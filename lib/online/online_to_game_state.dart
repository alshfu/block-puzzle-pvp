/// online_to_game_state.dart — адаптер серверного состояния в [GameState].
///
/// За что отвечает файл:
///   Строит локальный [GameState] из серверного [OnlineGameState], чтобы
///   переиспользовать существующие игровые виджеты (BoardView/HandView/
///   Scoreboard/TurnTimer) без дублирования. Выбор фигуры
///   (`selectedPieceId`/`orientIndex`) — локальное состояние онлайна, его
///   накладывает View через `copyWith`.
///
/// Маппинг: board → board; два OnlinePlayerView → PlayerState; `current` с
/// сервера; `gameOver` = status "over"; `winner` из result (`-1` → null/ничья);
/// таймер из ms → секунды; cfg как есть.
library;

import '../game/game_state.dart';
import 'online_models.dart';

/// Преобразует [s] в [GameState]; [you] — индекс локального игрока (для UI).
GameState onlineToGameState(OnlineGameState s, {required int you}) {
  final players = [
    for (final p in s.players)
      PlayerState(score: p.score, combo: p.combo, hand: p.hand, name: p.nick),
  ];
  final result = s.result;
  final winner = result == null || result.winner < 0 ? null : result.winner;
  return GameState(
    board: s.board,
    players: players,
    current: s.current,
    round: s.turnCount ~/ 2,
    gameOver: s.isOver,
    winner: winner,
    selectedPieceId: null,
    orientIndex: 0,
    turnLimit: s.turnTimeBaseMs / 1000.0,
    turnRemaining: s.turnTimeRemainingMs / 1000.0,
    cfg: s.cfg,
  );
}
