import type { SkinId } from "../shop/skins";
import { readJSON, writeJSON } from "./storage";

const KEY = "bd_skins";

export interface PlayerSkins {
  unlocked: SkinId[];
  equipped: SkinId;
}

export const DEFAULT_SKINS: PlayerSkins = {
  unlocked: ["default"],
  equipped: "default",
};

const VALID_IDS: SkinId[] = ["default", "gem", "bullet", "neon", "pixel", "candy"];
function isSkinId(v: unknown): v is SkinId {
  return typeof v === "string" && (VALID_IDS as string[]).includes(v);
}

export function loadPlayerSkins(): PlayerSkins {
  const raw = readJSON<Partial<PlayerSkins>>(KEY, {});
  const unlocked: SkinId[] = Array.isArray(raw.unlocked)
    ? raw.unlocked.filter(isSkinId)
    : ["default"];
  // default всегда разблокирован
  if (!unlocked.includes("default")) unlocked.unshift("default");
  const equipped: SkinId = raw.equipped && isSkinId(raw.equipped) && unlocked.includes(raw.equipped)
    ? raw.equipped
    : "default";
  return { unlocked, equipped };
}

export function savePlayerSkins(s: PlayerSkins): void {
  writeJSON(KEY, s);
}
