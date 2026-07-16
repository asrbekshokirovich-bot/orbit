import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'store.dart';

const String kFN =
    'https://zqpglkxbtpkvyraxquao.supabase.co/functions/v1/dashboard';

class ApiException implements Exception {
  final String code;
  ApiException(this.code);
  @override
  String toString() => 'ApiException($code)';
}

class Api {
  Api._();
  static final Api instance = Api._();
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> call(String op,
      [Map<String, dynamic>? extra]) async {
    final key = await Store.getKey();
    final body = <String, dynamic>{'op': op, ...?extra};
    final r = await _client.post(
      Uri.parse(kFN),
      headers: {
        'content-type': 'application/json',
        'x-orbit-key': key ?? '',
      },
      body: jsonEncode(body),
    );
    if (r.statusCode == 401) throw ApiException('key');
    if (r.statusCode >= 400) throw ApiException('http${r.statusCode}');
    final decoded = jsonDecode(utf8.decode(r.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }

  /// Streamed voice op. Sends a WAV as base64 and yields parsed SSE events:
  ///   {type:'audio', b64:'...'}  | {type:'empty'|'error'|'done'}
  Stream<Map<String, dynamic>> voiceStream(String wavB64) async* {
    final key = await Store.getKey();
    final req = http.Request('POST', Uri.parse(kFN));
    req.headers['content-type'] = 'application/json';
    req.headers['x-orbit-key'] = key ?? '';
    req.body = jsonEncode({'op': 'ai_voice', 'audio': wavB64, 'mime': 'audio/wav'});

    final resp = await _client.send(req);
    if (resp.statusCode == 401) throw ApiException('key');
    if (resp.statusCode >= 400) throw ApiException('http${resp.statusCode}');

    var sb = '';
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      sb += chunk;
      var idx = sb.indexOf('\n\n');
      while (idx >= 0) {
        final line = sb.substring(0, idx).trim();
        sb = sb.substring(idx + 2);
        if (line.startsWith('data:')) {
          final pl = line.substring(5).trim();
          if (pl.isNotEmpty) {
            try {
              final ev = jsonDecode(pl);
              if (ev is Map<String, dynamic>) yield ev;
            } catch (_) {}
          }
        }
        idx = sb.indexOf('\n\n');
      }
    }
  }

  /// Serial fallback if streaming yields nothing.
  Future<Map<String, dynamic>> stt(String wavB64) =>
      call('ai_stt', {'audio': wavB64, 'mime': 'audio/wav'});
  Future<Map<String, dynamic>> ask(String question) =>
      call('ai_ask', {'question': question});
}
