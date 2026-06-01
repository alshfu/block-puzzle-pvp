import { readJSON, writeJSON } from "./storage";

const KEY = "bd_wallet";

export interface Wallet {
  coins: number;
  totalEarned: number; // суммарно заработано за всю историю
}

export const DEFAULT_WALLET: Wallet = { coins: 0, totalEarned: 0 };

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
