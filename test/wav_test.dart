import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/wav.dart';

void main() {
  test('pcmToWav writes a valid 44-byte RIFF/WAVE header', () {
    final pcm = Uint8List.fromList(List<int>.filled(320, 0)); // 160 samples
    final wav = pcmToWav(pcm, sampleRate: 16000, channels: 1);

    expect(wav.length, 44 + pcm.length);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

    final bd = ByteData.sublistView(wav);
    expect(bd.getUint32(4, Endian.little), 36 + pcm.length); // chunk size
    expect(bd.getUint16(20, Endian.little), 1); // PCM
    expect(bd.getUint16(22, Endian.little), 1); // mono
    expect(bd.getUint32(24, Endian.little), 16000); // sample rate
    expect(bd.getUint32(28, Endian.little), 16000 * 2); // byte rate
    expect(bd.getUint16(34, Endian.little), 16); // bits per sample
    expect(bd.getUint32(40, Endian.little), pcm.length); // data size
  });

  test('pcmToWav preserves sample bytes after the header', () {
    final pcm = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    final wav = pcmToWav(pcm);
    expect(wav.sublist(44), pcm);
  });
}
