import { readJSON, writeJSON } from "./storage";

const KEY = "bd_wallet";

export interface Wallet {
  coins: number;
  totalEarned: number; // суммарно coins за всю историю
  /** Кристаллы силы — премиум-валюта для power-ups. 1 кристалл = 150 lifetime score. */
  crystals: number;
  /** Накопленный score для расчёта кристаллов; обнуляется как остаток от 150. */
  scoreForCrystals: number;
  totalCrystalsEarned: number;
}

export const DEFAULT_WALLET: Wallet = {
  coins: 0,
  totalEarned: 0,
  crystals: 0,
  scoreForCrystals: 0,
  totalCrystalsEarned: 0,
};

/** Прибавляет score в накопитель и возвращает {newCrystals, leftover}. */
export function addScoreForCrystals(prev: Wallet, score: number): { wallet: Wallet; granted: number } {
  if (score <= 0) return { wallet: prev, granted: 0 };
  const pool = prev.scoreForCrystals + score;
  const granted = Math.floor(pool / 150);
  return {
    wallet: {
      ...prev,
      crystals: prev.crystals + granted,
      scoreForCrystals: pool % 150,
      totalCrystalsEarned: prev.totalCrystalsEarned + granted,
    },
    granted,
  };
}

export function loadWallet(): Wallet {
  return { ...DEFAULT_WALLET, ...readJSON<Partial<Wallet>>(KEY, {}) };
}

export function saveWallet(w: Wallet): void {
  writeJSON(KEY, w);
}

/** Награда за партию: 1 монета за 8 очков игрока + бонусы. Минимум 1. */
export function coinsForMatch(myScore: number, won: boolean): number {
  const base = Math.max(1, Math.floor(myScore / 8));
  const winBonus = won ? 10 : 0;
  return base + winBonus;
}
