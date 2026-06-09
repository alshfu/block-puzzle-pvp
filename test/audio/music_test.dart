/// music_test.dart — тесты чистого рендера фоновой музыки ([music.dart]).
///
/// Проверяем: парсер нот [noteFreq] (равный темперированный строй), наличие
/// треков для всех тем, корректность WAV-цикла (заголовок + длина = длине
/// цикла трека) и детерминизм рендера.
library;

import 'dart:typed_data';

import 'package:block_duel/audio/music.dart';
import 'package:block_duel/audio/synth.dart';
import 'package:block_duel/ui/design_tokens.dart' show ThemeId;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('noteFreq', () {
    test('опорные ноты', () {
      expect(noteFreq('A4'), closeTo(440, 1e-6));
      expect(noteFreq('A2'), closeTo(110, 1e-6));
      expect(noteFreq('C5'), closeTo(523.251, 0.01));
      expect(noteFreq('Bb2'), closeTo(116.541, 0.01));
    });

    test('пауза и мусор → 0', () {
      expect(noteFreq(rest), 0);
      expect(noteFreq('nope'), 0);
      expect(noteFreq(''), 0);
    });
  });

  group('tracks / renderTrack', () {
    test('треки есть для всех тем', () {
      for (final id in ThemeId.values) {
        expect(tracks[id], isNotNull);
        expect(tracks[id]!.voices, isNotEmpty);
      }
    });

    test('WAV-цикл валиден и его длина = длине цикла трека', () {
      const sr = 22050;
      for (final id in ThemeId.values) {
        final track = tracks[id]!;
        final wav = renderTrack(track, sampleRate: sr);
        final d = ByteData.sublistView(wav);
        // Заголовок.
        expect(d.getUint16(22, Endian.little), 1); // моно
        expect(d.getUint32(24, Endian.little), sr); // sampleRate

        // Длина цикла = max по голосам сумма долей × beat.
        final beat = 60 / track.bpm;
        var loopBeats = 0.0;
        for (final v in track.voices) {
          var b = 0.0;
          for (final note in v.notes) {
            b += note.d;
          }
          if (b > loopBeats) loopBeats = b;
        }
        final expectedSamples = (loopBeats * beat * sr).ceil();
        final dataBytes = d.getUint32(40, Endian.little);
        expect(dataBytes, expectedSamples * 2); // 16-bit моно
      }
    });

    test('детерминизм: одинаковый трек → одинаковые байты', () {
      final a = renderTrack(tracks[ThemeId.candy]!, sampleRate: 8000);
      final b = renderTrack(tracks[ThemeId.candy]!, sampleRate: 8000);
      expect(a, equals(b));
    });
  });

  test('synth: новые параметры огибающей не ломают дефолт SFX', () {
    // totalDuration фиксирует длину буфера (для петли музыки).
    final s = renderSamples(
      const [ToneSpec(freq: 440, duration: 0.1)],
      totalDuration: 0.5,
      sampleRate: 8000,
    );
    expect(s.length, (0.5 * 8000).ceil());
  });
}
