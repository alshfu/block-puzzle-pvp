/// engine.dart — движок прогресса достижений (Model, чистый).
///
/// За что отвечает файл:
///   Порт `src/ui/achievements/engine.ts`: по контексту матча и накопительной
///   статистике обновляет прогресс достижений и возвращает ВПЕРВЫЕ
///   разблокированные (для тостов). Чистые функции — `nowMs` передаётся
///   снаружи (детерминизм в тестах).
///
/// Соответствие TS: `engine.ts` (processMatchAchievements / processOnline...).
library;

import 'achievement.dart';
import 'definitions.dart';

/// Контекст одной офлайн-партии для оценки достижений.
class MatchContext {
  /// Победитель: 0 (ты) / 1 / -1 (ничья).
  final int winner;

  /// Был ли perfect clear в матче.
  final bool hadPerfectClear;

  /// Максимум линий/боксов одним ходом за матч.
  final int maxMultiClear;

  /// Лучшее комбо за матч.
  final int bestCombo;

  /// Режим (`bot`/`hotseat`/`botvbot`).
  final String mode;

  /// Уровень бота (`easy`/`medium`/`hard`) или null.
  final String? botLevel;

  /// Статистика ПОСЛЕ применения матча.
  final Stats statsAfter;

  /// Текущий стрик побед.
  final int winStreak;

  /// Стрик партий через «Реванш».
  final int rematchStreak;

  const MatchContext({
    required this.winner,
    required this.hadPerfectClear,
    required this.maxMultiClear,
    required this.bestCombo,
    required this.mode,
    required this.botLevel,
    required this.statsAfter,
    required this.winStreak,
    this.rematchStreak = 0,
  });
}

/// Контекст одного онлайн-матча для оценки достижений.
class OnlineMatchInfo {
  final bool won;
  final bool drew;
  final int scoreGap;
  final int opponentScore;
  final int turnCount;
  final int maxMultiClear;
  final int bestCombo;
  final String? reason;
  final String themeId;
  final String opponentId;
  final int? myElo;

  const OnlineMatchInfo({
    required this.won,
    required this.drew,
    required this.scoreGap,
    required this.opponentScore,
    required this.turnCount,
    required this.maxMultiClear,
    required this.bestCombo,
    required this.themeId,
    required this.opponentId,
    this.reason,
    this.myElo,
  });
}

/// Результат прогона движка: новый прогресс + впервые разблокированные.
typedef EngineResult = ({
  Map<String, AchProgress> progress,
  List<AchievementDef> unlocked,
});

/// Применяет прогресс одного достижения [id] до значения [current] в [next];
/// уже разблокированное не трогает; при достижении цели — фиксирует unlock.
void _set(
  Map<String, AchProgress> next,
  List<AchievementDef> unlocked,
  int nowMs,
  String id,
  int current,
) {
  final def = achievementsById[id];
  if (def == null) return;
  final before = next[id];
  if (before != null && before.unlocked) return;
  final cur = (before?.current ?? 0) > current ? before!.current : current;
  if (cur >= def.total) {
    next[id] = AchProgress(current: def.total, unlockedAt: nowMs);
    unlocked.add(def);
  } else {
    next[id] = AchProgress(current: cur);
  }
}

/// Применяет офлайн-партию [ctx] к прогрессу [prev].
EngineResult processMatch(
  Map<String, AchProgress> prev,
  MatchContext ctx,
  int nowMs,
) {
  final next = {...prev};
  final unlocked = <AchievementDef>[];
  void set(String id, int v) => _set(next, unlocked, nowMs, id, v);

  final wonVsAi = ctx.winner == 0 && ctx.mode == 'bot';

  // single
  set('first_blood', ctx.winner == 0 ? 1 : 0);
  set('flawless', ctx.hadPerfectClear ? 1 : 0);
  set('combinator', ctx.maxMultiClear >= 4 ? 1 : 0);
  set('ai_tamer', wonVsAi && ctx.botLevel == 'hard' ? 1 : 0);
  set('strategist', ctx.bestCombo);

  // progressive
  set('cleaner_100', ctx.statsAfter.totalClears);
  set('cleaner_1k', ctx.statsAfter.totalClears);
  set('cleaner_10k', ctx.statsAfter.totalClears);
  set('veteran_10', ctx.statsAfter.games);
  set('veteran_100', ctx.statsAfter.games);

  // series
  set('streak_3', ctx.winStreak);
  set('streak_5', ctx.winStreak);
  set('streak_10', ctx.winStreak);

  // hidden
  set('king_five', ctx.maxMultiClear >= 5 ? 1 : 0);
  set('persistence', ctx.rematchStreak);

  return (progress: next, unlocked: unlocked);
}

/// Применяет онлайн-матч ([s] — статистика после, [m] — контекст матча).
EngineResult processOnlineMatch(
  Map<String, AchProgress> prev,
  Stats s,
  OnlineMatchInfo m,
  int nowMs,
) {
  final next = {...prev};
  final unlocked = <AchievementDef>[];
  void set(String id, int v) => _set(next, unlocked, nowMs, id, v);

  for (final t in [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500]) {
    set('on_w_$t', s.onlineWins);
  }
  for (final t in [10, 50, 100, 250, 500, 1000, 5000, 10000]) {
    set(t == 10000 ? 'on_g_10k' : 'on_g_$t', s.onlineGames);
  }
  for (final t in [3, 5, 7, 10, 15, 20, 25, 50]) {
    set('on_s_$t', s.onlineCurrentWinStreak);
  }
  for (final t in [5, 10, 25, 50]) {
    set('on_nl_$t', s.onlineCurrentNoLossStreak);
  }
  if (m.myElo != null) {
    for (final t in [
      1100,
      1200,
      1300,
      1400,
      1500,
      1600,
      1700,
      1800,
      1900,
      2000,
    ]) {
      set('on_e_$t', m.myElo!);
    }
  }
  for (final t in [100, 500, 1000, 5000, 10000]) {
    final key = t == 1000
        ? 'on_c_1k'
        : t == 5000
        ? 'on_c_5k'
        : t == 10000
        ? 'on_c_10k'
        : 'on_c_$t';
    set(key, s.onlineTotalClears);
  }
  for (final t in [1, 5, 10, 25, 50]) {
    set('on_p_$t', s.onlineTotalPerfects);
  }

  if (m.maxMultiClear >= 3) set('on_mc_3', 1);
  if (m.maxMultiClear >= 4) set('on_mc_4', 1);
  if (m.maxMultiClear >= 5) set('on_mc_5', 1);
  if (m.maxMultiClear >= 6) set('on_mc_6', 1);
  set('on_co_3', m.bestCombo);
  set('on_co_5', m.bestCombo);
  set('on_co_8', m.bestCombo);
  set('on_co_10', m.bestCombo);

  if (m.won) {
    if (m.scoreGap >= 10) set('on_gap_10', 1);
    if (m.scoreGap >= 25) set('on_gap_25', 1);
    if (m.scoreGap >= 50) set('on_gap_50', 1);
    if (m.scoreGap >= 100) set('on_gap_100', 1);
    if (m.scoreGap >= 200) set('on_gap_200', 1);
    if (m.scoreGap == 1) set('on_close', 1);
    if (m.opponentScore >= 10) set('on_cb_10', 1);
    if (m.opponentScore >= 25) set('on_cb_25', 1);
    if (m.opponentScore >= 50) set('on_cb_50', 1);
    if (m.opponentScore >= 100) set('on_cb_100', 1);
    if (m.turnCount > 0 && m.turnCount <= 15) set('on_fast_15', 1);
    if (m.turnCount > 0 && m.turnCount <= 25) set('on_fast_25', 1);
    if (m.turnCount >= 75) set('on_long_75', 1);
    if (m.turnCount >= 120) set('on_long_120', 1);
  }

  for (final t in [2, 3, 5, 10]) {
    set('on_rm_$t', s.onlineMaxRematchWinStreak);
  }
  for (final t in [3, 10, 25, 50, 100]) {
    set('on_opp_$t', s.onlineUniqueOpponents);
  }
  for (final t in [3, 5, 10, 25]) {
    set('on_rival_$t', s.onlineMostVsSingleOpponent);
  }

  if (m.won && m.themeId == 'neutral') set('on_th_neutral', s.onlineWins);
  if (m.won && m.themeId == 'candy') set('on_th_candy', s.onlineWins);
  if (m.won && m.themeId == 'night') set('on_th_night', s.onlineWins);
  set('on_th_all3', s.onlineThemesPlayed.length);
  if (m.won) set('on_th_all3_w', s.onlineThemesPlayed.length);

  for (final t in [2, 7, 14, 30, 100]) {
    set('on_d_$t', s.onlineConsecutiveDays);
  }

  if (m.won && m.reason == 'resign') set('on_resign', 1);
  if (m.won && m.reason == 'timeout') set('on_timeout', 1);
  if (m.drew) set('on_draw', 1);
  if (m.won && m.scoreGap >= 50 && m.turnCount > 0 && m.turnCount <= 25) {
    set('on_dragon', 1);
  }
  if (s.onlineGames >= 1000 && s.onlineTotalPerfects >= 100) set('on_zen', 1);
  if (m.myElo != null && m.myElo! >= 2200 && s.onlineCurrentWinStreak >= 100) {
    set('on_top', 1);
  }

  return (progress: next, unlocked: unlocked);
}
