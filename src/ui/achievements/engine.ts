import type { BotLevel } from "../../core";
import type { GameMode } from "../screens/MenuScreen";
import type { PlayerAchievements } from "../storage/achievements";
import type { Stats } from "../storage/stats";
import { ACHIEVEMENTS, ACHIEVEMENTS_BY_ID, type AchievementDef } from "./definitions";

export interface AchievementContext {
  winner: 0 | 1 | -1;
  myScore: number;
  totalClearsThisMatch: number;
  maxMultiClearThisMatch: number;
  bestComboThisMatch: number;
  hadPerfectClear: boolean;
  mode: GameMode;
  botLevel: BotLevel | null;
  statsAfter: Stats;
  winStreak: number;
  rematchStreak: number;
}

/**
 * Применяет прогресс ачивок по событиям одной партии.
 * Возвращает обновлённое состояние и список **впервые** разблокированных ачивок
 * (для UI-тостов).
 */
export function processMatchAchievements(
  prev: PlayerAchievements,
  ctx: AchievementContext,
): { next: PlayerAchievements; unlocked: AchievementDef[] } {
  const next: PlayerAchievements = { ...prev };
  const unlocked: AchievementDef[] = [];

  function set(id: string, current: number): void {
    const def = ACHIEVEMENTS_BY_ID[id];
    if (!def) return;
    const before = next[id];
    if (before?.unlockedAt) {
      // уже разблокирована — current не уменьшаем
      next[id] = before;
      return;
    }
    const cur = Math.max(before?.current ?? 0, current);
    if (cur >= def.total) {
      next[id] = { current: def.total, unlockedAt: Date.now() };
      unlocked.push(def);
    } else {
      next[id] = { current: cur };
    }
  }

  const wonVsAi = ctx.winner === 0 && ctx.mode === "bot";

  // single-event
  set("first_blood", ctx.winner === 0 ? 1 : 0);
  set("flawless", ctx.hadPerfectClear ? 1 : 0);
  set("combinator", ctx.maxMultiClearThisMatch >= 4 ? 1 : 0);
  set("ai_tamer", wonVsAi && ctx.botLevel === "hard" ? 1 : 0);
  set("strategist", ctx.bestComboThisMatch);

  // progressive
  set("cleaner_100", ctx.statsAfter.totalClears);
  set("cleaner_1k", ctx.statsAfter.totalClears);
  set("cleaner_10k", ctx.statsAfter.totalClears);
  set("veteran_10", ctx.statsAfter.games);
  set("veteran_100", ctx.statsAfter.games);

  // series
  set("streak_3", ctx.winStreak);
  set("streak_5", ctx.winStreak);
  set("streak_10", ctx.winStreak);

  // hidden
  set("king_five", ctx.maxMultiClearThisMatch >= 5 ? 1 : 0);
  set("persistence", ctx.rematchStreak);

  return { next, unlocked };
}

/** XP-бонус за стрик побед, начисляется отдельным куском поверх match XP. */
export function streakXpBonus(streak: number): number {
  if (streak >= 10) return 200;
  if (streak >= 5) return 75;
  if (streak >= 3) return 25;
  return 0;
}

export { ACHIEVEMENTS };

// ═════════════════════════════════════════════════════════════════════
//   ONLINE ACHIEVEMENT ENGINE
// ═════════════════════════════════════════════════════════════════════

export interface OnlineAchievementContext {
  /** Снимок stats **после** apply онлайн-матча — используем для прогрессий. */
  stats: import("../storage/stats").Stats;
  /** Контекст конкретного матча для one-shot ачивок. */
  match: import("../storage/stats").OnlineMatchInfo;
}

/**
 * Применяет онлайн-ачивки. Возвращает обновлённое состояние + новые анлоки.
 */
export function processOnlineAchievements(
  prev: PlayerAchievements,
  ctx: OnlineAchievementContext,
): { next: PlayerAchievements; unlocked: AchievementDef[] } {
  const next: PlayerAchievements = { ...prev };
  const unlocked: AchievementDef[] = [];

  function set(id: string, current: number): void {
    const def = ACHIEVEMENTS_BY_ID[id];
    if (!def) return;
    const before = next[id];
    if (before?.unlockedAt) {
      next[id] = before;
      return;
    }
    const cur = Math.max(before?.current ?? 0, current);
    if (cur >= def.total) {
      next[id] = { current: def.total, unlockedAt: Date.now() };
      unlocked.push(def);
    } else {
      next[id] = { current: cur };
    }
  }

  const s = ctx.stats;
  const m = ctx.match;

  // ── Прогрессии побед ─────────────────────────────────────────────────
  for (const t of [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500]) {
    set(`on_w_${t}`, s.onlineWins);
  }

  // ── Матчи всего ──────────────────────────────────────────────────────
  for (const t of [10, 50, 100, 250, 500, 1000, 5000, 10000]) {
    const key = t === 10000 ? "on_g_10k" : `on_g_${t}`;
    set(key, s.onlineGames);
  }

  // ── Стрики побед ─────────────────────────────────────────────────────
  for (const t of [3, 5, 7, 10, 15, 20, 25, 50]) {
    set(`on_s_${t}`, s.onlineCurrentWinStreak);
  }
  // Без поражения
  for (const t of [5, 10, 25, 50]) {
    set(`on_nl_${t}`, s.onlineCurrentNoLossStreak);
  }

  // ── ELO milestones ───────────────────────────────────────────────────
  if (typeof m.myElo === "number") {
    for (const t of [1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000]) {
      set(`on_e_${t}`, m.myElo);
    }
  }

  // ── Очистки и perfects ───────────────────────────────────────────────
  for (const t of [100, 500, 1000, 5000, 10000]) {
    const key = t === 1000 ? "on_c_1k" : t === 5000 ? "on_c_5k" : t === 10000 ? "on_c_10k" : `on_c_${t}`;
    set(key, s.onlineTotalClears);
  }
  for (const t of [1, 5, 10, 25, 50]) set(`on_p_${t}`, s.onlineTotalPerfects);

  // ── Multi-clear / комбо за матч ──────────────────────────────────────
  if (m.maxMultiClearThisMatch >= 3) set("on_mc_3", 1);
  if (m.maxMultiClearThisMatch >= 4) set("on_mc_4", 1);
  if (m.maxMultiClearThisMatch >= 5) set("on_mc_5", 1);
  if (m.maxMultiClearThisMatch >= 6) set("on_mc_6", 1);
  set("on_co_3", m.bestComboThisMatch);
  set("on_co_5", m.bestComboThisMatch);
  set("on_co_8", m.bestComboThisMatch);
  set("on_co_10", m.bestComboThisMatch);

  // ── Разрывы и камбэки ────────────────────────────────────────────────
  if (m.won) {
    if (m.scoreGap >= 10) set("on_gap_10", 1);
    if (m.scoreGap >= 25) set("on_gap_25", 1);
    if (m.scoreGap >= 50) set("on_gap_50", 1);
    if (m.scoreGap >= 100) set("on_gap_100", 1);
    if (m.scoreGap >= 200) set("on_gap_200", 1);
    if (m.scoreGap === 1) set("on_close", 1);
    // приближённый камбэк: opponentScore при победе показывает что соперник набрал, прежде чем мы выиграли
    if (m.opponentScore >= 10) set("on_cb_10", 1);
    if (m.opponentScore >= 25) set("on_cb_25", 1);
    if (m.opponentScore >= 50) set("on_cb_50", 1);
    if (m.opponentScore >= 100) set("on_cb_100", 1);
  }

  // ── Темп ─────────────────────────────────────────────────────────────
  if (m.won) {
    if (m.turnCount > 0 && m.turnCount <= 15) set("on_fast_15", 1);
    if (m.turnCount > 0 && m.turnCount <= 25) set("on_fast_25", 1);
    if (m.turnCount >= 75) set("on_long_75", 1);
    if (m.turnCount >= 120) set("on_long_120", 1);
  }

  // ── Реванши против того же соперника ────────────────────────────────
  for (const t of [2, 3, 5, 10]) set(`on_rm_${t}`, s.onlineMaxRematchWinStreak);

  // ── Соперники ────────────────────────────────────────────────────────
  for (const t of [3, 10, 25, 50, 100]) set(`on_opp_${t}`, s.onlineUniqueOpponents);
  for (const t of [3, 5, 10, 25]) set(`on_rival_${t}`, s.onlineMostVsSingleOpponent);

  // Серия побед против одного и того же соперника
  const opp = s.onlineOpponents[m.opponentId];
  if (opp && m.won) {
    // приближённо: используем opp.wins при условии что последняя серия была всех wins.
    // У нас нет точного "streak vs opponent" — используем opp.wins-opp.losses когда last="win".
    if (opp.lastResult === "win") {
      const dominanceStreak = Math.max(0, opp.wins - opp.losses);
      set("on_dom_3", dominanceStreak);
      set("on_dom_5", dominanceStreak);
      set("on_dom_10", dominanceStreak);
    }
  }
  // Реванш-сладкий: предыдущий результат был "loss" → теперь "win"
  if (opp && m.won && opp.losses > 0 && opp.lastResult === "win") {
    // эвристика: если соперник нам когда-то проигрывал, не доказательство
    // того что сейчас именно после поражения. Упростим: засчитываем если против него уже было поражение.
    set("on_revenge", 1);
  }

  // ── Темы ─────────────────────────────────────────────────────────────
  if (m.won && m.themeId === "neutral") set("on_th_neutral", s.onlineWins); // приближённо
  if (m.won && m.themeId === "candy") set("on_th_candy", s.onlineWins);
  if (m.won && m.themeId === "night") set("on_th_night", s.onlineWins);
  set("on_th_all3", s.onlineThemesPlayed.length);
  if (m.won) set("on_th_all3_w", s.onlineThemesPlayed.length); // если играл во всех 3 темах + есть победа

  // ── Дни подряд ───────────────────────────────────────────────────────
  for (const t of [2, 7, 14, 30, 100]) set(`on_d_${t}`, s.onlineConsecutiveDays);

  // ── Hidden ───────────────────────────────────────────────────────────
  if (m.won && m.reason === "resign") set("on_resign", 1);
  if (m.won && m.reason === "timeout") set("on_timeout", 1);
  if (m.drew) set("on_draw", 1);
  if (m.won && m.scoreGap >= 50 && m.turnCount > 0 && m.turnCount <= 25) set("on_dragon", 1);

  // ── Большие финальные ────────────────────────────────────────────────
  if (s.onlineGames >= 1000 && s.onlineTotalPerfects >= 100) set("on_zen", 1);
  if (typeof m.myElo === "number" && m.myElo >= 2200 && s.onlineCurrentWinStreak >= 100) set("on_top", 1);

  return { next, unlocked };
}
