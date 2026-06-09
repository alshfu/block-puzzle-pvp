import { readJSON, writeJSON } from "./storage";

const KEY = "bd_profile";
const XP_PER_LEVEL = 100;

export interface Profile {
  id: string;       // стабильный UUID, идентификатор в онлайне
  nick: string;
  avatar: string;
  xp: number;
}

function genId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return "id-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
}

export const DEFAULT_PROFILE: Profile = {
  id: "",         // заменится в loadProfile если пусто
  nick: "Игрок",
  avatar: "🙂",
  xp: 0,
};

export function loadProfile(): Profile {
  const raw = readJSON<Partial<Profile>>(KEY, DEFAULT_PROFILE);
  const id = typeof raw.id === "string" && raw.id.length > 4 ? raw.id : genId();
  const out: Profile = {
    id,
    nick: typeof raw.nick === "string" && raw.nick.length > 0 ? raw.nick : DEFAULT_PROFILE.nick,
    avatar: typeof raw.avatar === "string" && raw.avatar.length > 0 ? raw.avatar : DEFAULT_PROFILE.avatar,
    xp: typeof raw.xp === "number" && raw.xp >= 0 ? raw.xp : 0,
  };
  if (!raw.id) saveProfile(out); // зафиксируем сгенерированный id сразу
  return out;
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
