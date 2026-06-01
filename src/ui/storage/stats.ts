import { readJSON, writeJSON } from "./storage";

const KEY = "bd_stats";

export interface Stats {
  games: number;
  wins: number;
  losses: number;
  draws: number;
  bestScore: number;
  totalClears: number;
  maxMultiClear: number;
}

export const DEFAULT_STATS: Stats = {
  games: 0,
  wins: 0,
  losses: 0,
  draws: 0,
  bestScore: 0,
  totalClears: 0,
  maxMultiClear: 0,
};

export function loadStats(): Stats {
  return { ...DEFAULT_STATS, ...readJSON<Partial<Stats>>(KEY, {}) };
}

export function saveStats(s: Stats): void {
  writeJSON(KEY, s);
}

export interface MatchOutcome {
  // perspective игрока 0 (человек). Для hot-seat 1v1 учитываем общие итоги
  // (любой выигрыш считается победой одного из живых игроков).
  winner: 0 | 1 | -1;
  scores: [number, number];
  myScore: number; // лучший достигнутый счёт человеком в этой партии
  totalClearsThisMatch: number;
  maxMultiClearThisMatch: number;
}

export function applyMatchToStats(prev: Stats, m: MatchOutcome): Stats {
  return {
    games: prev.games + 1,
    wins: prev.wins + (m.winner === 0 ? 1 : 0),
    losses: prev.losses + (m.winner === 1 ? 1 : 0),
    draws: prev.draws + (m.winner === -1 ? 1 : 0),
    bestScore: Math.max(prev.bestScore, m.myScore),
    totalClears: prev.totalClears + m.totalClearsThisMatch,
    maxMultiClear: Math.max(prev.maxMultiClear, m.maxMultiClearThisMatch),
  };
}
