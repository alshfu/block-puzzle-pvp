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
