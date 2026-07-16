import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'api.dart';
import 'wav.dart';

enum VoiceState { idle, listen, rec, think, talk }

/// Hands-free continuous voice loop ported from the web dashboard:
/// listen -> rec (VAD endpointing) -> think (stream ai_voice) -> talk
/// with barge-in + TTS ducking. Capture uses the phone's voice-communication
/// audio source so hardware AEC keeps the mic from hearing our own TTS.
class VoiceEngine extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final Api _api = Api.instance;

  static const int sr = 16000;
  static const int _bytesPerSec = sr * 2;

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;
  String status = 'Tayyor';
  final ValueNotifier<double> level = ValueNotifier<double>(0);
  void Function(String code)? onError;

  bool _running = false;
  bool get running => _running;

  StreamSubscription<Uint8List>? _sub;
  StreamSubscription<void>? _playSub;
  StreamSubscription<Map<String, dynamic>>? _voiceSub;

  // VAD state
  double _noise = 0.012;
  int _voiceRun = 0;
  int _silenceMs = 0;
  int _voicedMs = 0;
  int _bargeRun = 0;
  final List<int> _pcm = <int>[];
  final List<Uint8List> _pre = <Uint8List>[];
  int _preBytes = 0;

  // playback queue
  final List<Uint8List> _q = <Uint8List>[];
  bool _qPlaying = false;
  bool _streamDone = false;
  bool _gotEvent = false;

  Future<void> start() async {
    if (_running) return;
    final status0 = await Permission.microphone.request();
    if (!status0.isGranted) {
      status = 'Mikrofon ruxsati berilmadi';
      notifyListeners();
      return;
    }
    Stream<Uint8List>? stream;
    try {
      stream = await MicStream.microphone(
        audioSource: AudioSource.VOICE_COMMUNICATION,
        sampleRate: sr,
        channelConfig: ChannelConfig.CHANNEL_IN_MONO,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
      );
    } catch (_) {
      stream = null;
    }
    if (stream == null) {
      status = 'Mikrofon ochilmadi';
      notifyListeners();
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    _playSub ??= _player.onPlayerComplete.listen((_) => _playNext());
    _running = true;
    _sub = stream.listen(_onChunk, onError: (_) {});
    _setState(VoiceState.listen, 'Tinglayapman...');
  }

  Future<void> stop() async {
    _running = false;
    await _voiceSub?.cancel();
    _voiceSub = null;
    await _sub?.cancel(); // cancelling the subscription stops the mic
    _sub = null;
    await _stopPlayback();
    _q.clear();
    _qPlaying = false;
    _pcm.clear();
    _pre.clear();
    _preBytes = 0;
    level.value = 0;
    _setState(VoiceState.idle, 'Tayyor');
  }

  double _rms(Uint8List b) {
    final n = b.length ~/ 2;
    if (n == 0) return 0;
    final bd = ByteData.sublistView(b);
    double sum = 0;
    for (var i = 0; i < n; i++) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    return sqrt(sum / n);
  }

  void _onChunk(Uint8List b) {
    if (!_running) return;
    final rms = _rms(b);
    final ms = ((b.length ~/ 2) / sr * 1000).round();
    level.value = rms;

    final startTh = max(0.020, _noise * 2.2);
    final stopTh = max(0.012, _noise * 1.6);
    final bargeTh = max(0.055, _noise * 2.8);

    switch (_state) {
      case VoiceState.listen:
        _pushPre(b);
        if (rms > startTh) {
          _voiceRun++;
        } else {
          _voiceRun = 0;
          if (rms < stopTh) _noise = _noise * 0.95 + rms * 0.05;
        }
        if (_voiceRun >= 2) _beginRec();
        break;
      case VoiceState.rec:
        _pcm.addAll(b);
        if (rms > stopTh) {
          _voicedMs += ms;
          _silenceMs = 0;
        } else {
          _silenceMs += ms;
        }
        final endSil = _voicedMs > 1500 ? 600 : 380;
        if (_voicedMs >= 200 && _silenceMs >= endSil) {
          _endUtterance();
        } else if (_pcm.length > _bytesPerSec * 15) {
          _endUtterance();
        }
        break;
      case VoiceState.think:
      case VoiceState.talk:
        if (rms > bargeTh) {
          _bargeRun++;
        } else {
          _bargeRun = 0;
        }
        if (_state == VoiceState.talk) {
          _player.setVolume(rms > bargeTh ? 0.3 : 1.0);
        }
        if (_bargeRun >= 3) _barge(b);
        break;
      case VoiceState.idle:
        break;
    }
  }

  void _pushPre(Uint8List b) {
    _pre.add(b);
    _preBytes += b.length;
    while (_preBytes > (_bytesPerSec * 0.2).round() && _pre.length > 1) {
      final r = _pre.removeAt(0);
      _preBytes -= r.length;
    }
  }

  void _beginRec() {
    _pcm.clear();
    for (final p in _pre) {
      _pcm.addAll(p);
    }
    _pre.clear();
    _preBytes = 0;
    _voicedMs = 0;
    _silenceMs = 0;
    _voiceRun = 0;
    _setState(VoiceState.rec, 'Eshityapman...');
  }

  void _endUtterance() {
    if (_pcm.isEmpty) {
      _setState(VoiceState.listen, 'Tinglayapman...');
      return;
    }
    final pcm = Uint8List.fromList(_pcm);
    _pcm.clear();
    _setState(VoiceState.think, 'Oylayapman...');
    final wav = pcmToWav(pcm, sampleRate: sr);
    _sendVoice(base64Encode(wav));
  }

  void _sendVoice(String b64) {
    _voiceSub?.cancel();
    _streamDone = false;
    _gotEvent = false;
    _q.clear();
    _qPlaying = false;
    _voiceSub = _api.voiceStream(b64).listen((ev) {
      _gotEvent = true;
      final t = ev['type'];
      if (t == 'audio') {
        final s = ev['b64'];
        if (s is String && s.isNotEmpty) {
          try {
            _enqueue(base64Decode(s));
          } catch (_) {}
        }
      } else if (t == 'empty' || t == 'error' || t == 'done') {
        _streamDone = true;
        if (!_qPlaying && _q.isEmpty) _resume();
      }
    }, onError: (e) {
      if (e is ApiException && e.code == 'key') {
        onError?.call('key');
        stop();
        return;
      }
      if (!_gotEvent) {
        _fallback(b64);
      } else {
        _streamDone = true;
        if (!_qPlaying && _q.isEmpty) _resume();
      }
    }, onDone: () {
      _streamDone = true;
      if (!_qPlaying && _q.isEmpty) _resume();
    });
  }

  Future<void> _fallback(String b64) async {
    try {
      final r = await _api.stt(b64);
      final text = (r['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        _resume();
        return;
      }
      final a = await _api.ask(text);
      final tts = a['tts'];
      if (tts is String && tts.isNotEmpty) {
        _streamDone = true;
        _enqueue(base64Decode(tts));
      } else {
        _resume();
      }
    } catch (e) {
      if (e is ApiException && e.code == 'key') {
        onError?.call('key');
        stop();
        return;
      }
      _resume();
    }
  }

  void _enqueue(Uint8List bytes) {
    _q.add(bytes);
    if (!_qPlaying) _playNext();
  }

  Future<void> _playNext() async {
    if (!_running) {
      _qPlaying = false;
      return;
    }
    if (_q.isEmpty) {
      _qPlaying = false;
      if (_streamDone) {
        _resume();
      } else {
        _setState(VoiceState.think, 'Oylayapman...');
      }
      return;
    }
    _qPlaying = true;
    final bytes = _q.removeAt(0);
    _bargeRun = 0;
    _silenceMs = 0;
    _setState(VoiceState.talk, 'Javob beryapman...');
    try {
      await _player.setVolume(1.0);
      await _player.play(BytesSource(bytes));
    } catch (_) {
      _playNext();
    }
  }

  void _barge(Uint8List b) {
    _voiceSub?.cancel();
    _voiceSub = null;
    _stopPlayback();
    _bargeRun = 0;
    _q.clear();
    _qPlaying = false;
    _pcm.clear();
    _pcm.addAll(b);
    _voicedMs = 0;
    _silenceMs = 0;
    _setState(VoiceState.rec, 'Eshityapman...');
  }

  void _resume() {
    _q.clear();
    _qPlaying = false;
    _streamDone = false;
    _bargeRun = 0;
    _voiceRun = 0;
    _player.setVolume(1.0);
    if (_running) {
      _setState(VoiceState.listen, 'Tinglayapman...');
    } else {
      _setState(VoiceState.idle, 'Tayyor');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _setState(VoiceState s, String st) {
    _state = s;
    status = st;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _playSub?.cancel();
    _player.dispose();
    level.dispose();
    super.dispose();
  }
}
