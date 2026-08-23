/// puzzle_test.dart — тесты режима «Силуэты» (pure: фигуры/генератор/ядро/пак).
///
/// Проверяют: нестандартный набор фигур и обобщённые ориентации; генератор
/// строит ТОЧНОЕ покрытие маски (разрешимость) и детерминирован; правила
/// постановки только внутри маски; решённость; скоринг/бюджет/награду; и что
/// КАЖДЫЙ уровень стартового пака разрешим (реплей эталонного решения решает
/// головоломку). Плюс JSON round-trip уровня.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/puzzle/puzzle_core.dart';
import 'package:block_duel/modes/puzzle/puzzle_generator.dart';
import 'package:block_duel/modes/puzzle/puzzle_notifier.dart';
import 'package:block_duel/modes/puzzle/puzzle_pack.dart';
import 'package:block_duel/modes/puzzle/puzzle_pieces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _c() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

/// Воспроизводит постановку [pl] из эталонного решения через публичный API
/// ViewModel (выбор экземпляра нужной формы → поворот до нужной ориентации →
/// постановка по якорю). Возвращает `true`, если получилось.
bool _replay(ProviderContainer c, PuzzlePlacement pl) {
  final vm = c.read(puzzleProvider.notifier);
  final st = c.read(puzzleProvider);
  final hp = st.hand.where((p) => p.shapeId == pl.shapeId).toList();
  if (hp.isEmpty) return false;
  vm.selectPiece(hp.first.instanceId);
  final target = normalize(pl.cells).toString();
  final os = puzzleOrientations(pl.shapeId);
  var minR = pl.cells.first.r, minC = pl.cells.first.c;
  for (final cell in pl.cells) {
    if (cell.r < minR) minR = cell.r;
    if (cell.c < minC) minC = cell.c;
  }
  for (int i = 0; i < os.length; i++) {
    if (os[i].toString() == target) {
      for (int k = 0; k < i; k++) {
        vm.rotate();
      }
      vm.placeAt(minR, minC);
      return true;
    }
  }
  return false;
}

void main() {
  group('фигуры', () {
    test('набор содержит тетромино + расширения', () {
      expect(puzzleBaseShapes.containsKey('I'), isTrue);
      expect(puzzleBaseShapes.containsKey(puzzleMini), isTrue);
      expect(puzzleBaseShapes.containsKey(puzzlePlus), isTrue);
      expect(puzzleShapeSize(puzzleMini), 1);
      expect(puzzleShapeSize(puzzlePlus), 5);
    });

    test('обобщённые ориентации: O — одна, T — четыре', () {
      expect(shapeOrientations(puzzleBaseShapes['O']!).length, 1);
      expect(
        shapeOrientations(puzzleBaseShapes['T']!, flip: false).length,
        4,
      );
    });
  });

  group('генератор', () {
    test('точно покрывает прямоугольную маску без наложений', () {
      final mask = <Coord>{
        for (int r = 0; r < 4; r++)
          for (int c = 0; c < 4; c++) Coord(r, c),
      };
      final sol = tilePuzzle(mask, PuzzleDifficulty.medium, 42);
      final covered = <Coord>{};
      var total = 0;
      for (final p in sol) {
        for (final cell in p.cells) {
          expect(mask.contains(cell), isTrue, reason: 'клетка вне маски');
          expect(covered.add(cell), isTrue, reason: 'наложение');
          total++;
        }
      }
      expect(total, mask.length, reason: 'покрыта вся маска');
    });

    test('детерминирован по seed', () {
      final mask = <Coord>{
        for (int r = 0; r < 5; r++)
          for (int c = 0; c < 3; c++) Coord(r, c),
      };
      final a = tilePuzzle(mask, PuzzleDifficulty.hard, 7);
      final b = tilePuzzle(mask, PuzzleDifficulty.hard, 7);
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(a[i].shapeId, b[i].shapeId);
        expect(a[i].cells.toString(), b[i].cells.toString());
      }
    });
  });

  group('ядро', () {
    test('постановка только внутри маски', () {
      final mask = {const Coord(0, 0), const Coord(0, 1)};
      final board = puzzleEmptyBoard(3, 3);
      expect(puzzleCanPlace(board, mask, puzzleBaseShapes[puzzleDomino]!, 0, 0),
          isTrue);
      // Домино из (1,0)-(1,1) — вне маски.
      expect(puzzleCanPlace(board, mask, puzzleBaseShapes[puzzleDomino]!, 1, 0),
          isFalse);
    });

    test('решённость: вся маска заполнена', () {
      final mask = {const Coord(0, 0), const Coord(0, 1)};
      final board = puzzleEmptyBoard(3, 3);
      expect(isPuzzleSolved(board, mask), isFalse);
      puzzlePlace(board, puzzleBaseShapes[puzzleDomino]!, 0, 0, 0);
      expect(isPuzzleSolved(board, mask), isTrue);
    });

    test('скоринг/бюджет/награда', () {
      final def = puzzleById('sym-cross')!;
      final budget = puzzleMoveBudget(def);
      expect(budget, def.pieceCount + 6); // easy slack
      // Меньше ходов → больше очки.
      expect(puzzleScore(def, def.pieceCount) > puzzleScore(def, budget), isTrue);
      expect(puzzleCoinReward(PuzzleDifficulty.expert), 100);
      expect(puzzleCoinReward(PuzzleDifficulty.easy), 10);
    });
  });

  group('контент-пак', () {
    test('каждый уровень разрешим (реплей решения решает головоломку)', () {
      expect(puzzlePack, isNotEmpty);
      for (final def in puzzlePack) {
        expect(def.mask, isNotEmpty, reason: '${def.id}: пустая маска');
        final board = puzzleEmptyBoard(def.width, def.height);
        for (int i = 0; i < def.solution.length; i++) {
          final cells = def.solution[i].cells;
          expect(
            puzzleCanPlace(board, def.mask, cells, 0, 0),
            isTrue,
            reason: '${def.id}: постановка $i невалидна',
          );
          puzzlePlace(board, cells, 0, 0, i);
        }
        expect(
          isPuzzleSolved(board, def.mask),
          isTrue,
          reason: '${def.id}: решение не покрывает маску',
        );
        expect(def.handShapeIds.length, def.solution.length);
      }
    });

    test('JSON round-trip уровня', () {
      final def = puzzlePack.first;
      final back = PuzzleDef.fromJson(def.toJson());
      expect(back.id, def.id);
      expect(back.width, def.width);
      expect(back.height, def.height);
      expect(back.difficulty, def.difficulty);
      expect(back.category, def.category);
      expect(back.mask.length, def.mask.length);
      expect(back.handShapeIds, def.handShapeIds);
    });

    test('fromJson: клетка решения вне сетки → FormatException (fail-fast)', () {
      // Битый внешний пак: сетка 3×3, но клетка (5,5) вне границ. Без валидации
      // это уронило бы RangeError позже в isPuzzleSolved/hint.
      final bad = {
        'id': 'bad',
        'name': 'X',
        'category': 'objects',
        'difficulty': 'easy',
        'w': 3,
        'h': 3,
        'solution': [
          {
            's': 'O',
            'c': [
              [5, 5],
            ],
          },
        ],
      };
      expect(() => PuzzleDef.fromJson(bad), throwsFormatException);
    });

    test('fromJson: недопустимый размер сетки → FormatException', () {
      final bad = {
        'id': 'bad',
        'name': 'X',
        'category': 'objects',
        'difficulty': 'easy',
        'w': 0,
        'h': 3,
        'solution': const [],
      };
      expect(() => PuzzleDef.fromJson(bad), throwsFormatException);
    });
  });

  group('ViewModel', () {
    test('загрузка: рука по числу фигур, не решено', () {
      final c = _c();
      final vm = c.read(puzzleProvider.notifier);
      final def = puzzleById('sym-cross')!;
      vm.loadPuzzle(def);
      final st = c.read(puzzleProvider);
      expect(st.hand.length, def.pieceCount);
      expect(st.solved, isFalse);
      expect(st.movesUsed, 0);
    });

    test('выбор и поворот фигуры', () {
      final c = _c();
      final vm = c.read(puzzleProvider.notifier);
      vm.loadPuzzle(puzzleById('sym-cross')!);
      final id = c.read(puzzleProvider).hand.first.instanceId;
      vm.selectPiece(id);
      expect(c.read(puzzleProvider).selectedInstanceId, id);
      vm.rotate();
      expect(c.read(puzzleProvider).orientIndex, 1);
    });

    test('undo возвращает фигуру в руку и очищает клетки', () {
      final c = _c();
      final vm = c.read(puzzleProvider.notifier);
      final def = puzzleById('sym-cross')!;
      vm.loadPuzzle(def);
      expect(_replay(c, def.solution.first), isTrue);
      final afterPlace = c.read(puzzleProvider);
      expect(afterPlace.hand.length, def.pieceCount - 1);
      expect(afterPlace.canUndo, isTrue);
      vm.undo();
      final afterUndo = c.read(puzzleProvider);
      expect(afterUndo.hand.length, def.pieceCount);
      expect(afterUndo.placed, isEmpty);
    });

    test('реплей эталонного решения через VM решает уровень', () {
      final c = _c();
      final vm = c.read(puzzleProvider.notifier);
      final def = puzzleById('sym-diamond')!;
      vm.loadPuzzle(def);
      for (final pl in def.solution) {
        expect(_replay(c, pl), isTrue, reason: 'не удалось поставить $pl');
      }
      final st = c.read(puzzleProvider);
      expect(st.solved, isTrue);
      expect(st.hand, isEmpty);
      expect(st.movesUsed, def.pieceCount);
      expect(st.score, puzzleScore(def, def.pieceCount));
    });
  });
}
