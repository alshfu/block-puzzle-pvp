/// core_behavior_test.dart — поведенческие unit-тесты ядра (зеркало
/// `tests/{deadlock,bot,timer,bag,clears,scoring}.test.ts`).
///
/// За что отвечает файл:
///   Проверяет инварианты ядра, которые golden-эталон не фиксирует напрямую:
///   корректность тупика и force-place, валидность ходов бота на всех уровнях,
///   значения blitz-таймера, антидубль в `drawAvoiding`, базовую интеграцию
///   доски и очисток. Дополняет golden-gate (`determinism_golden_test.dart`).
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Полностью заполняет доску (для сценариев тупика).
Board _fullBoard() {
  final board = emptyBoard();
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      board[r][c] = Cell(filled: true, owner: 0);
    }
  }
  return board;
}

/// Собирает руку из заданных типов с предсказуемыми id.
List<PieceInstance> _hand(List<PieceType> types) => [
  for (int i = 0; i < types.length; i++)
    PieceInstance(
      id: 'h$i',
      type: types[i],
      cells: normalize(baseShapes[types[i]]!),
    ),
];

void main() {
  group('тупик и forcePlace', () {
    test('пустая доска — ходы есть, полная — нет', () {
      final hand = _hand([PieceType.i]);
      expect(hasAnyMove(emptyBoard(), hand, defaultConfig), isTrue);
      expect(hasAnyMove(_fullBoard(), hand, defaultConfig), isFalse);
    });

    test('forcePlace на полной доске возвращает null', () {
      final move = forcePlace(
        _fullBoard(),
        _hand([PieceType.o]),
        defaultConfig,
        makeRng(1),
      );
      expect(move, isNull);
    });

    test('forcePlace возвращает валидную постановку', () {
      final board = emptyBoard();
      final move = forcePlace(
        board,
        _hand([PieceType.t]),
        defaultConfig,
        makeRng(42),
      );
      expect(move, isNotNull);
      expect(canPlace(board, move!.cells, move.r, move.c), isTrue);
    });

    test('forcePlace уважает preferredPieceId, пока тот может встать', () {
      final board = emptyBoard();
      final hand = _hand([PieceType.i, PieceType.o]);
      final move = forcePlace(
        board,
        hand,
        defaultConfig,
        makeRng(7),
        preferredPieceId: hand[1].id,
      );
      expect(move, isNotNull);
      expect(move!.pieceId, hand[1].id);
    });
  });

  group('бот — валидность на всех уровнях', () {
    for (final level in BotLevel.values) {
      test('$level выбирает валидный ход на пустой доске', () {
        final board = emptyBoard();
        final hand = _hand([PieceType.l, PieceType.s, PieceType.z]);
        final move = chooseBotMove(
          board,
          hand,
          level,
          defaultConfig,
          makeRng(3),
        );
        expect(move, isNotNull);
        expect(canPlace(board, move!.cells, move.r, move.c), isTrue);
      });

      test('$level возвращает null при тупике', () {
        final move = chooseBotMove(
          _fullBoard(),
          _hand([PieceType.i]),
          level,
          defaultConfig,
          makeRng(3),
        );
        expect(move, isNull);
      });
    }
  });

  group('blitz-таймер', () {
    test('раунд 0 = старт; убывает; не ниже минимума', () {
      expect(turnTimeForRound(0, defaultConfig), defaultConfig.turnTimeStart);
      expect(
        turnTimeForRound(1, defaultConfig),
        closeTo(
          defaultConfig.turnTimeStart - defaultConfig.turnTimeDecay,
          1e-9,
        ),
      );
      // На большом раунде упирается в нижнюю границу.
      expect(turnTimeForRound(1000, defaultConfig), defaultConfig.turnTimeMin);
    });

    test('выключенный таймер — бесконечность', () {
      const cfg = RuleConfig(
        handSize: 3,
        rotationEnabled: true,
        flipEnabled: true,
        sharedBag: false,
        comboEnabled: true,
        comboCap: 10,
        comboStep: 0.1,
        perfectClearBonus: 25,
        scoreRowPts: 10,
        scoreColPts: 10,
        scoreBoxPts: 15,
        multiClearStep: 0.15,
        comboExpStep: 0.02,
        speedBonusMax: 0.4,
        placementBonus: {},
        turnTimerEnabled: false,
        turnTimeStart: 12.0,
        turnTimeDecay: 0.4,
        turnTimeMin: 3.0,
        onTimeout: TimeoutPolicy.forcePlace,
      );
      expect(turnTimeForRound(0, cfg), double.infinity);
    });
  });

  group('7-bag drawAvoiding', () {
    test('избегает повтора типа, когда это возможно', () {
      final bag = Bag(123);
      final first = bag.draw();
      // Просим следующую фигуру с другим типом — мешок ещё не пуст.
      final second = bag.drawAvoiding({first.type});
      expect(second.type, isNot(first.type));
    });
  });

  group('доска и очистки', () {
    test('заполнение строки даёт ровно одну очистку строки', () {
      final board = emptyBoard();
      for (int c = 0; c < boardSize; c++) {
        place(board, const [Coord(0, 0)], 0, c, 0);
      }
      final res = findClears(board);
      expect(res.rows, [0]);
      expect(res.cols, isEmpty);
      expect(res.count, 1);
      expect(res.cleared.length, boardSize);
    });

    test('scoreForMove без очисток и без perfect = 0', () {
      expect(scoreForMove(0, 0, false, defaultConfig), 0);
    });
  });
}
