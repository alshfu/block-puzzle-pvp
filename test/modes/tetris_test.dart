/// tetris_test.dart — тесты «Классического Tetris» (pure-ядро + ViewModel).
///
/// Проверяют: размеры поля, 4 состояния поворота, центрирование спавна,
/// дистанцию падения, СХЛОПЫВАЮЩУЮ очистку строк (классика, не row-in-place),
/// таблицу очков и кривые уровня/скорости; а также ViewModel — старт партии,
/// сдвиг у стен, фиксацию hard drop, hold (раз за фигуру) и гравитацию через
/// tick.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/tetris/tetris_core.dart';
import 'package:block_duel/modes/tetris/tetris_notifier.dart';
import 'package:block_duel/modes/tetris/tetris_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _c() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

/// Заполняет строку [r] целиком (для проверки очистки).
void _fillRow(Board b, int r) {
  for (int col = 0; col < tetrisCols; col++) {
    b[r][col] = Cell(filled: true, owner: 0);
  }
}

void main() {
  group('поле и геометрия', () {
    test('пустое поле 20×10', () {
      final b = emptyTetrisBoard();
      expect(b.length, tetrisRows);
      expect(b.first.length, tetrisCols);
    });

    test('у каждой фигуры 4 состояния поворота', () {
      for (final t in allTypes) {
        expect(tetrisRotationStates(t).length, 4);
      }
    });

    test('O-фигура одинакова во всех поворотах', () {
      final states = tetrisRotationStates(PieceType.o);
      expect(states.every((s) => s.toString() == states.first.toString()),
          isTrue);
    });

    test('индекс цвета соответствует порядку allTypes', () {
      for (int i = 0; i < allTypes.length; i++) {
        expect(tetrisColorIndex(allTypes[i]), i);
      }
    });

    test('спавн центрирует фигуру по ширине', () {
      // O шириной 2 → колонка (10-2)/2 = 4.
      expect(tetrisSpawnCol(PieceType.o), 4);
    });
  });

  group('падение и постановка', () {
    test('canPlace уважает границы поля', () {
      final b = emptyTetrisBoard();
      expect(tetrisCanPlace(b, PieceType.o, 0, 0, 0), isTrue);
      expect(tetrisCanPlace(b, PieceType.o, 0, tetrisRows - 1, 0), isFalse,
          reason: 'O не влезает по высоте у дна');
      expect(tetrisCanPlace(b, PieceType.o, 0, 0, tetrisCols - 1), isFalse,
          reason: 'за правой границей');
    });

    test('drop distance на пустом поле — до самого дна', () {
      final b = emptyTetrisBoard();
      // O высотой 2 в строке 0 → может опуститься на (rows-2) рядов.
      expect(tetrisDropDistance(b, PieceType.o, 0, 0, 4), tetrisRows - 2);
    });
  });

  group('очистка строк (схлопывание)', () {
    test('полная нижняя строка очищается, стопка сверху опускается', () {
      final b = emptyTetrisBoard();
      _fillRow(b, tetrisRows - 1);
      // Одна клетка над очищаемой строкой — должна «упасть» на дно.
      b[tetrisRows - 2][3] = Cell(filled: true, owner: 1);
      final res = tetrisClearRows(b);
      expect(res.cleared, 1);
      expect(res.board.length, tetrisRows);
      // Верхняя клетка опустилась на последнюю строку.
      expect(res.board[tetrisRows - 1][3].filled, isTrue);
      // Самая верхняя строка пуста.
      expect(res.board[0].every((cell) => !cell.filled), isTrue);
    });

    test('неполные строки не очищаются', () {
      final b = emptyTetrisBoard();
      b[tetrisRows - 1][0] = Cell(filled: true, owner: 0);
      expect(tetrisClearRows(b).cleared, 0);
    });
  });

  group('счёт и кривые', () {
    test('таблица очков за линии (×уровень)', () {
      expect(tetrisLineScore(0, 1), 0);
      expect(tetrisLineScore(1, 1), 100);
      expect(tetrisLineScore(2, 1), 300);
      expect(tetrisLineScore(3, 1), 500);
      expect(tetrisLineScore(4, 1), 800);
      expect(tetrisLineScore(4, 3), 2400);
    });

    test('уровень растёт каждые 10 линий', () {
      expect(tetrisLevelForLines(0), 1);
      expect(tetrisLevelForLines(9), 1);
      expect(tetrisLevelForLines(10), 2);
      expect(tetrisLevelForLines(25), 3);
    });

    test('скорость гравитации убывает и зажата снизу', () {
      expect(tetrisGravitySeconds(1), closeTo(0.80, 1e-9));
      expect(tetrisGravitySeconds(2) < tetrisGravitySeconds(1), isTrue);
      expect(tetrisGravitySeconds(99), 0.05);
    });
  });

  group('ViewModel', () {
    test('новая игра: идёт, есть фигура и очередь, счёт/уровень стартовые', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(123);
      final s = c.read(tetrisProvider);
      expect(s.status, TetrisStatus.playing);
      expect(s.piece, isNotNull);
      expect(s.queue.length, tetrisQueuePreview);
      expect(s.score, 0);
      expect(s.level, 1);
      expect(s.canHold, isTrue);
    });

    test('сдвиг ограничен стенами', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(1);
      // Двигаем максимально влево — фигура не уходит за край.
      for (int i = 0; i < 20; i++) {
        vm.move(-1);
      }
      final s = c.read(tetrisProvider);
      final minC = s.activeCells.map((e) => e.c).reduce((a, b) => a < b ? a : b);
      expect(minC, 0);
    });

    test('hard drop фиксирует фигуру и спавнит следующую', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(42);
      final before = c.read(tetrisProvider);
      vm.hardDrop();
      final after = c.read(tetrisProvider);
      expect(after.moveSeq, before.moveSeq + 1);
      // На поле появились занятые клетки.
      final filled =
          after.board.expand((row) => row).where((cell) => cell.filled).length;
      expect(filled, 4);
      expect(after.piece, isNotNull, reason: 'спавнилась следующая фигура');
    });

    test('hold кладёт фигуру и блокируется до следующей', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(7);
      final firstType = c.read(tetrisProvider).piece!.type;
      vm.hold();
      final s = c.read(tetrisProvider);
      expect(s.hold, firstType);
      expect(s.canHold, isFalse);
      // Повторный hold игнорируется.
      vm.hold();
      expect(c.read(tetrisProvider).hold, firstType);
    });

    test('gravity tick опускает фигуру со временем', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(99);
      final r0 = c.read(tetrisProvider).piece!.r;
      // Накопим больше одного интервала гравитации.
      vm.tick(tetrisGravitySeconds(1) + 0.01);
      final r1 = c.read(tetrisProvider).piece!.r;
      expect(r1, r0 + 1);
    });

    test('партия сходится к концу при бесконечных hard drop', () {
      final c = _c();
      final vm = c.read(tetrisProvider.notifier);
      vm.newGame(5);
      var guard = 0;
      while (!c.read(tetrisProvider).gameOver && guard < 1000) {
        vm.hardDrop();
        guard++;
      }
      expect(c.read(tetrisProvider).gameOver, isTrue);
      expect(c.read(tetrisProvider).piece, isNull);
    });
  });
}
