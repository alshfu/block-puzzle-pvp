/// memory_solo_test.dart — тесты pure-ядра режима «Память: соло».
///
/// Проверяют: детерминизм генерации (тот же seed → та же раскладка и рука),
/// корректность раскладки (нет очисток, нужное число фигур/клеток, рука
/// соответствует раскладке) и скоринг (точность, штраф за брак, perfect-бонус,
/// тайм-бонус). Ядро pure — тестируется без Flutter-окружения.
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/modes/memory_solo/memory_solo_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Сериализует доску в строку «заполненности» для сравнения раскладок.
String _boardKey(Board b) => [
  for (final row in b) row.map((cell) => cell.filled ? '1' : '0').join(),
].join('/');

/// Считает заполненные клетки доски.
int _filled(Board b) {
  var n = 0;
  for (final row in b) {
    for (final cell in row) {
      if (cell.filled) n++;
    }
  }
  return n;
}

void main() {
  group('generateMemoryPuzzle', () {
    test('детерминизм: тот же seed → та же раскладка и рука', () {
      final a = generateMemoryPuzzle(MemoryDifficulty.medium, 12345);
      final b = generateMemoryPuzzle(MemoryDifficulty.medium, 12345);
      expect(_boardKey(a.target), _boardKey(b.target));
      expect(
        a.hand.map((p) => p.type).toList(),
        b.hand.map((p) => p.type).toList(),
      );
      expect(a.totalCells, b.totalCells);
    });

    test('разные seed → как правило разные раскладки', () {
      final a = generateMemoryPuzzle(MemoryDifficulty.medium, 1);
      final b = generateMemoryPuzzle(MemoryDifficulty.medium, 2);
      expect(_boardKey(a.target), isNot(_boardKey(b.target)));
    });

    test('раскладка валидна для всех уровней: число фигур, клеток, без очисток',
        () {
      for (final diff in MemoryDifficulty.values) {
        final p = generateMemoryPuzzle(diff, 99);
        expect(p.hand.length, diff.pieceCount,
            reason: 'рука должна содержать ${diff.pieceCount} фигур');
        expect(p.totalCells, diff.pieceCount * 4);
        expect(_filled(p.target), diff.pieceCount * 4,
            reason: 'клетки = 4 на фигуру, без наложений');
        expect(findClears(p.target).count, 0,
            reason: 'раскладка не должна содержать готовых очисток');
      }
    });

    test('рука по типам совпадает с фигурами раскладки (мультимножество)', () {
      final p = generateMemoryPuzzle(MemoryDifficulty.hard, 7);
      // Каждая фигура руки в базовой ориентации соответствует своему типу.
      for (final piece in p.hand) {
        expect(piece.cells, normalize(baseShapes[piece.type]!));
      }
    });
  });

  group('scoreMemory', () {
    test('идеальное воспроизведение → accuracy 1.0, perfect, бонус', () {
      final p = generateMemoryPuzzle(MemoryDifficulty.easy, 555);
      final res = scoreMemory(p.target, p.target, timeRatio: 1.0);
      expect(res.accuracy, 1.0);
      expect(res.correctCells, p.totalCells);
      expect(res.wrongCells, 0);
      expect(res.perfect, isTrue);
      expect(res.score, greaterThan(0));
    });

    test('пустая попытка → accuracy 0, score 0', () {
      final p = generateMemoryPuzzle(MemoryDifficulty.easy, 555);
      final res = scoreMemory(p.target, emptyBoard(), timeRatio: 1.0);
      expect(res.accuracy, 0.0);
      expect(res.correctCells, 0);
      expect(res.perfect, isFalse);
      expect(res.score, 0);
    });

    test('частичное совпадение → точность строго между 0 и 1', () {
      final target = emptyBoard();
      target[0][0].filled = true;
      target[0][1].filled = true;
      target[0][2].filled = true;
      target[0][3].filled = true;
      final player = emptyBoard();
      player[0][0].filled = true;
      player[0][1].filled = true;
      final res = scoreMemory(target, player, timeRatio: 0.0);
      expect(res.totalCells, 4);
      expect(res.correctCells, 2);
      expect(res.accuracy, closeTo(0.5, 1e-9));
      expect(res.perfect, isFalse);
    });

    test('лишние клетки штрафуют очки, но accuracy остаётся correct/total', () {
      final target = emptyBoard();
      for (var c = 0; c < 4; c++) {
        target[0][c].filled = true;
      }
      final player = emptyBoard();
      for (var c = 0; c < 4; c++) {
        player[0][c].filled = true; // 4 верных
      }
      player[5][5].filled = true; // 1 лишняя
      player[5][6].filled = true; // ещё 1 лишняя
      final res = scoreMemory(target, player, timeRatio: 0.0);
      expect(res.correctCells, 4);
      expect(res.wrongCells, 2);
      expect(res.accuracy, 1.0); // correct/total
      expect(res.perfect, isFalse); // но не идеально из-за лишних
    });

    test('тайм-бонус растёт с оставшимся временем', () {
      final p = generateMemoryPuzzle(MemoryDifficulty.easy, 7);
      final slow = scoreMemory(p.target, p.target, timeRatio: 0.0);
      final fast = scoreMemory(p.target, p.target, timeRatio: 1.0);
      expect(fast.timeBonus, greaterThan(slow.timeBonus));
      expect(fast.score, greaterThan(slow.score));
    });
  });
}
