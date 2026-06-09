/// online_to_game_state_test.dart — тесты адаптера OnlineGameState→GameState.
///
/// Проверяем маппинг для переиспользования игровых виджетов: игроки/счёт/ход,
/// таймер ms→секунды, gameOver из status, winner из result (-1 → null/ничья).
library;

import 'dart:convert';

import 'package:block_duel/online/online_models.dart';
import 'package:block_duel/online/online_to_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'online_samples.dart';

OnlineGameState _parse(Map<String, dynamic> json) => OnlineGameState.fromJson(
  jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
);

void main() {
  test('маппит игроков, ход и таймер (ms→сек)', () {
    final s = _parse(sampleStateJson(current: 1));
    final gs = onlineToGameState(s, you: 0);
    expect(gs.players.length, 2);
    expect(gs.players[0].name, 'Алиса');
    expect(gs.players[0].score, 30);
    expect(gs.current, 1);
    expect(gs.gameOver, isFalse);
    expect(gs.turnLimit, 60.0);
    expect(gs.turnRemaining, 45.0);
    expect(gs.currentPlayer.hand.length, 2); // рука игрока, чей ход
  });

  test('gameOver и winner из result', () {
    final s = _parse(
      sampleStateJson(
        status: 'over',
        result: {
          'winner': 1,
          'scores': [10, 20],
        },
      ),
    );
    final gs = onlineToGameState(s, you: 0);
    expect(gs.gameOver, isTrue);
    expect(gs.winner, 1);
  });

  test('ничья (-1) → winner null', () {
    final s = _parse(
      sampleStateJson(
        status: 'over',
        result: {
          'winner': -1,
          'scores': [20, 20],
        },
      ),
    );
    final gs = onlineToGameState(s, you: 0);
    expect(gs.gameOver, isTrue);
    expect(gs.winner, isNull);
  });
}
