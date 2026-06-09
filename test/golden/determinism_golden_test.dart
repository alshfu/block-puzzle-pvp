/// determinism_golden_test.dart — главный gate Фазы 1: сверка Dart-ядра с
/// golden-эталоном TS-ядра по всем слоям.
///
/// За что отвечает файл:
///   Проверяет, что Dart-порт воспроизводит TS-ядро бит-в-бит по секциям
///   эталона `test/golden/determinism_match.json`: bag, orientations, scoring,
///   clears и полная детерминированная партия (game). PRNG проверяется
///   отдельно в `rng_golden_test.dart`. Харнесс партии повторяет TS
///   (`tools/dump-golden.ts` / `tests/determinism.test.ts`): на каждом ходу
///   берётся первый ход, без участия rng в решениях.
///
/// Кодировка доски совпадает с TS: 81 символ, row-major, '.'=пусто,
/// '0'/'1'=владелец.
library;

import 'dart:convert';
import 'dart:io';

import 'package:block_duel/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Парсит буквенный код фигуры ('I'…'L') в [PieceType].
PieceType _pieceFromCode(String code) =>
    allTypes.firstWhere((t) => pieceTypeCode(t) == code);

/// Кодирует доску так же, как TS `encodeBoard` в `tools/dump-golden.ts`.
String _encodeBoard(Board board) {
  final sb = StringBuffer();
  for (int r = 0; r < boardSize; r++) {
    for (int c = 0; c < boardSize; c++) {
      final cell = board[r][c];
      sb.write(cell.filled ? '${cell.owner ?? 0}' : '.');
    }
  }
  return sb.toString();
}

/// Восстанавливает доску из строковой кодировки (обратное к [_encodeBoard]).
Board _decodeBoard(String encoded) {
  final board = emptyBoard();
  for (int i = 0; i < encoded.length; i++) {
    final ch = encoded[i];
    if (ch == '.') continue;
    final r = i ~/ boardSize;
    final c = i % boardSize;
    board[r][c] = Cell(filled: true, owner: int.parse(ch));
  }
  return board;
}

/// Результат прогона детерминированной партии (для сравнения с golden).
class _GameRun {
  final int movesPlayed;
  final String finalBoard;
  final List<int> scores;
  final List<int> combos;
  final List<Map<String, dynamic>> moves;

  _GameRun(
    this.movesPlayed,
    this.finalBoard,
    this.scores,
    this.combos,
    this.moves,
  );
}

/// Повторяет детерминированный харнесс партии из `tools/dump-golden.ts`.
_GameRun _runGame(int seedA, int seedB, int turns) {
  const cfg = defaultConfig;
  final bags = [Bag(seedA), Bag(seedB)];
  final board = emptyBoard();
  final hands = <List<PieceInstance>>[
    [bags[0].draw(), bags[0].draw(), bags[0].draw()],
    [bags[1].draw(), bags[1].draw(), bags[1].draw()],
  ];
  final scores = [0, 0];
  final combos = [0, 0];
  final moves = <Map<String, dynamic>>[];

  for (int t = 0; t < turns; t++) {
    final player = t % 2;
    final hand = hands[player];
    if (!hasAnyMove(board, hand, cfg)) break;
    final m = enumerateMoves(board, hand, cfg).first;
    place(board, m.cells, m.r, m.c, player);
    final clears = findClears(board);
    applyClears(board, clears.cleared);
    final perfect = clears.count > 0 && isPerfectClear(board);
    final gained = scoreForMove(clears.count, combos[player], perfect, cfg);
    scores[player] += gained;
    combos[player] = clears.count > 0 ? combos[player] + 1 : 0;

    moves.add({
      't': t,
      'player': player,
      'pieceId': m.pieceId,
      'type': pieceTypeCode(m.type),
      'r': m.r,
      'c': m.c,
      'cells': [
        for (final cell in m.cells) [cell.r, cell.c],
      ],
      'clearCount': clears.count,
      'perfect': perfect,
      'gained': gained,
      'scoreAfter': scores[player],
      'comboAfter': combos[player],
    });

    hand.removeWhere((p) => p.id == m.pieceId);
    hand.add(bags[player].draw());
  }

  return _GameRun(moves.length, _encodeBoard(board), scores, combos, moves);
}

void main() {
  final golden =
      jsonDecode(File('test/golden/determinism_match.json').readAsStringSync())
          as Map<String, dynamic>;

  group('bag vs golden', () {
    for (final dynamic entry in golden['bag'] as List<dynamic>) {
      final e = entry as Map<String, dynamic>;
      final seed = e['seed'] as int;
      final expected = (e['types'] as List<dynamic>).cast<String>();
      test('seed=$seed — та же последовательность фигур', () {
        final bag = Bag(seed);
        for (int i = 0; i < expected.length; i++) {
          expect(pieceTypeCode(bag.draw().type), expected[i], reason: 'i=$i');
        }
      });
    }
  });

  group('orientations vs golden', () {
    final orient = golden['orientations'] as Map<String, dynamic>;
    for (final code in orient.keys) {
      test('фигура $code — те же ориентации', () {
        final expected = (orient[code] as List<dynamic>)
            .map(
              (o) => (o as List<dynamic>).map((p) => (p as List).cast<int>()),
            )
            .toList();
        final got = orientations(_pieceFromCode(code), true, true);
        expect(got.length, expected.length);
        for (int i = 0; i < got.length; i++) {
          final wantCells = expected[i].toList();
          expect(got[i].length, wantCells.length);
          for (int k = 0; k < got[i].length; k++) {
            expect(got[i][k].r, wantCells[k][0], reason: '$code o=$i p=$k r');
            expect(got[i][k].c, wantCells[k][1], reason: '$code o=$i p=$k c');
          }
        }
      });
    }
  });

  group('scoring vs golden', () {
    final cases = golden['scoring'] as List<dynamic>;
    for (int idx = 0; idx < cases.length; idx++) {
      final caseObj = cases[idx] as Map<String, dynamic>;
      final input = caseObj['input'] as Map<String, dynamic>;
      test('case#$idx', () {
        final rows = input['rows'] as int;
        final cols = input['cols'] as int;
        final boxes = input['boxes'] as int;
        final combo = input['combo'] as int;
        final perfect = input['perfect'] as bool;
        final pieceType = _pieceFromCode(input['pieceType'] as String);
        final timeRatio = (input['timeRatio'] as num).toDouble();

        expect(
          scoreForMove(rows + cols + boxes, combo, perfect, defaultConfig),
          caseObj['scoreForMove'] as int,
        );

        final detailed = scoreMoveDetailed(
          ScoreInput(
            rows: rows,
            cols: cols,
            boxes: boxes,
            pieceType: pieceType,
            combo: combo,
            perfect: perfect,
            timeRatio: timeRatio,
            cfg: defaultConfig,
          ),
        );
        final want = caseObj['detailed'] as Map<String, dynamic>;
        expect(detailed.total, want['total'] as int);
        expect(detailed.base, want['base'] as int);
        expect(detailed.placement, want['placement'] as int);
        expect(detailed.perfectBonus, want['perfectBonus'] as int);
        expect(
          detailed.multiClearMult,
          closeTo((want['multiClearMult'] as num).toDouble(), 1e-9),
        );
        expect(
          detailed.comboMult,
          closeTo((want['comboMult'] as num).toDouble(), 1e-9),
        );
        expect(
          detailed.speedMult,
          closeTo((want['speedMult'] as num).toDouble(), 1e-9),
        );
      });
    }
  });

  group('clears vs golden', () {
    for (final dynamic entry in golden['clears'] as List<dynamic>) {
      final e = entry as Map<String, dynamic>;
      test('сценарий ${e['name']}', () {
        final board = _decodeBoard(e['board'] as String);
        final res = findClears(board);
        expect(res.count, e['count'] as int);
        expect(res.rows, (e['rows'] as List).cast<int>());
        expect(res.cols, (e['cols'] as List).cast<int>());
        expect(res.boxes, (e['boxes'] as List).cast<int>());
        expect(res.cleared.length, e['clearedCount'] as int);
      });
    }
  });

  group('game vs golden (полный gate детерминизма)', () {
    for (final dynamic entry in golden['game'] as List<dynamic>) {
      final g = entry as Map<String, dynamic>;
      final seedA = g['seedA'] as int;
      final seedB = g['seedB'] as int;
      final turns = g['turns'] as int;
      test('партия seedA=$seedA seedB=$seedB turns=$turns', () {
        final run = _runGame(seedA, seedB, turns);
        expect(run.movesPlayed, g['movesPlayed'] as int, reason: 'movesPlayed');
        expect(run.finalBoard, g['finalBoard'] as String, reason: 'board');
        expect(run.scores, (g['scores'] as List).cast<int>(), reason: 'scores');
        expect(run.combos, (g['combos'] as List).cast<int>(), reason: 'combos');

        final wantMoves = g['moves'] as List<dynamic>;
        expect(run.moves.length, wantMoves.length);
        for (int i = 0; i < run.moves.length; i++) {
          final got = run.moves[i];
          final want = wantMoves[i] as Map<String, dynamic>;
          for (final field in [
            'player',
            'pieceId',
            'type',
            'r',
            'c',
            'clearCount',
            'perfect',
            'gained',
            'scoreAfter',
            'comboAfter',
          ]) {
            expect(got[field], want[field], reason: 'move#$i.$field');
          }
        }
      });
    }
  });
}
