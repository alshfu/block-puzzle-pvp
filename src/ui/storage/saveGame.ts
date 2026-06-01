import type { Board, BotLevel, PieceInstance, RuleConfig } from "../../core";
import type { GameMode } from "../screens/MenuScreen";
import type { BlitzPreset } from "../screens/SetupScreen";
import { readJSON, removeKey, writeJSON } from "./storage";

const KEY = "bd_save";
const VERSION = 2;

export interface SavedPlayer {
  score: number;
  combo: number;
  hand: PieceInstance[];
  isBot: boolean;
}

export interface SavedGame {
  version: number;
  seed: number;
  cfg: RuleConfig;
  mode: GameMode;
  botLevel: BotLevel;                              // legacy/UI badge; для логики используем botLevels
  botLevels: [BotLevel | null, BotLevel | null];   // null = живой игрок
  blitz: BlitzPreset;
  board: Board;
  players: [SavedPlayer, SavedPlayer];
  drawCounts: [number, number]; // сколько раз был дёрнут каждый мешок
  current: 0 | 1;
  turnCount: number;
  perTurn: number;
  remaining: number;
  totalClears: number;
  maxMultiClear: number;
  savedAt: number;
}

export function loadSavedGame(): SavedGame | null {
  const raw = readJSON<SavedGame | null>(KEY, null);
  if (!raw || raw.version !== VERSION) return null;
  return raw;
}

export function saveGame(s: SavedGame): void {
  writeJSON(KEY, { ...s, version: VERSION });
}

export const SAVE_VERSION = VERSION;

export function clearSavedGame(): void {
  removeKey(KEY);
}
