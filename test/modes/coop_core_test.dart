/// coop_core_test.dart — тесты pure-ядра «Co-op Tetris» (поле 10×20).
///
/// Проверяют: размеры пустого поля, границы постановки, row-only очистку (без
/// столбцов/боксов и без «падения»), формулу очков за одну/несколько строк и
/// определение тупика.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/coop/coop_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Заполняет строку [r] целиком (для проверки очистки).
void _fillRow(Board b, int r) {
  for (int c = 0; c < coopWidth; c++) {
    b[r][c] = Cell(filled: true, owner: 0);
  }
}

void main() {
  group('поле и постановка', () {
    test('пустое поле имеет размеры 20×10', () {
      final b = emptyCoopBoard();
      expect(b.length, coopHeight);
      expect(b.first.length, coopWidth);
      expect(b.every((row) => row.every((cell) => !cell.filled)), isTrue);
    });

    test('постановка в пределах поля разрешена, за границей — нет', () {
      final b = emptyCoopBoard();
      final iVert = [
        const Coord(0, 0),
        const Coord(1, 0),
        const Coord(2, 0),
        const Coord(3, 0),
      ];
      expect(coopCanPlace(b, iVert, 0, 0), isTrue);
      expect(coopCanPlace(b, iVert, coopHeight - 3, 0), isFalse,
          reason: 'вертикальная I не влезает по высоте у дна');
      expect(coopCanPlace(b, iVert, 0, coopWidth), isFalse,
          reason: 'за правой границей');
    });

    test('нельзя ставить на занятую клетку', () {
      final b = emptyCoopBoard();
      b[0][0] = Cell(filled: true, owner: 1);
      expect(coopCanPlace(b, [const Coord(0, 0)], 0, 0), isFalse);
    });
  });

  group('очистка строк', () {
    test('полная строка распознаётся и очищается, соседние не трогаются', () {
      final b = emptyCoopBoard();
      _fillRow(b, 5);
      b[6][0] = Cell(filled: true, owner: 0); // частично занятая — не полная
      final full = coopFullRows(b);
      expect(full, [5]);
      coopClearRows(b, full);
      expect(b[5].every((cell) => !cell.filled), isTrue);
      expect(b[6][0].filled, isTrue, reason: 'строка 6 не очищается');
    });

    test('столбцы и боксы НЕ очищаются (только строки)', () {
      final b = emptyCoopBoard();
      for (int r = 0; r < coopHeight; r++) {
        b[r][0] = Cell(filled: true, owner: 0); // полный столбец 0
      }
      expect(coopFullRows(b), isEmpty);
    });

    test('несколько полных строк за один поиск', () {
      final b = emptyCoopBoard();
      _fillRow(b, 0);
      _fillRow(b, 1);
      _fillRow(b, 19);
      expect(coopFullRows(b), [0, 1, 19]);
    });
  });

  group('скоринг', () {
    test('0 строк → 0 очков', () {
      expect(coopScoreForClear(0), 0);
    });

    test('1 строка → база', () {
      expect(coopScoreForClear(1), coopRowPoints);
    });

    test('несколько строк дают мультипликатор', () {
      expect(coopScoreForClear(2), (2 * coopRowPoints * 1.25).round());
      expect(coopScoreForClear(4), (4 * coopRowPoints * 1.75).round());
      expect(coopScoreForClear(4), greaterThan(coopScoreForClear(1) * 4),
          reason: 'тетрис выгоднее четырёх одиночных');
    });
  });

  group('тупик', () {
    test('на пустом поле ход есть', () {
      final hand = [
        const PieceInstance(id: 'a', type: PieceType.o, cells: [
          Coord(0, 0),
          Coord(0, 1),
          Coord(1, 0),
          Coord(1, 1),
        ]),
      ];
      expect(
        coopHasAnyMove(emptyCoopBoard(), hand,
            rotationEnabled: true, flipEnabled: true),
        isTrue,
      );
    });

    test('на полностью занятом поле хода нет', () {
      final b = emptyCoopBoard();
      for (int r = 0; r < coopHeight; r++) {
        _fillRow(b, r);
      }
      final hand = [
        const PieceInstance(id: 'a', type: PieceType.o, cells: [
          Coord(0, 0),
          Coord(0, 1),
          Coord(1, 0),
          Coord(1, 1),
        ]),
      ];
      expect(
        coopHasAnyMove(b, hand, rotationEnabled: true, flipEnabled: true),
        isFalse,
      );
    });
  });
}
