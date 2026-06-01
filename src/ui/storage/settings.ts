import { DEFAULT_CONFIG, type BotLevel, type RuleConfig } from "../../core";
import type { BlitzPreset } from "../screens/SetupScreen";
import { readJSON, writeJSON } from "./storage";

const KEY = "bd_settings";

export interface AppSettings {
  sound: boolean;
  vibrate: boolean;
  defaultCfg: RuleConfig;
  defaultBotLevel: BotLevel;
  defaultBlitz: BlitzPreset;
}

export const DEFAULT_SETTINGS: AppSettings = {
  sound: true,
  vibrate: true,
  defaultCfg: DEFAULT_CONFIG,
  defaultBotLevel: "medium",
  defaultBlitz: "norm",
};

export function loadSettings(): AppSettings {
  const raw = readJSON<Partial<AppSettings>>(KEY, {});
  return {
    sound: raw.sound ?? DEFAULT_SETTINGS.sound,
    vibrate: raw.vibrate ?? DEFAULT_SETTINGS.vibrate,
    defaultCfg: { ...DEFAULT_CONFIG, ...(raw.defaultCfg ?? {}) },
    defaultBotLevel: raw.defaultBotLevel ?? DEFAULT_SETTINGS.defaultBotLevel,
    defaultBlitz: raw.defaultBlitz ?? DEFAULT_SETTINGS.defaultBlitz,
  };
}

export function saveSettings(s: AppSettings): void {
  writeJSON(KEY, s);
}
