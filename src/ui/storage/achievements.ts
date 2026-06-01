import { readJSON, writeJSON } from "./storage";

const KEY = "bd_achievements";

export interface AchievementProgress {
  current: number;
  unlockedAt?: number;
}

export type PlayerAchievements = Record<string, AchievementProgress>;

export function loadAchievements(): PlayerAchievements {
  return readJSON<PlayerAchievements>(KEY, {});
}

export function saveAchievements(p: PlayerAchievements): void {
  writeJSON(KEY, p);
}
