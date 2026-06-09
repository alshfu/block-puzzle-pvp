/// bot.dart — ИИ-бот трёх уровней (порт из `src/core/index.ts`).
///
/// За что отвечает файл:
///   Выбор хода ботом. Лёгкий уровень играет почти случайно (иногда хватает
///   очевидную очистку), средний и сложный — взвешенная эвристика поверх
///   симуляции каждого хода. Веса [botWeights] откалиброваны bot-vs-bot
///   прогонами; менять их без рекалибровки нельзя. Логика и порядок перебора
///   совпадают с TS, иначе разойдётся выбор и golden-партии.
///
/// Соответствие TS:
///   BotWeights / BOT_WEIGHTS / chooseBotMove → этот файл. Эвристики
///   (nearLines/countHoles/opponentThreatGain/simulate) — в `moves.dart`.
library;

import 'board.dart';
import 'moves.dart';
import 'rng.dart';
import 'scoring.dart';
import 'types.dart';

/// Веса оценочной функции бота. TS: `BotWeights`.
class BotWeights {
  /// Вес очков, заработанных ходом.
  final double gain;

  /// Вес «заготовок» (почти-готовых линий).
  final double nearLines;

  /// Штраф за «дырки».
  final double holes;

  /// Штраф за подарок сопернику простой очистки (Hard).
  final double oppThreat;

  /// Микрошум для разнообразия.
  final double noise;

  /// Вероятность для Easy схватить очевидную очистку.
  final double easyClearProb;

  /// Создаёт набор весов.
  const BotWeights({
    required this.gain,
    required this.nearLines,
    required this.holes,
    required this.oppThreat,
    required this.noise,
    required this.easyClearProb,
  });
}

/// Веса по уровням. Значения 1:1 с TS `BOT_WEIGHTS` (откалиброваны на 1000
/// партий на пару). Целевая дифференциация: medium >> easy, hard > medium.
const Map<BotLevel, BotWeights> botWeights = {
  BotLevel.easy: BotWeights(
    gain: 6,
    nearLines: 0.0,
    holes: 0.0,
    oppThreat: 0.0,
    noise: 0,
    easyClearProb: 0.30,
  ),
  BotLevel.medium: BotWeights(
    gain: 10,
    nearLines: 1.0,
    holes: 4.0,
    oppThreat: 0.0,
    noise: 0.01,
    easyClearProb: 0,
  ),
  BotLevel.hard: BotWeights(
    gain: 16,
    nearLines: 1.8,
    holes: 6.0,
    oppThreat: 1.2,
    noise: 0,
    easyClearProb: 0,
  ),
};

/// Выбирает ход бота заданного [level]. Возвращает `null`, если ходов нет.
///
/// Easy: с вероятностью `easyClearProb` берёт случайную очищающую постановку,
/// иначе — любую случайную. Medium/Hard: максимизируют взвешенную сумму
/// (очки + заготовки − дырки − угроза сопернику + шум). При равенстве очков
/// побеждает первый по порядку перебора (строгое `>`), что детерминированно.
/// [weightsOverride] позволяет подменить веса (для калибровки). TS:
/// `chooseBotMove`.
CandidateMove? chooseBotMove(
  Board board,
  List<PieceInstance> hand,
  BotLevel level,
  RuleConfig cfg,
  RandomSource rng, {
  BotWeights? weightsOverride,
}) {
  final moves = enumerateMoves(board, hand, cfg);
  if (moves.isEmpty) return null;
  final w = weightsOverride ?? botWeights[level]!;

  if (level == BotLevel.easy) {
    if (rng() < w.easyClearProb) {
      final scoring = moves
          .where((m) => simulate(board, m, 1).clears.count > 0)
          .toList();
      if (scoring.isNotEmpty) {
        return scoring[(rng() * scoring.length).floor()];
      }
    }
    return moves[(rng() * moves.length).floor()];
  }

  CandidateMove? best;
  var bestScore = double.negativeInfinity;
  for (final m in moves) {
    final sim = simulate(board, m, 1);
    final gain = scoreForMove(sim.clears.count, 0, sim.perfect, cfg);
    var s =
        w.gain * gain +
        w.nearLines * nearLines(sim.board) -
        w.holes * countHoles(sim.board);
    if (w.oppThreat > 0) {
      s -= w.oppThreat * opponentThreatGain(sim.board);
    }
    if (w.noise > 0) s += (rng() - 0.5) * w.noise;
    if (s > bestScore) {
      bestScore = s;
      best = m;
    }
  }
  return best;
}
