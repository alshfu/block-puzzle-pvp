/**
 * Протокол обмена между клиентом и PartyKit-серверами.
 * Один и тот же файл импортируется из party/* и из src/ui/online/.
 */

import type { Board, BotLevel, Coord, PieceInstance, RuleConfig } from "../src/core";

// ─── Профиль игрока в онлайне ────────────────────────────────────────────
export interface OnlineProfile {
  id: string;     // UUID v4, генерится клиентом один раз
  nick: string;
  avatar: string;
}

// ─── Состояние игры, которое сервер шлёт клиенту ─────────────────────────
export interface OnlinePlayerView {
  id: string;
  nick: string;
  avatar: string;
  score: number;
  combo: number;
  hand: PieceInstance[];
}

/** Подмножество правил, которые клиент может запросить при подключении. */
export interface RequestedCfg {
  handSize?: number;          // 1..4
  rotationEnabled?: boolean;
  flipEnabled?: boolean;
}

export interface OnlineGameState {
  matchId: string;
  board: Board;
  players: [OnlinePlayerView, OnlinePlayerView];
  current: 0 | 1;        // чей ход (индекс в players)
  turnCount: number;
  status: "playing" | "over";
  result?: { winner: 0 | 1 | -1; scores: [number, number]; reason?: "deadlock" | "timeout" | "resign" };
  /** Последняя очистка (для flash на клиенте) — клетки, которые сервер только что очистил. */
  lastClearedCells?: Coord[];
  /** Оставшееся время хода (мс). Сервер тикает раз в N мс. */
  turnTimeRemainingMs: number;
  /** Базовое время на ход (мс). */
  turnTimeBaseMs: number;
  /** Полный cfg, по которому идёт партия (handSize, rotation/flip, blitz и пр.). */
  cfg: RuleConfig;
}

// ─── Lobby (matchmaking) ────────────────────────────────────────────────

export type LobbyClient2Server =
  | { type: "queue"; profile: OnlineProfile }
  | { type: "cancel" };

export type LobbyServer2Client =
  | { type: "queued"; position: number; waitedSec: number }
  // token — одноразовый секрет слота для аутентификации в комнате (SEC-2).
  | { type: "matched"; roomId: string; opponent: OnlineProfile; token: string }
  | { type: "bot_fallback" } // ждал слишком долго — играй с ботом локально
  | { type: "error"; reason: string };

// ─── Room (game) ────────────────────────────────────────────────────────

export type RoomClient2Server =
  // token — секрет слота из `matched` (SEC-2); проверяется сервером.
  | { type: "hello"; profile: OnlineProfile; cfg?: RequestedCfg; token?: string }
  | {
      type: "move";
      pieceId: string;
      cells: Coord[];
      r: number;
      c: number;
    }
  | { type: "resign" }
  | { type: "rematch_request" }
  | { type: "rematch_cancel" };

export type RoomServer2Client =
  | {
      type: "joined";
      you: 0 | 1;
      state: OnlineGameState;
    }
  | { type: "state"; state: OnlineGameState; lastMoveOwner?: 0 | 1; gained?: number; perfect?: boolean }
  | { type: "move_rejected"; reason: string }
  | { type: "opponent_left"; willTimeoutMs: number }
  | { type: "opponent_reconnected" }
  | { type: "rematch_status"; yours: boolean; theirs: boolean }
  | { type: "error"; reason: string };

// ─── Internal (типы между lobby и room, не для клиента) ─────────────────

export interface MatchSeed {
  matchSeed: number;                                  // PRNG seed
  participants: [OnlineProfile, OnlineProfile];       // order = индексы 0/1
  botLevel?: BotLevel;                                // зарезервировано
}

// ─── Leaderboard ────────────────────────────────────────────────────────

export interface LeaderboardEntry {
  id: string;
  nick: string;
  avatar: string;
  elo: number;
  wins: number;
  losses: number;
  draws: number;
  /** ms epoch последнего матча. */
  updatedAt: number;
}

/** Внутренний RPC от room → leaderboard. */
export interface LeaderboardMatchReport {
  participants: [OnlineProfile, OnlineProfile];
  /** 0 / 1 — индекс победителя в `participants`; -1 — ничья. */
  winner: 0 | 1 | -1;
}

export type LeaderboardClient2Server =
  | { type: "subscribe"; myId: string | null }
  | { type: "ping" };

export type LeaderboardServer2Client =
  | { type: "snapshot"; top: LeaderboardEntry[]; you?: LeaderboardEntry; yourRank?: number; totalPlayers: number };
