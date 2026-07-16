import 'dart:typed_data';

/// Wrap raw little-endian PCM16 mono samples in a 44-byte RIFF/WAVE header.
Uint8List pcmToWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final byteRate = sampleRate * channels * 2;
  final dataLen = pcm.length;
  final out = Uint8List(44 + dataLen);
  final v = ByteData.view(out.buffer);

  void writeStr(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      v.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  v.setUint32(4, 36 + dataLen, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  v.setUint32(16, 16, Endian.little); // PCM chunk size
  v.setUint16(20, 1, Endian.little); // PCM format
  v.setUint16(22, channels, Endian.little);
  v.setUint32(24, sampleRate, Endian.little);
  v.setUint32(28, byteRate, Endian.little);
  v.setUint16(32, channels * 2, Endian.little); // block align
  v.setUint16(34, 16, Endian.little); // bits per sample
  writeStr(36, 'data');
  v.setUint32(40, dataLen, Endian.little);
  out.setRange(44, 44 + dataLen, pcm);
  return out;
}
