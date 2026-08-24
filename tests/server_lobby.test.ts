/**
 * server_lobby.test.ts — тесты матчмейкинга лобби PvP-сервера.
 *
 * Покрывает FIFO-пэйринг (2 в очереди → матч), отмену и bot-fallback по таймеру
 * (25с). Таймеры мокаются vi.useFakeTimers() — детерминированно и без ожидания
 * реального времени; интервал tick корректно останавливается.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { Lobby } from "../server/lobby";

class FakeConn {
  handlers: Record<string, (data: unknown) => void> = {};
  sent: Record<string, unknown>[] = [];
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
    this.handlers.close?.(undefined);
  }
  emit(event: string, data: unknown): void {
    this.handlers[event]?.(data);
  }
  received(type: string): Record<string, unknown> | undefined {
    return this.sent.find((m) => m.type === type);
  }
}

const A = { id: "a", nick: "Алиса", avatar: "🦊" };
const B = { id: "b", nick: "Боб", avatar: "🐼" };

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe("Lobby — матчмейкинг", () => {
  it("двое в очереди → onCreateMatch вызван, оба получают matched+token", () => {
    const calls: Array<[string, string]> = [];
    const lobby = new Lobby((a, b, tokenA, tokenB) => {
      calls.push([a.id, b.id]);
      expect(tokenA).not.toBe(tokenB);
      return "room-1";
    });
    const ca = new FakeConn();
    const cb = new FakeConn();
    lobby.handleConnection(ca as never);
    lobby.handleConnection(cb as never);
    ca.emit("message", JSON.stringify({ type: "queue", profile: A }));
    cb.emit("message", JSON.stringify({ type: "queue", profile: B }));

    expect(calls).toEqual([["a", "b"]]);
    expect(ca.received("matched")?.roomId).toBe("room-1");
    expect(cb.received("matched")?.roomId).toBe("room-1");
    expect(ca.received("matched")?.token).toBeDefined();
    // Очередь опустела → tick остановится сам; закрываем соединения для чистоты.
    ca.close();
    cb.close();
  });

  it("одиночка в очереди матч не создаёт", () => {
    let created = 0;
    const lobby = new Lobby(() => {
      created++;
      return "r";
    });
    const ca = new FakeConn();
    lobby.handleConnection(ca as never);
    ca.emit("message", JSON.stringify({ type: "queue", profile: A }));
    expect(created).toBe(0);
    ca.emit("message", JSON.stringify({ type: "cancel" }));
  });

  it("bot_fallback шлётся после 25с ожидания", () => {
    const lobby = new Lobby(() => "r");
    const ca = new FakeConn();
    lobby.handleConnection(ca as never);
    ca.emit("message", JSON.stringify({ type: "queue", profile: A }));
    expect(ca.received("bot_fallback")).toBeUndefined();
    vi.advanceTimersByTime(26_000); // tick каждые 5с, порог 25с
    expect(ca.received("bot_fallback")).toBeDefined();
    ca.close();
  });

  it("cancel убирает из очереди — второй игрок не пэйрится с ушедшим", () => {
    let created = 0;
    const lobby = new Lobby(() => {
      created++;
      return "r";
    });
    const ca = new FakeConn();
    const cb = new FakeConn();
    lobby.handleConnection(ca as never);
    lobby.handleConnection(cb as never);
    ca.emit("message", JSON.stringify({ type: "queue", profile: A }));
    ca.emit("message", JSON.stringify({ type: "cancel" }));
    cb.emit("message", JSON.stringify({ type: "queue", profile: B }));
    expect(created).toBe(0); // A ушёл до прихода B
    cb.close();
  });
});
