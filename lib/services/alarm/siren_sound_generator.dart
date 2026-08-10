import 'dart:math';
import 'dart:typed_data';

class SirenSoundGenerator {
  static Uint8List? _cachedSirenBytes;

  /// Returns synthesized emergency siren WAV audio bytes in pure Dart (Offline & Immediate)
  static Uint8List getSirenWavBytes({int sampleRate = 22050, double durationSeconds = 1.4}) {
    if (_cachedSirenBytes != null) return _cachedSirenBytes!;

    final int totalSamples = (sampleRate * durationSeconds).toInt();
    final int dataSize = totalSamples * 2; // 16-bit mono = 2 bytes per sample
    final int fileSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);

    // RIFF chunk descriptor
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    byteData.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little);  // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, dataSize, Endian.little);

    // Synthesize two-tone emergency alarm siren waveform (960Hz high tone, 770Hz low tone)
    int offset = 44;
    for (int i = 0; i < totalSamples; i++) {
      final double t = i / sampleRate;
      // High-pitch vs lower-pitch alternating every 0.35 seconds
      final double freq = (t % 0.70 < 0.35) ? 960.0 : 770.0;

      // Two-tone harmonic acoustic wave for penetration
      final double sample = (0.75 * sin(2 * pi * freq * t)) +
                            (0.25 * sin(4 * pi * freq * t));

      final int sampleInt16 = (sample * 28000).clamp(-32768, 32767).toInt();
      byteData.setInt16(offset, sampleInt16, Endian.little);
      offset += 2;
    }

    _cachedSirenBytes = byteData.buffer.asUint8List();
    return _cachedSirenBytes!;
  }
}
