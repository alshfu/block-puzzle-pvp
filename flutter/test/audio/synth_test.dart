/// synth_test.dart — тесты чистого WAV-синтеза ([synth.dart], [sfx.dart]).
///
/// Проверяем: длину буфера от таймингов тонов, корректность WAV-заголовка
/// (RIFF/WAVE/fmt/data, моно, 16-bit, sampleRate), границы амплитуды [-1, 1],
/// достижение пика огибающей, детерминизм байтов и кламп звука очистки.
library;

import 'dart:typed_data';

import 'package:block_duel/audio/sfx.dart';
import 'package:block_duel/audio/synth.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(ByteData d, int offset, int len) {
  final sb = StringBuffer();
  for (int i = 0; i < len; i++) {
    sb.writeCharCode(d.getUint8(offset + i));
  }
  return sb.toString();
}

void main() {
  group('renderSamples', () {
    test('пустой список тонов → пустой буфер', () {
      expect(renderSamples(const []), isEmpty);
    });

    test('длина буфера = ceil(maxEnd * sampleRate)', () {
      const sr = 8000;
      // Два тона: второй стартует позже и определяет конец.
      const tones = [
        ToneSpec(freq: 440, duration: 0.1),
        ToneSpec(freq: 660, duration: 0.2, start: 0.3),
      ];
      // maxEnd = 0.3 + 0.2 + 0.02 (tail) = 0.52 c → 0.52*8000 = 4160.
      final s = renderSamples(tones, sampleRate: sr);
      expect(s.length, (0.52 * sr).ceil());
    });

    test('все сэмплы в пределах [-1, 1]', () {
      final s = renderSamples(sfxPerfect(), volume: 1.0);
      for (final v in s) {
        expect(v, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('огибающая достигает пика (gain * volume)', () {
      const peak = 0.5; // gain 0.5 * volume 1.0
      final s = renderSamples(
        const [ToneSpec(freq: 440, duration: 0.1, gain: 0.5)],
        volume: 1.0,
      );
      var maxAbs = 0.0;
      for (final v in s) {
        if (v.abs() > maxAbs) maxAbs = v.abs();
      }
      // Синус 440Гц многократно проходит ±1 в окне → максимум близок к peak.
      expect(maxAbs, lessThanOrEqualTo(peak + 1e-6));
      expect(maxAbs, greaterThan(peak * 0.8));
    });

    test('детерминизм: одинаковые тоны → идентичные сэмплы', () {
      final a = renderSamples(sfxWin());
      final b = renderSamples(sfxWin());
      expect(a, equals(b));
    });
  });

  group('encodeWav', () {
    test('корректный 44-байтный заголовок и размер data', () {
      const sr = 16000;
      final samples = renderSamples(sfxClick(), sampleRate: sr);
      final wav = encodeWav(samples, sampleRate: sr);
      final d = ByteData.sublistView(wav);

      expect(_ascii(d, 0, 4), 'RIFF');
      expect(_ascii(d, 8, 4), 'WAVE');
      expect(_ascii(d, 12, 4), 'fmt ');
      expect(_ascii(d, 36, 4), 'data');
      expect(d.getUint16(20, Endian.little), 1); // PCM
      expect(d.getUint16(22, Endian.little), 1); // моно
      expect(d.getUint32(24, Endian.little), sr); // sampleRate
      expect(d.getUint16(34, Endian.little), 16); // bits per sample

      final dataBytes = d.getUint32(40, Endian.little);
      expect(dataBytes, samples.length * 2); // 16-bit моно
      expect(wav.length, 44 + dataBytes);
      expect(d.getUint32(4, Endian.little), 36 + dataBytes); // RIFF size
    });

    test('пустой буфер → только заголовок (44 байта)', () {
      final wav = encodeWav(Float64List(0));
      expect(wav.length, 44);
    });
  });

  group('sfxClear', () {
    test('число тонов = clamp(n, 1, 8)', () {
      expect(sfxClear(0).length, 1);
      expect(sfxClear(3).length, 3);
      expect(sfxClear(20).length, 8);
    });

    test('ноты восходящие по частоте', () {
      final tones = sfxClear(5);
      for (int i = 1; i < tones.length; i++) {
        expect(tones[i].freq, greaterThan(tones[i - 1].freq));
      }
    });
  });
}
