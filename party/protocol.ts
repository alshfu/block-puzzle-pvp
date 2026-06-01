/**
 * Протокол обмена между клиентом и PartyKit-серверами.
 * Один и тот же файл импортируется из party/* и из src/ui/online/.
 */

import type { Board, BotLevel, Coord, PieceInstance } from "../src/core";

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

export interface OnlineGameState {
  matchId: string;
  board: Board;
  players: [OnlinePlayerView, OnlinePlayerView];
  current: 0 | 1;        // чей ход (индекс в players)
  turnCount: number;
  status: "playing" | "over";
  result?: { winner: 0 | 1 | -1; scores: [number, number] };
  /** Последняя очистка (для flash на клиенте) — клетки, которые сервер только что очистил. */
  lastClearedCells?: Coord[];
  /** Кто сейчас "я" — определяется индивидуально для каждого клиента. */
}

// ─── Lobby (matchmaking) ────────────────────────────────────────────────

export type LobbyClient2Server =
  | { type: "queue"; profile: OnlineProfile }
  | { type: "cancel" };

export type LobbyServer2Client =
  | { type: "queued"; position: number }
  | { type: "matched"; roomId: string; opponent: OnlineProfile }
  | { type: "error"; reason: string };

// ─── Room (game) ────────────────────────────────────────────────────────

export type RoomClient2Server =
  | { type: "hello"; profile: OnlineProfile }
  | {
      type: "move";
      pieceId: string;
      cells: Coord[];
      r: number;
      c: number;
    }
  | { type: "resign" };

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
  | { type: "error"; reason: string };

// ─── Internal (типы между lobby и room, не для клиента) ─────────────────

export interface MatchSeed {
  matchSeed: number;                                  // PRNG seed
  participants: [OnlineProfile, OnlineProfile];       // order = индексы 0/1
  botLevel?: BotLevel;                                // зарезервировано
}
