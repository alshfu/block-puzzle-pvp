/// mode_scenarios_test.dart — исполняемый ОБРАЗЕЦ каталогов оси «режим».
///
/// За что отвечает файл:
///   Вторая половина гибрида «генератор + образец» для оси «1001 на режим» (см.
///   tools/gen_scenarios.py → `qa/SCENARIOS_MODE_<id>.md`). Проверяет исполняемо
///   репрезентативные механики отдельных режимов на чистом ядре/pure-режимах.
///   Имена тестов ссылаются на `MODE-<ID>` каталога соответствующего режима.
library;

import 'package:block_duel/modes/coop/coop_core.dart';
import 'package:block_duel/modes/ladder/composite_score.dart';
import 'package:block_duel/modes/match3/match3_core.dart';
import 'package:block_duel/modes/puzzle/puzzle_core.dart';
import 'package:block_duel/modes/puzzle/puzzle_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MODE-COOP — Co-op Tetris 10×20', () {
    test('MODE-COOP: очистка 0 строк = 0 очков', () {
      expect(coopScoreForClear(0), 0);
    });

    test('MODE-COOP: множитель +25% за каждую доп. строку', () {
      // 1 строка = 100·1.0; 2 строки = 2·100·1.25 = 250 > 2×100.
      expect(coopScoreForClear(1), coopRowPoints);
      expect(coopScoreForClear(2), greaterThan(2 * coopScoreForClear(1)));
    });

    test('MODE-COOP: поле объявлено как 10×20', () {
      expect(coopWidth, 10);
      expect(coopHeight, 20);
    });
  });

  group('MODE-MATCH3 — Match-3 PvP 8×8', () {
    test('MODE-MATCH3: сгенерированное поле имеет размер 8×8', () {
      final grid = generateMatch3Grid(7);
      expect(grid.length, match3Size);
      expect(grid.every((row) => row.length == match3Size), isTrue);
    });

    test('MODE-MATCH3: детерминизм — один seed даёт одинаковое поле', () {
      final a = generateMatch3Grid(999);
      final b = generateMatch3Grid(999);
      expect(a, b);
    });
  });

  group('MODE-PUZZLE — Силуэты', () {
    test('MODE-PUZZLE: очки растут со сложностью при том же бюджете', () {
      // Экономный проход (0 ходов сверх минимума) на разных сложностях: expert
      // базово дороже easy.
      final easy = puzzleCoinReward(PuzzleDifficulty.easy);
      final expert = puzzleCoinReward(PuzzleDifficulty.expert);
      expect(expert, greaterThan(easy));
    });

    test('MODE-PUZZLE: puzzleScore = base + бонус за сэкономленные ходы', () {
      final def = puzzlePack.first;
      final full = puzzleScore(def, 0); // не потрачено ни одного лишнего хода
      final spent = puzzleScore(def, def.pieceCount); // потрачен весь бюджет
      expect(full, greaterThanOrEqualTo(spent));
    });
  });

  group('MODE-* — сводный рейтинг (composite)', () {
    test('MODE: пустой список режимов → композит = общий ELO', () {
      expect(compositeScore(1200, const []), 1200);
    });

    test('MODE: composite = floor(0.4·general + 0.6·avg(modes))', () {
      // general=1000, modes avg=1500 → 0.4·1000 + 0.6·1500 = 400 + 900 = 1300.
      expect(compositeScore(1000, const [1500, 1500]), 1300);
    });
  });
}
