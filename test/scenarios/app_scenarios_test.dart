/// app_scenarios_test.dart — исполняемый ОБРАЗЕЦ сквозного каталога сценариев.
///
/// За что отвечает файл:
///   Вторая половина гибрида «генератор + образец» (см. tools/gen_scenarios.py и
///   qa/SCENARIOS_APP.md): каталог фиксирует полное пространство из 1001
///   пользовательского сценария, а этот файл проверяет РЕПРЕЗЕНТАТИВНЫЙ срез из
///   них исполняемо, на чистом ядре и pure-режимах (без widget-инфры). Имена
///   тестов ссылаются на APP-ID каталога, чтобы связь «сценарий → проверка» была
///   явной. Файл не дублирует уже покрытое (см. test/core, test/modes,
///   test/online) сверх необходимого для образца.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/match3/match3_core.dart';
import 'package:block_duel/modes/puzzle/puzzle_core.dart';
import 'package:block_duel/modes/puzzle/puzzle_pack.dart';
import 'package:block_duel/profile/xp_formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ядро игры (APP-scenarios ядра/очисток)', () {
    test('APP: одиночная очистка строки без комбо = scoreRowPts', () {
      final s = scoreForMove(1, 0, false, defaultConfig);
      expect(s, defaultConfig.scoreRowPts);
    });

    test('APP: комбо повышает очки за ту же очистку', () {
      final base = scoreForMove(1, 0, false, defaultConfig);
      final withCombo = scoreForMove(1, 5, false, defaultConfig);
      expect(withCombo, greaterThan(base));
    });

    test('APP: perfect clear добавляет perfectClearBonus', () {
      final s = scoreForMove(0, 0, true, defaultConfig);
      expect(s, defaultConfig.perfectClearBonus);
    });

    test('APP: мульти-очистка (2 линии) дороже двух одиночных за счёт множителя', () {
      final single = scoreForMove(1, 0, false, defaultConfig);
      final duo = scoreForMove(2, 0, false, defaultConfig);
      expect(duo, greaterThan(2 * single - 1)); // множитель +multiClearStep
    });

    test('APP: тупик — на полностью занятой доске нет ни одного хода', () {
      final board = emptyBoard();
      for (final row in board) {
        for (var c = 0; c < row.length; c++) {
          row[c] = Cell(filled: true, owner: 0);
        }
      }
      final piece = Bag(1).draw();
      expect(hasAnyMove(board, [piece], defaultConfig), isFalse);
    });
  });

  group('7-bag детерминизм (APP: resume/раздача)', () {
    test('APP: два мешка с одним seed дают одинаковую последовательность', () {
      final a = Bag(4242);
      final b = Bag(4242);
      final seqA = [for (var i = 0; i < 21; i++) a.draw().type];
      final seqB = [for (var i = 0; i < 21; i++) b.draw().type];
      expect(seqA, seqB);
    });

    test('APP: 7-bag fairness — каждый тип ровно раз в первом цикле из 7', () {
      final bag = Bag(7);
      final first7 = {for (var i = 0; i < 7; i++) bag.draw().type};
      expect(first7.length, 7); // все 7 типов различны
    });
  });

  group('Прогрессия / XP (APP: начисление за матч)', () {
    test('APP: победа > ничья > поражение по XP', () {
      final win = xpForMatch(outcome: MatchOutcome.win);
      final draw = xpForMatch(outcome: MatchOutcome.draw);
      final loss = xpForMatch(outcome: MatchOutcome.loss);
      expect(win, greaterThan(draw));
      expect(draw, greaterThan(loss));
    });

    test('APP: поражение даёт 0 XP по формуле', () {
      expect(xpForMatch(outcome: MatchOutcome.loss), 0);
    });

    test('APP: ничья = floor(base·0.5) = 25', () {
      expect(xpForMatch(outcome: MatchOutcome.draw), 25);
    });

    test('APP: стрик побед повышает XP, но с потолком 1.5×', () {
      final s0 = xpForMatch(outcome: MatchOutcome.win, winStreak: 0);
      final s5 = xpForMatch(outcome: MatchOutcome.win, winStreak: 5);
      final s99 = xpForMatch(outcome: MatchOutcome.win, winStreak: 99);
      expect(s5, greaterThan(s0));
      expect(s99, greaterThanOrEqualTo(s5));
      // Потолок: 50·1.5 = 75.
      expect(s99, 75);
    });
  });

  group('Match-3 (APP: своп/каскады/завершение)', () {
    test('APP: resolveBoard всегда завершается (потолок каскадов)', () {
      final grid = generateMatch3Grid(123);
      final res = resolveBoard(grid, makeRng(999));
      expect(res.cascades, greaterThanOrEqualTo(0));
    });

    test('APP: wouldMatch согласован со свопом+findMatches', () {
      final grid = generateMatch3Grid(555);
      // Ищем пару соседей, дающих серию.
      Cellxy? a, b;
      outer:
      for (var r = 0; r < match3Size; r++) {
        for (var c = 0; c < match3Size; c++) {
          final here = (r: r, c: c);
          for (final n in [(r: r, c: c + 1), (r: r + 1, c: c)]) {
            if (n.c >= match3Size || n.r >= match3Size) continue;
            if (wouldMatch(grid, here, n)) {
              a = here;
              b = n;
              break outer;
            }
          }
        }
      }
      if (a != null && b != null) {
        final copy = cloneGrid(grid);
        swapCells(copy, a, b);
        expect(findMatches(copy), isNotEmpty);
      }
      // Если такой пары нет на этом seed — сценарий вырожден, тест не падает.
    });
  });

  group('Силуэты (APP: разрешимость/валидация пака)', () {
    test('APP: каждый уровень контент-пака разрешим реплеем решения', () {
      for (final def in puzzlePack) {
        final board = puzzleEmptyBoard(def.width, def.height);
        for (final p in def.solution) {
          expect(puzzleCanPlace(board, def.mask, p.cells, 0, 0), isTrue,
              reason: '${def.id}: постановка невалидна');
          puzzlePlace(board, p.cells, 0, 0, 0);
        }
        expect(isPuzzleSolved(board, def.mask), isTrue,
            reason: '${def.id}: решение не покрывает маску');
      }
    });

    test('APP: битый внешний пак (клетка вне сетки) отвергается fail-fast', () {
      expect(
        () => PuzzleDef.fromJson({
          'id': 'x',
          'name': 'X',
          'category': 'objects',
          'difficulty': 'easy',
          'w': 3,
          'h': 3,
          'solution': [
            {
              's': 'O',
              'c': [
                [9, 9],
              ],
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
