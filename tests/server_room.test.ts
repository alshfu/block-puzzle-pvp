/**
 * server_room.test.ts — тесты стейт-машины PvP-сервера (Room/Lobby).
 *
 * Раньше server/*.ts не имели ни одного теста (ядро покрыто, стейт-машина — нет).
 * Здесь — регрессы на баги из аудита 2026-08-23:
 *   H-A: сообщение `null` / `hello` без profile роняли ВЕСЬ Node-процесс;
 *   M-A: `resign` в статусе `waiting` завершал матч и менял ELO до входа оппонента.
 * Соединения мокаются лёгким FakeConn (WebSocket-совместимый по нужным методам).
 */
import { describe, expect, it } from "vitest";

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

describe("Lobby — устойчивость к malformed сообщениям (H-A)", () => {
  it("сообщение `null` не роняет обработчик", () => {
    const lobby = new Lobby(() => "room-x");
    const conn = new FakeConn();
    lobby.handleConnection(conn as never);
    expect(() => conn.emit("message", "null")).not.toThrow();
  });
});
