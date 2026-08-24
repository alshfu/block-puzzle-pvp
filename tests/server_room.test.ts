/**
 * server_room.test.ts — тесты стейт-машины PvP-сервера (Room/Lobby).
 *
 * Раньше server/*.ts не имели ни одного теста (ядро покрыто, стейт-машина — нет).
 * Здесь — регрессы на баги из аудита 2026-08-23:
 *   H-A: сообщение `null` / `hello` без profile роняли ВЕСЬ Node-процесс;
 *   M-A: `resign` в статусе `waiting` завершал матч и менял ELO до входа оппонента.
 * Соединения мокаются лёгким FakeConn (WebSocket-совместимый по нужным методам).
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { Lobby } from "../server/lobby";
import { Room } from "../server/room";

class FakeConn {
  handlers: Record<string, (data: unknown) => void> = {};
  sent: unknown[] = [];
  readyState = 1;
  on(event: string, cb: (data: unknown) => void): this {
    this.handlers[event] = cb;
    return this;
  }
  send(data: string): void {
    this.sent.push(JSON.parse(data));
  }
  close(): void {
    this.readyState = 3;
  }
  emit(event: string, data: unknown): void {
    this.handlers[event]?.(data);
  }
}

const p0 = { id: "u0", nick: "Алиса", avatar: "🦊" };
const p1 = { id: "u1", nick: "Боб", avatar: "🐼" };

function makeRoom(): Room {
  return new Room(
    "t",
    { matchSeed: 42, participants: [p0, p1] },
    ["ta", "tb"],
    () => [1000, 1000],
    () => {},
  );
}

describe("Room — устойчивость к malformed сообщениям (H-A)", () => {
  it("сообщение `null` не роняет обработчик", () => {
    const room = makeRoom();
    const conn = new FakeConn();
    room.handleConnection(conn as never);
    expect(() => conn.emit("message", "null")).not.toThrow();
  });

  it("сообщение-примитив не роняет обработчик", () => {
    const room = makeRoom();
    const conn = new FakeConn();
    room.handleConnection(conn as never);
    expect(() => conn.emit("message", "42")).not.toThrow();
  });

  it("hello без profile не роняет, шлёт error", () => {
    const room = makeRoom();
    const conn = new FakeConn();
    room.handleConnection(conn as never);
    expect(() => conn.emit("message", JSON.stringify({ type: "hello" }))).not.toThrow();
    expect(conn.sent).toContainEqual({ type: "error", reason: "invalid profile" });
  });
});

describe("Room — resign в waiting не завершает матч (M-A)", () => {
  it("resign до входа оппонента оставляет статус waiting", () => {
    const room = makeRoom();
    const conn = new FakeConn();
    room.handleConnection(conn as never);
    conn.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    expect(room.state.status).toBe("waiting");
    conn.emit("message", JSON.stringify({ type: "resign" }));
    expect(room.state.status).toBe("waiting"); // НЕ over
    expect(room.state.result).toBeUndefined();
  });

  it("resign во время playing по-прежнему завершает матч", () => {
    const room = makeRoom();
    const c0 = new FakeConn();
    const c1 = new FakeConn();
    room.handleConnection(c0 as never);
    room.handleConnection(c1 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    c1.emit("message", JSON.stringify({ type: "hello", profile: p1, token: "tb" }));
    expect(room.state.status).toBe("playing");
    c0.emit("message", JSON.stringify({ type: "resign" }));
    expect(room.state.status).toBe("over");
    expect(room.state.result?.winner).toBe(1); // победа оппоненту сдавшегося
  });

  it("opponent_left НЕ шлётся после конца матча (L-B)", () => {
    const room = makeRoom();
    const c0 = new FakeConn();
    const c1 = new FakeConn();
    room.handleConnection(c0 as never);
    room.handleConnection(c1 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    c1.emit("message", JSON.stringify({ type: "hello", profile: p1, token: "tb" }));
    c0.emit("message", JSON.stringify({ type: "resign" })); // матч over
    c1.emit("close", undefined); // соперник отключается уже после конца
    expect(c0.sent.some((m) => (m as { type?: string }).type === "opponent_left")).toBe(false);
  });
});

describe("Room — аутентификация и reconnect", () => {
  it("неверный token → error + закрытие", () => {
    const room = makeRoom();
    const conn = new FakeConn();
    room.handleConnection(conn as never);
    conn.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "WRONG" }));
    expect(conn.sent).toContainEqual({ type: "error", reason: "invalid token" });
    expect(conn.readyState).toBe(3); // закрыт
  });

  it("reconnect по мёртвому conn проходит (слот освобождён при close)", () => {
    const room = makeRoom();
    const c0 = new FakeConn();
    room.handleConnection(c0 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    expect(c0.sent.some((m) => (m as { type?: string }).type === "joined")).toBe(true);
    c0.emit("close", undefined); // разрыв → слот освобождён

    const c0b = new FakeConn(); // новое соединение того же игрока
    room.handleConnection(c0b as never);
    c0b.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    expect(c0b.sent.some((m) => (m as { type?: string }).type === "joined")).toBe(true);
    expect(c0b.sent).not.toContainEqual({ type: "error", reason: "slot already connected" });
  });

  it("угон занятого ЖИВОГО слота отклоняется", () => {
    const room = makeRoom();
    const c0 = new FakeConn();
    room.handleConnection(c0 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    const hijack = new FakeConn(); // второй коннект под тем же id, старый жив
    room.handleConnection(hijack as never);
    hijack.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    expect(hijack.sent).toContainEqual({ type: "error", reason: "slot already connected" });
  });
});

describe("Room — валидация ходов и анти-чит", () => {
  function startedRoom(): { room: Room; c0: FakeConn } {
    const room = makeRoom();
    const c0 = new FakeConn();
    const c1 = new FakeConn();
    room.handleConnection(c0 as never);
    room.handleConnection(c1 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    c1.emit("message", JSON.stringify({ type: "hello", profile: p1, token: "tb" }));
    return { room, c0 };
  }

  it("ход до старта матча отклоняется", () => {
    const room = makeRoom();
    const c0 = new FakeConn();
    room.handleConnection(c0 as never);
    c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    // только один игрок → waiting
    c0.emit("message", JSON.stringify({ type: "move", pieceId: "x", cells: [[0, 0]], r: 0, c: 0 }));
    expect(c0.sent).toContainEqual({ type: "move_rejected", reason: "match not active" });
  });

  it("кривой ход (мусорные cells) отклоняется как malformed", () => {
    const { c0 } = startedRoom();
    c0.emit("message", JSON.stringify({ type: "move", pieceId: "x", cells: "нет", r: 0, c: 0 }));
    expect(c0.sent).toContainEqual({ type: "move_rejected", reason: "malformed move" });
  });

  it("валидный ход применяется и передаёт ход сопернику", () => {
    const { room, c0 } = startedRoom();
    const joined = c0.sent.find((m) => (m as { type?: string }).type === "joined") as {
      state: { players: Array<{ hand: Array<{ id: string; cells: number[][] }> }> };
    };
    const piece = joined.state.players[0].hand[0];
    expect(room.state.current).toBe(0);
    c0.emit(
      "message",
      JSON.stringify({ type: "move", pieceId: piece.id, cells: piece.cells, r: 0, c: 0 }),
    );
    // Ход принят (нет reject), состояние продвинулось, очередь перешла к сопернику.
    expect(c0.sent.some((m) => (m as { type?: string }).type === "move_rejected")).toBe(false);
    expect(room.state.turnCount).toBe(1);
    expect(room.state.current).toBe(1);
  });

  it("анти-чит: cells не соответствуют ориентации фигуры → отклонение", () => {
    const { c0 } = startedRoom();
    const joined = c0.sent.find((m) => (m as { type?: string }).type === "joined") as {
      state: { players: Array<{ hand: Array<{ id: string }> }> };
    };
    const pieceId = joined.state.players[0].hand[0].id;
    // Одна клетка вместо тетромино — валидна по форме, но не совпадает ни с одной
    // ориентацией фигуры → анти-чит отклоняет.
    c0.emit(
      "message",
      JSON.stringify({ type: "move", pieceId, cells: [[0, 0]], r: 0, c: 0 }),
    );
    expect(c0.sent).toContainEqual({ type: "move_rejected", reason: "invalid orientation" });
  });
});

/** Комната с обоими игроками в статусе playing + опциональным спаем onMatchOver. */
function bothInRoom(onOver?: (winner: number) => [number, number]): {
  room: Room;
  c0: FakeConn;
  c1: FakeConn;
} {
  const room = new Room(
    "t",
    { matchSeed: 42, participants: [p0, p1] },
    ["ta", "tb"],
    (r) => onOver?.(r.winner) ?? [1000, 1000],
    () => {},
  );
  const c0 = new FakeConn();
  const c1 = new FakeConn();
  room.handleConnection(c0 as never);
  room.handleConnection(c1 as never);
  c0.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
  c1.emit("message", JSON.stringify({ type: "hello", profile: p1, token: "tb" }));
  return { room, c0, c1 };
}

describe("Room — очередь ходов и реванш", () => {
  it("ход не в свою очередь отклоняется", () => {
    const { room, c1 } = bothInRoom();
    expect(room.state.current).toBe(0);
    c1.emit(
      "message",
      JSON.stringify({ type: "move", pieceId: "x", cells: [[0, 0]], r: 0, c: 0 }),
    );
    expect(c1.sent).toContainEqual({ type: "move_rejected", reason: "not your turn" });
  });

  it("оба запросили реванш → новый матч стартует (счёт/ход сброшены)", () => {
    const { room, c0, c1 } = bothInRoom();
    c0.emit("message", JSON.stringify({ type: "resign" })); // матч over
    expect(room.state.status).toBe("over");
    const seedBefore = room.state.matchSeed;
    c0.emit("message", JSON.stringify({ type: "rematch_request" }));
    c1.emit("message", JSON.stringify({ type: "rematch_request" }));
    expect(room.state.status).toBe("playing");
    expect(room.state.turnCount).toBe(0);
    expect(room.state.players[0].score).toBe(0);
    expect(room.state.result).toBeUndefined();
    expect(room.state.matchSeed).not.toBe(seedBefore); // новый seed реванша
  });

  it("rematch_request во время playing игнорируется (только из over)", () => {
    const { room } = bothInRoom();
    const c = new FakeConn();
    room.handleConnection(c as never);
    c.emit("message", JSON.stringify({ type: "hello", profile: p0, token: "ta" }));
    c.emit("message", JSON.stringify({ type: "rematch_request" }));
    expect(room.state.status).toBe("playing"); // не сбросилось
  });
});

describe("Room — таймаут хода (fake timers)", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("истечение turnDeadline завершает матч поражением текущего игрока", () => {
    const winners: number[] = [];
    const { room } = bothInRoom((w) => {
      winners.push(w);
      return [1000, 1000];
    });
    expect(room.state.status).toBe("playing");
    expect(room.state.current).toBe(0);
    vi.advanceTimersByTime(61_000); // TURN_TIME_MS=60с + запас
    expect(room.state.status).toBe("over");
    expect(room.state.result?.reason).toBe("timeout");
    expect(room.state.result?.winner).toBe(1); // текущий (0) проиграл по времени
    expect(winners).toContain(1); // отчёт в лидерборд
  });
});

describe("Lobby — устойчивость к malformed сообщениям (H-A)", () => {
  it("сообщение `null` не роняет обработчик", () => {
    const lobby = new Lobby(() => "room-x");
    const conn = new FakeConn();
    lobby.handleConnection(conn as never);
    expect(() => conn.emit("message", "null")).not.toThrow();
  });
});
