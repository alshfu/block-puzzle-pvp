import { readJSON, writeJSON } from "./storage";

const KEY = "bd_profile";
const XP_PER_LEVEL = 100;

export interface Profile {
  nick: string;
  avatar: string; // эмодзи или короткая строка
  xp: number;
}

export const DEFAULT_PROFILE: Profile = {
  nick: "Игрок",
  avatar: "🙂",
  xp: 0,
};

export function loadProfile(): Profile {
  const raw = readJSON<Partial<Profile>>(KEY, DEFAULT_PROFILE);
  return {
    nick: typeof raw.nick === "string" && raw.nick.length > 0 ? raw.nick : DEFAULT_PROFILE.nick,
    avatar: typeof raw.avatar === "string" && raw.avatar.length > 0 ? raw.avatar : DEFAULT_PROFILE.avatar,
    xp: typeof raw.xp === "number" && raw.xp >= 0 ? raw.xp : 0,
  };
}

export function saveProfile(p: Profile): void {
  writeJSON(KEY, p);
}

export function levelFromXp(xp: number): number {
  return 1 + Math.floor(Math.max(0, xp) / XP_PER_LEVEL);
}

export function xpInLevel(xp: number): { current: number; needed: number } {
  const x = Math.max(0, xp);
  return { current: x % XP_PER_LEVEL, needed: XP_PER_LEVEL };
}
