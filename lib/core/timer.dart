/// timer.dart — blitz-таймер и force-place (порт из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Чистые функции таймера: [turnTimeForRound] — сколько секунд даётся на ход
///   в заданном раунде, и [forcePlace] — выбор валидного хода при таймауте
///   (ТЗ §2.7.1). Само тиканье таймера — на UI; ядро лишь хранит параметры и
///   предоставляет эти функции.
///
/// Соответствие TS:
///   turnTimeForRound / forcePlace → этот файл.
library;

import 'board.dart';
import 'moves.dart';
import 'rng.dart';
import 'types.dart';

/// Время (секунды) на ход для номера [round] (раунд = пара ходов обоих
/// игроков). Если таймер выключен — `double.infinity`. Иначе линейно убывает
/// от `turnTimeStart` с шагом `turnTimeDecay`, но не ниже `turnTimeMin`.
/// TS: `turnTimeForRound`.
double turnTimeForRound(int round, RuleConfig cfg) {
  if (!cfg.turnTimerEnabled) return double.infinity;
  final clampedRound = round > 0 ? round : 0;
  final t = cfg.turnTimeStart - cfg.turnTimeDecay * clampedRound;
  return t > cfg.turnTimeMin ? t : cfg.turnTimeMin;
}

/// Возвращает случайный валидный ход на таймауте, либо `null` при тупике.
///
/// Если задан [preferredPieceId] и эта фигура ещё может встать — выбирается её
/// случайная валидная позиция; иначе случайная пара (фигура, позиция) из всей
/// руки. TS: `forcePlace`.
CandidateMove? forcePlace(
  Board board,
  List<PieceInstance> hand,
  RuleConfig cfg,
  RandomSource rng, {
  String? preferredPieceId,
}) {
  final all = enumerateMoves(board, hand, cfg);
  if (all.isEmpty) return null;
  if (preferredPieceId != null) {
    final subset = all.where((m) => m.pieceId == preferredPieceId).toList();
    if (subset.isNotEmpty) {
      return subset[(rng() * subset.length).floor()];
    }
  }
  return all[(rng() * all.length).floor()];
}
