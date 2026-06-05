/// rng_web_test.dart — проверка PRNG на ОБОИХ таргетах (VM и Web/JS).
///
/// За что отвечает файл:
///   [Mulberry32] использует 32-битную арифметику, а целые в Dart на VM
///   64-битны, на Web — это JS number. Этот тест с ВСТРОЕННЫМИ эталонными
///   значениями (без `dart:io`/`flutter_test`) запускается и через
///   `dart test test/core/rng_web_test.dart` (VM), и через
///   `dart test -p chrome test/core/rng_web_test.dart` (Web) — ловит
///   расхождения 32/64-бит, которые golden-тест на VM не увидит.
///
/// Эталонные значения взяты из `test/golden/determinism_match.json`
/// (секция rng, первые 6 чисел для сидов 1, 0 и 2^32-1).
library;

import 'package:block_duel/core/rng.dart';
import 'package:test/test.dart';

/// Эталонные первые 6 выходов mulberry32 по сидам (из golden-дампа TS).
const Map<int, List<double>> _expected = {
  1: [
    0.6270739405881613,
    0.002735721180215478,
    0.5274470399599522,
    0.9810509674716741,
    0.9683778982143849,
    0.281103502959013,
  ],
  0: [
    0.26642920868471265,
    0.0003297457005828619,
    0.2232720274478197,
    0.1462021479383111,
    0.46732782293111086,
    0.5450490827206522,
  ],
  4294967295: [
    0.8964226141106337,
    0.189478256739676,
    0.7156526781618595,
    0.9440599093213677,
    0.8452364315744489,
    0.5391399988438934,
  ],
};

void main() {
  group('Mulberry32 (VM + Web)', () {
    _expected.forEach((seed, values) {
      test('seed=$seed совпадает с эталоном', () {
        final rng = Mulberry32(seed);
        for (int i = 0; i < values.length; i++) {
          expect(rng.next(), values[i], reason: 'seed=$seed i=$i');
        }
      });
    });
  });
}
