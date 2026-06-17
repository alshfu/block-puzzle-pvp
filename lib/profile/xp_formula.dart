/// xp_formula.dart — структурированная формула начисления XP за матч (Model).
///
/// За что отвечает файл:
///   Pure-функция награды опыта по итогу партии (ROADMAP § 8.1):
///   `xp = floor(baseXp · resultMult · diffMult · streakBonus)`. Отделяет баланс
///   прогрессии от ViewModel: контроллер профиля лишь вызывает [xpForMatch] с
///   исходом, сложностью соперника и текущей серией побед. Кривая уровней —
///   в `profile.dart` (`xpToReachLevel`).
///
/// Без UI/IO/случайности — детерминированная функция входов (легко тестируется).
library;

import 'package:block_duel/core/core.dart' show BotLevel;

/// Исход матча для расчёта XP.
enum MatchOutcome {
  /// Победа.
  win,

  /// Ничья.
  draw,

  /// Поражение.
  loss,
}

/// Базовый опыт за матч (до множителей). ROADMAP § 8.1.
const int matchBaseXp = 50;

/// Нижняя/верхняя границы множителя сложности.
const double minDiffMult = 0.7;
const double maxDiffMult = 1.6;

/// Множитель за результат: победа 1.0 / ничья 0.5 / поражение 0.0
/// (ROADMAP § 8.1 — за поражение опыт по формуле не начисляется; ачивки дают
/// XP отдельно).
double resultMultiplier(MatchOutcome outcome) => switch (outcome) {
  MatchOutcome.win => 1.0,
  MatchOutcome.draw => 0.5,
  MatchOutcome.loss => 0.0,
};

/// Множитель сложности по уровню бота: easy 0.7 / medium 1.0 / hard 1.3.
double diffMultForBot(BotLevel level) => switch (level) {
  BotLevel.easy => 0.7,
  BotLevel.medium => 1.0,
  BotLevel.hard => 1.3,
};

/// Множитель сложности для онлайн-матча по разнице ELO: чем сильнее соперник
/// относительно игрока, тем выше награда. `1.0` при равных, растёт/падает на
/// 0.1 за каждые 50 пунктов разницы, зажат в `[minDiffMult, maxDiffMult]`.
double diffMultForElo(int myElo, int opponentElo) {
  final mult = 1.0 + (opponentElo - myElo) / 500.0;
  return mult.clamp(minDiffMult, maxDiffMult);
}

/// Множитель за серию побед: `1 + 0.05·streak`, не более 1.5 (cap при streak≥10).
double streakBonus(int winStreak) {
  if (winStreak <= 0) return 1.0;
  return (1.0 + 0.05 * winStreak).clamp(1.0, 1.5);
}

/// Опыт за матч: `floor(baseXp · resultMult · diffMult · streakBonus)`.
///
/// [diffMult] зажимается в `[minDiffMult, maxDiffMult]` (но 0 при поражении даст
/// 0 в любом случае). [winStreak] — серия побед игрока с учётом этого матча.
int xpForMatch({
  required MatchOutcome outcome,
  double diffMult = 1.0,
  int winStreak = 0,
}) {
  final d = diffMult.clamp(minDiffMult, maxDiffMult);
  final value =
      matchBaseXp * resultMultiplier(outcome) * d * streakBonus(winStreak);
  return value.floor();
}
