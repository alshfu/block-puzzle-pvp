import { DEFAULT_CONFIG, type BotLevel, type RuleConfig } from "../../core";
import type { BlitzPreset } from "../screens/SetupScreen";
import { readJSON, writeJSON } from "./storage";

const KEY = "bd_settings";

export type VibrateIntensity = "off" | "light" | "strong";
export type ClearSpeed = "fast" | "normal" | "slow";

export interface AppSettings {
  sound: boolean;
  soundVolume: number;          // 0..1
  music: boolean;
  musicVolume: number;          // 0..1
  vibrate: boolean;
  vibrateIntensity: VibrateIntensity;
  // Анимации
  flashEnabled: boolean;        // вспышка при очистке
  confettiEnabled: boolean;     // конфетти на perfect
  mascotEnabled: boolean;       // парящие пони / фоновая мультяшная декорация
  reducedMotion: boolean;       // глобально отключить дёргающие движения
  // Геймплей
  botDelayMs: number;           // 0..1500 — задержка хода бота
  clearSpeed: ClearSpeed;       // скорость анимации очистки
  showGhost: boolean;           // подсветка целевых клеток при выборе фигуры
  // Существующие дефолты матча
  defaultCfg: RuleConfig;
  defaultBotLevel: BotLevel;
  defaultBlitz: BlitzPreset;
}

export const DEFAULT_SETTINGS: AppSettings = {
  sound: true,
  soundVolume: 0.7,
  music: true,
  musicVolume: 0.5,
  vibrate: true,
  vibrateIntensity: "strong",
  flashEnabled: true,
  confettiEnabled: true,
  mascotEnabled: true,
  reducedMotion: false,
  botDelayMs: 800,
  clearSpeed: "normal",
  showGhost: true,
  defaultCfg: DEFAULT_CONFIG,
  defaultBotLevel: "medium",
  defaultBlitz: "norm",
};

const CLEAR_SPEED_MS: Record<ClearSpeed, number> = {
  fast: 180,
  normal: 430,
  slow: 700,
};
export function clearSpeedMs(s: ClearSpeed): number {
  return CLEAR_SPEED_MS[s];
}

function clamp01(n: unknown, def: number): number {
  return typeof n === "number" && n >= 0 && n <= 1 ? n : def;
}

export function loadSettings(): AppSettings {
  const raw = readJSON<Partial<AppSettings>>(KEY, {});
  return {
    sound: raw.sound ?? DEFAULT_SETTINGS.sound,
    soundVolume: clamp01(raw.soundVolume, DEFAULT_SETTINGS.soundVolume),
    music: raw.music ?? DEFAULT_SETTINGS.music,
    musicVolume: clamp01(raw.musicVolume, DEFAULT_SETTINGS.musicVolume),
    vibrate: raw.vibrate ?? DEFAULT_SETTINGS.vibrate,
    vibrateIntensity: raw.vibrateIntensity ?? DEFAULT_SETTINGS.vibrateIntensity,
    flashEnabled: raw.flashEnabled ?? DEFAULT_SETTINGS.flashEnabled,
    confettiEnabled: raw.confettiEnabled ?? DEFAULT_SETTINGS.confettiEnabled,
    mascotEnabled: raw.mascotEnabled ?? DEFAULT_SETTINGS.mascotEnabled,
    reducedMotion: raw.reducedMotion ?? DEFAULT_SETTINGS.reducedMotion,
    botDelayMs: typeof raw.botDelayMs === "number" ? raw.botDelayMs : DEFAULT_SETTINGS.botDelayMs,
    clearSpeed: raw.clearSpeed ?? DEFAULT_SETTINGS.clearSpeed,
    showGhost: raw.showGhost ?? DEFAULT_SETTINGS.showGhost,
    defaultCfg: { ...DEFAULT_CONFIG, ...(raw.defaultCfg ?? {}) },
    defaultBotLevel: raw.defaultBotLevel ?? DEFAULT_SETTINGS.defaultBotLevel,
    defaultBlitz: raw.defaultBlitz ?? DEFAULT_SETTINGS.defaultBlitz,
  };
}

export function saveSettings(s: AppSettings): void {
  writeJSON(KEY, s);
}
