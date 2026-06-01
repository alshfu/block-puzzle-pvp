import type * as Party from "partykit/server";
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
  place,
  scoreForMove,
  type Board,
  type Coord,
  type PieceInstance,
  type RuleConfig,
} from "../src/core";
import type {
  MatchSeed,
  OnlineGameState,
  OnlinePlayerView,
  OnlineProfile,
  RoomClient2Server,
  RoomServer2Client,
} from "./protocol";

interface ServerPlayer {
  profile: OnlineProfile;
  score: number;
  combo: number;
  hand: PieceInstance[];
  isBot: false;
  connId?: string;       // текущий active connection
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
  result?: { winner: 0 | 1 | -1; scores: [number, number] };
  lastClearedCells: Coord[];
}

/**
 * One Room party = one match.
 * Создаётся POST-запросом из lobby с MatchSeed, затем принимает два WS-connect'а.
 */
export default class RoomServer implements Party.Server {
  state: MatchState | null = null;

  constructor(readonly room: Party.Room) {}

  /** Lobby делает POST с MatchSeed — инициализируем матч. */
  async onRequest(req: Party.Request): Promise<Response> {
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
    if (this.state) return new Response("already initialised", { status: 409 });
    let seed: MatchSeed;
    try {
      seed = (await req.json()) as MatchSeed;
    } catch {
      return new Response("bad json", { status: 400 });
    }
    this.state = this.initMatch(seed);
    return new Response("ok");
  }

  onClose(conn: Party.Connection) {
    if (!this.state) return;
    for (const p of this.state.players) {
      if (p.connId === conn.id) p.connId = undefined;
    }
    // Уведомим оставшегося, что соперник отвалился.
    const remaining = this.state.players.find((p) => p.connId);
    if (remaining && remaining.connId) {
      const conn2 = this.room.getConnection(remaining.connId);
      if (conn2)
        this.send(conn2, {
          type: "opponent_left",
          willTimeoutMs: 30000,
        });
    }
  }

  async onMessage(message: string, sender: Party.Connection): Promise<void> {
    if (!this.state) {
      this.send(sender, { type: "error", reason: "room not initialised" });
      return;
    }
    let msg: RoomClient2Server;
    try {
      msg = JSON.parse(message);
    } catch {
      this.send(sender, { type: "error", reason: "bad json" });
      return;
    }

    if (msg.type === "hello") {
      // Найдём слот игрока по profile.id.
      const idx = this.state.players.findIndex((p) => p.profile.id === msg.profile.id) as 0 | 1 | -1;
      if (idx === -1) {
        this.send(sender, { type: "error", reason: "not a participant" });
        return;
      }
      // Если уже был коннект от того же игрока, заменяем.
      this.state.players[idx].connId = sender.id;

      // Если оба игрока подключены и статус waiting — стартуем.
      const bothIn = this.state.players.every((p) => p.connId);
      if (this.state.status === "waiting" && bothIn) {
        this.state.status = "playing";
      }
      this.send(sender, {
        type: "joined",
        you: idx,
        state: this.publicState(),
      });
      // Если матч уже идёт — уведомим оппонента о реконнекте
      const other = this.state.players[1 - idx];
      if (other.connId) {
        const ocn = this.room.getConnection(other.connId);
        if (ocn) this.send(ocn, { type: "opponent_reconnected" });
      }
      // На старте отправим обоим актуальный state
      if (bothIn) this.broadcastState();
      return;
    }

    if (msg.type === "resign") {
      this.endMatch(sender, "resign");
      return;
    }

    if (msg.type === "move") {
      this.handleMove(sender, msg.pieceId, msg.cells, msg.r, msg.c);
      return;
    }
  }

  // ─── game logic ────────────────────────────────────────────────────────

  private initMatch(seed: MatchSeed): MatchState {
    const cfg: RuleConfig = { ...DEFAULT_CONFIG, turnTimerEnabled: false };
    const bags: [Bag, Bag] = [new Bag(seed.matchSeed + 11), new Bag(seed.matchSeed + 99)];
    const makePlayer = (profile: OnlineProfile, bag: Bag): ServerPlayer => ({
      profile,
      score: 0,
      combo: 0,
      isBot: false,
      hand: Array.from({ length: cfg.handSize }, () => bag.draw()),
    });
    return {
      matchSeed: seed.matchSeed,
      cfg,
      board: emptyBoard(),
      players: [makePlayer(seed.participants[0], bags[0]), makePlayer(seed.participants[1], bags[1])],
      bags,
      current: 0,
      turnCount: 0,
      status: "waiting",
      lastClearedCells: [],
    };
  }

  private handleMove(sender: Party.Connection, pieceId: string, cells: Coord[], r: number, c: number): void {
    const s = this.state!;
    if (s.status !== "playing") {
      this.send(sender, { type: "move_rejected", reason: "match not active" });
      return;
    }
    const idx = s.players.findIndex((p) => p.connId === sender.id) as 0 | 1 | -1;
    if (idx === -1) {
      this.send(sender, { type: "move_rejected", reason: "not a participant" });
      return;
    }
    if (idx !== s.current) {
      this.send(sender, { type: "move_rejected", reason: "not your turn" });
      return;
    }
    const player = s.players[idx];
    const piece = player.hand.find((p) => p.id === pieceId);
    if (!piece) {
      this.send(sender, { type: "move_rejected", reason: "piece not in hand" });
      return;
    }
    if (!canPlace(s.board, cells, r, c)) {
      this.send(sender, { type: "move_rejected", reason: "cannot place" });
      return;
    }
    // Проверим, что cells соответствуют какой-либо ориентации фигуры — оставим простой
    // sanity: число клеток совпадает с количеством клеток в pieceType.
    if (cells.length !== piece.cells.length) {
      this.send(sender, { type: "move_rejected", reason: "cells mismatch" });
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
    // снимаем фигуру, пополняем руку
    player.hand = player.hand.filter((p) => p.id !== pieceId);
    while (player.hand.length < s.cfg.handSize) player.hand.push(s.bags[idx].draw());

    // Передаём ход. Проверяем тупик для соперника.
    const next: 0 | 1 = (1 - idx) as 0 | 1;
    s.turnCount += 1;
    s.current = next;

    if (!hasAnyMove(s.board, s.players[next].hand, s.cfg)) {
      const scores: [number, number] = [s.players[0].score, s.players[1].score];
      const winner: 0 | 1 | -1 = scores[0] > scores[1] ? 0 : scores[1] > scores[0] ? 1 : -1;
      s.status = "over";
      s.result = { winner, scores };
    }

    this.broadcastState(idx, gained, perfect);
  }

  private endMatch(sender: Party.Connection, _reason: string): void {
    const s = this.state!;
    if (s.status === "over") return;
    const idx = s.players.findIndex((p) => p.connId === sender.id);
    if (idx === -1) return;
    const winner: 0 | 1 = (1 - idx) as 0 | 1;
    s.status = "over";
    s.result = {
      winner,
      scores: [s.players[0].score, s.players[1].score],
    };
    this.broadcastState();
  }

  // ─── serialization / broadcast ─────────────────────────────────────────

  private publicState(): OnlineGameState {
    const s = this.state!;
    const view = (p: ServerPlayer): OnlinePlayerView => ({
      id: p.profile.id,
      nick: p.profile.nick,
      avatar: p.profile.avatar,
      score: p.score,
      combo: p.combo,
      hand: p.hand,
    });
    return {
      matchId: this.room.id,
      board: s.board,
      players: [view(s.players[0]), view(s.players[1])],
      current: s.current,
      turnCount: s.turnCount,
      status: s.status === "over" ? "over" : "playing",
      result: s.result,
      lastClearedCells: s.lastClearedCells.length > 0 ? s.lastClearedCells : undefined,
    };
  }

  private broadcastState(lastMoveOwner?: 0 | 1, gained?: number, perfect?: boolean): void {
    const s = this.state!;
    const stateMsg: RoomServer2Client = {
      type: "state",
      state: this.publicState(),
      lastMoveOwner,
      gained,
      perfect,
    };
    const text = JSON.stringify(stateMsg);
    for (const p of s.players) {
      if (!p.connId) continue;
      const conn = this.room.getConnection(p.connId);
      if (conn) conn.send(text);
    }
  }

  private send(conn: Party.Connection, msg: RoomServer2Client): void {
    conn.send(JSON.stringify(msg));
  }
}
