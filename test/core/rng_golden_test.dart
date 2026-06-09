/// rng_golden_test.dart — сверка Dart-PRNG с golden-эталоном TS-ядра.
///
/// За что отвечает файл:
///   Проверяет, что [Mulberry32] воспроизводит сырые выходы `mulberry32` из
///   TS-версии бит-в-бит. Эталон — секция `rng` файла
///   `test/golden/determinism_match.json` (сгенерирован `tools/dump-golden.ts`).
///   Это первый и важнейший слой gate Фазы 1: если PRNG совпал, всё
///   детерминированное поведение ядра может совпасть.
///
/// Как читается эталон:
///   JSON грузится с диска (`dart:io`, тесты идут на VM). Для каждого сида
///   создаётся генератор и сравнивается последовательность чисел.
library;

import 'dart:convert';
import 'dart:io';

import 'package:block_duel/core/rng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Грузим golden один раз для всей группы.
  final Map<String, dynamic> golden =
      jsonDecode(File('test/golden/determinism_match.json').readAsStringSync())
          as Map<String, dynamic>;

  group('Mulberry32 vs golden', () {
    final List<dynamic> rngSection = golden['rng'] as List<dynamic>;

    for (final dynamic entry in rngSection) {
      final Map<String, dynamic> e = entry as Map<String, dynamic>;
      final int seed = e['seed'] as int;
      final List<dynamic> expected = e['values'] as List<dynamic>;

      test('seed=$seed даёт ту же последовательность', () {
        final rng = Mulberry32(seed);
        for (int i = 0; i < expected.length; i++) {
          final double got = rng.next();
          final double want = (expected[i] as num).toDouble();
          // Числитель < 2^32 делится на 2^32 точно в IEEE754, поэтому
          // сравнение строгое (==), а не с допуском.
          expect(got, want, reason: 'seed=$seed index=$i');
        }
      });
    }
  });
}
