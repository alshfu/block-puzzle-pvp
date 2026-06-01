/**
 * Игровая комната — экземпляр на один матч. Авторитативный gameplay,
 * та же логика что в ядре (src/core).
 */
import {
  applyClears,
  Bag,
  canPlace,
  cloneBoard,
  DEFAULT_CONFIG,
  emptyBoard,
  findClears,
  hasAnyMove,
  isPerfectClear,
  normalize,
  orientations,
  place,
  scoreForMove,
  type Board,
  type Coord,
  type PieceInstance,
  type RuleConfig,
} from "../src/core";
import type {
  LeaderboardMatchReport,
  MatchSeed,
  OnlineGameState,
  OnlinePlayerView,
  OnlineProfile,
  RoomClient2Server,
  RoomServer2Client,
} from "../party/protocol";
import type { Conn } from "./types";

const TURN_TIME_MS = 60_000;

interface ServerPlayer {
  profile: OnlineProfile;
  score: number;
  combo: number;
  hand: PieceInstance[];
  conn?: Conn;
}

interface MatchState {
  matchSeed: number;
  cfg: RuleConfig;
  board: Board;
  players: [ServerPlayer, ServerPlayer];
  bags: [Bag, Bag];
  current: 0 | 1;
  turnCount: number;
  status: "waiting" | "playing" | "over";
  result?: { winner: 0 | 1 | -1; scores: [number, number]; reason?: "deadlock" | "timeout" | "resign" };
  lastClearedCells: Coord[];
  turnDeadline: number;
  rematchWanted: [boolean, boolean];
  participants: [OnlineProfile, OnlineProfile];
}

export class Room {
  state: MatchState;
  private timer: NodeJS.Timeout | null = null;

  constructor(
    public readonly id: string,
    seed: MatchSeed,
    private onMatchOver: (report: LeaderboardMatchReport) => void,
    private onAllGone: () => void,
  ) {
    this.state = this.init(seed);
  }

  private init(seed: MatchSeed): MatchState {
    const cfg: RuleConfig = { ...DEFAULT_CONFIG, turnTimerEnabled: false };
    const bags: [Bag, Bag] = [new Bag(seed.matchSeed + 11), new Bag(seed.matchSeed + 99)];
    const makeP = (p: OnlineProfile, bag: Bag): ServerPlayer => ({
      profile: p,
      score: 0,
      combo: 0,
      hand: Array.from({ length: cfg.handSize }, () => bag.draw()),
    });
    return {
      matchSeed: seed.matchSeed,
      cfg,
      board: emptyBoard(),
      players: [makeP(seed.participants[0], bags[0]), makeP(seed.participants[1], bags[1])],
      bags,
      current: 0,
      turnCount: 0,
      status: "waiting",
      lastClearedCells: [],
      turnDeadline: Date.now() + TURN_TIME_MS,
      rematchWanted: [false, false],
      participants: [seed.participants[0], seed.participants[1]],
    };
  }

  handleConnection(conn: Conn): void {
    conn.on("message", (data) => {
      let msg: RoomClient2Server;
      try {
        msg = JSON.parse(String(data));
      } catch {
        return;
      }
      this.onMessage(conn, msg);
    });
    conn.on("close", () => {
      const slot = this.state.players.findIndex((p) => p.conn === conn);
      if (slot >= 0) this.state.players[slot].conn = undefined;
      this.notifyOpponentLeft(slot);
      // Если оба отвалились — сообщаем room manager'у убить инстанс.
      if (this.state.players.every((p) => !p.conn)) {
        this.stopTimer();
        this.onAllGone();
      }
    });
  }

  private onMessage(conn: Conn, msg: RoomClient2Server): void {
    if (msg.type === "hello") {
      this.handleHello(conn, msg.profile);
      return;
    }
    if (msg.type === "move") {
      this.handleMove(conn, msg.pieceId, msg.cells, msg.r, msg.c);
      return;
    }
    if (msg.type === "resign") {
      this.endMatch(conn, "resign");
      return;
    }
    if (msg.type === "rematch_request" || msg.type === "rematch_cancel") {
      this.handleRematch(conn, msg.type === "rematch_request");
      return;
    }
  }

  private handleHello(conn: Conn, profile: OnlineProfile): void {
    const idx = this.state.players.findIndex((p) => p.profile.id === profile.id);
    if (idx === -1) {
      this.send(conn, { type: "error", reason: "not a participant" });
      return;
    }
    this.state.players[idx].conn = conn;
    const bothIn = this.state.players.every((p) => p.conn);
    if (this.state.status === "waiting" && bothIn) {
      this.state.status = "playing";
      this.resetDeadline();
      this.startTimer();
    }
    this.send(conn, { type: "joined", you: idx as 0 | 1, state: this.publicState() });
    if (bothIn) this.broadcastState();
  }

  private handleMove(conn: Conn, pieceId: string, cells: Coord[], r: number, c: number): void {
    const s = this.state;
    if (s.status !== "playing") {
      this.send(conn, { type: "move_rejected", reason: "match not active" });
      return;
    }
    const idx = s.players.findIndex((p) => p.conn === conn);
    if (idx === -1) return;
    if (idx !== s.current) {
      this.send(conn, { type: "move_rejected", reason: "not your turn" });
      return;
    }
    const player = s.players[idx];
    const piece = player.hand.find((p) => p.id === pieceId);
    if (!piece) {
      this.send(conn, { type: "move_rejected", reason: "piece not in hand" });
      return;
    }
    if (!canPlace(s.board, cells, r, c)) {
      this.send(conn, { type: "move_rejected", reason: "cannot place" });
      return;
    }
    // Анти-чит: cells должны быть валидной ориентацией piece.type
    const wanted = JSON.stringify(normalize(cells));
    const valid = orientations(piece.type, s.cfg.rotationEnabled, s.cfg.flipEnabled);
    const ok = valid.some((o) => JSON.stringify(o) === wanted);
    if (!ok) {
      this.send(conn, { type: "move_rejected", reason: "invalid orientation" });
      return;
    }

    const newBoard = cloneBoard(s.board);
    place(newBoard, cells, r, c, idx);
    const clears = findClears(newBoard);
    let perfect = false;
    let gained = 0;
    if (clears.count > 0) {
      const probe = cloneBoard(newBoard);
      applyClears(probe, clears.cleared);
      perfect = isPerfectClear(probe);
      gained = scoreForMove(clears.count, player.combo, perfect, s.cfg);
      player.score += gained;
      player.combo += 1;
      applyClears(newBoard, clears.cleared);
    } else {
      player.combo = 0;
    }
    s.board = newBoard;
    s.lastClearedCells = clears.cleared;
    player.hand = player.hand.filter((p) => p.id !== pieceId);
    while (player.hand.length < s.cfg.handSize) player.hand.push(s.bags[idx].draw());

    const next: 0 | 1 = (1 - idx) as 0 | 1;
    s.current = next;
    s.turnCount += 1;

    if (!hasAnyMove(s.board, s.players[next].hand, s.cfg)) {
      const scores: [number, number] = [s.players[0].score, s.players[1].score];
      const winner: 0 | 1 | -1 = scores[0] > scores[1] ? 0 : scores[1] > scores[0] ? 1 : -1;
      s.status = "over";
      s.result = { winner, scores, reason: "deadlock" };
      this.stopTimer();
      this.reportToLeaderboard(winner);
    } else {
      this.resetDeadline();
    }

    this.broadcastState(idx as 0 | 1, gained, perfect);
  }

  private endMatch(conn: Conn, reason: "resign" | "timeout"): void {
    const s = this.state;
    if (s.status === "over") return;
    const idx = s.players.findIndex((p) => p.conn === conn);
    if (idx === -1) return;
    const winner: 0 | 1 = (1 - idx) as 0 | 1;
    s.status = "over";
    s.result = { winner, scores: [s.players[0].score, s.players[1].score], reason };
    this.stopTimer();
    this.reportToLeaderboard(winner);
    this.broadcastState();
  }

  private handleRematch(conn: Conn, wanted: boolean): void {
    if (this.state.status !== "over") return;
    const idx = this.state.players.findIndex((p) => p.conn === conn);
    if (idx === -1) return;
    this.state.rematchWanted[idx as 0 | 1] = wanted;
    // ack обоим
    this.state.players.forEach((p, i) => {
      if (!p.conn) return;
      this.send(p.conn, {
        type: "rematch_status",
        yours: this.state.rematchWanted[i as 0 | 1],
        theirs: this.state.rematchWanted[(1 - i) as 0 | 1],
      });
    });
    if (this.state.rematchWanted[0] && this.state.rematchWanted[1]) {
      const newSeed = (Math.random() * 0xffffffff) | 0;
      const conns: [Conn | undefined, Conn | undefined] = [
        this.state.players[0].conn,
        this.state.players[1].conn,
      ];
      this.state = this.init({
        matchSeed: newSeed,
        participants: [this.state.participants[0], this.state.participants[1]],
      });
      this.state.players[0].conn = conns[0];
      this.state.players[1].conn = conns[1];
      if (conns[0] && conns[1]) {
        this.state.status = "playing";
        this.resetDeadline();
        this.startTimer();
      }
      this.broadcastState();
    }
  }

  // ─── timer ─────────────────────────────────────────────────────────────
  private startTimer(): void {
    if (this.timer) return;
    this.timer = setInterval(() => this.tick(), 1000);
  }
  private stopTimer(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
  private resetDeadline(): void {
    this.state.turnDeadline = Date.now() + TURN_TIME_MS;
  }
  private tick(): void {
    const s = this.state;
    if (s.status !== "playing") {
      this.stopTimer();
      return;
    }
    const now = Date.now();
    if (now >= s.turnDeadline) {
      const winner: 0 | 1 = (1 - s.current) as 0 | 1;
      s.status = "over";
      s.result = { winner, scores: [s.players[0].score, s.players[1].score], reason: "timeout" };
      this.stopTimer();
      this.reportToLeaderboard(winner);
      this.broadcastState();
      return;
    }
    if (Math.floor((s.turnDeadline - now) / 1000) % 5 === 0) this.broadcastState();
  }

  // ─── helpers ───────────────────────────────────────────────────────────
  private reportToLeaderboard(winner: 0 | 1 | -1): void {
    const s = this.state;
    this.onMatchOver({
      participants: [s.participants[0], s.participants[1]],
      winner,
    });
  }

  private notifyOpponentLeft(slot: number): void {
    if (slot === -1) return;
    const other = this.state.players[(1 - slot) as 0 | 1];
    if (other?.conn) this.send(other.conn, { type: "opponent_left", willTimeoutMs: 30_000 });
  }

  private publicState(): OnlineGameState {
    const s = this.state;
    const view = (p: ServerPlayer): OnlinePlayerView => ({
      id: p.profile.id,
      nick: p.profile.nick,
      avatar: p.profile.avatar,
      score: p.score,
      combo: p.combo,
      hand: p.hand,
    });
    return {
      matchId: this.id,
      board: s.board,
      players: [view(s.players[0]), view(s.players[1])],
      current: s.current,
      turnCount: s.turnCount,
      status: s.status === "over" ? "over" : "playing",
      result: s.result,
      lastClearedCells: s.lastClearedCells.length > 0 ? s.lastClearedCells : undefined,
      turnTimeRemainingMs: Math.max(0, s.turnDeadline - Date.now()),
      turnTimeBaseMs: TURN_TIME_MS,
    };
  }

  private broadcastState(lastMoveOwner?: 0 | 1, gained?: number, perfect?: boolean): void {
    const text = JSON.stringify({
      type: "state",
      state: this.publicState(),
      lastMoveOwner,
      gained,
      perfect,
    } as RoomServer2Client);
    for (const p of this.state.players) {
      if (p.conn) safeSend(p.conn, text);
    }
  }

  private send(conn: Conn, msg: RoomServer2Client): void {
    safeSend(conn, JSON.stringify(msg));
  }
}

function safeSend(conn: Conn, text: string): void {
  try {
    if (conn.readyState === 1) conn.send(text);
  } catch {
    /* ignore */
  }
}
