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
  currentWinStreak: number;
  bestWinStreak: number;
  rematchStreak: number; // партий подряд через «Реванш»
}

export const DEFAULT_STATS: Stats = {
  games: 0,
  wins: 0,
  losses: 0,
  draws: 0,
  bestScore: 0,
  totalClears: 0,
  maxMultiClear: 0,
  currentWinStreak: 0,
  bestWinStreak: 0,
  rematchStreak: 0,
};

export function loadStats(): Stats {
  return { ...DEFAULT_STATS, ...readJSON<Partial<Stats>>(KEY, {}) };
}

export function saveStats(s: Stats): void {
  writeJSON(KEY, s);
}

export interface MatchOutcome {
  winner: 0 | 1 | -1;
  scores: [number, number];
  myScore: number;
  totalClearsThisMatch: number;
  maxMultiClearThisMatch: number;
  bestComboThisMatch: number;
  hadPerfectClear: boolean;
  // breakdown очков игрока 0
  baseScore: number;       // сумма N·(N+1)/2 по всем очисткам
  comboBonus: number;      // сколько добавили комбо-множители (round(base·mult)−base)
  perfectBonus: number;    // сумма +perfectClearBonus
}

export function applyMatchToStats(prev: Stats, m: MatchOutcome): Stats {
  const winStreak = m.winner === 0 ? prev.currentWinStreak + 1 : 0;
  return {
    games: prev.games + 1,
    wins: prev.wins + (m.winner === 0 ? 1 : 0),
    losses: prev.losses + (m.winner === 1 ? 1 : 0),
    draws: prev.draws + (m.winner === -1 ? 1 : 0),
    bestScore: Math.max(prev.bestScore, m.myScore),
    totalClears: prev.totalClears + m.totalClearsThisMatch,
    maxMultiClear: Math.max(prev.maxMultiClear, m.maxMultiClearThisMatch),
    currentWinStreak: winStreak,
    bestWinStreak: Math.max(prev.bestWinStreak, winStreak),
    rematchStreak: prev.rematchStreak, // обновляется в App при rematch/non-rematch
  };
}
