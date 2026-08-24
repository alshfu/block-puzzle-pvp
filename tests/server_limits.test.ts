/**
 * server_limits.test.ts — тесты защитных ограничений протокола (limits.ts).
 *
 * Security-критичные чистые функции (анти-чит формы хода, анти-мусор профиля,
 * анти-DoS rate-limit), до 2026-08-23 без тестов. Покрывает граничные случаи,
 * на которых держится валидация входа сервера.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  DEFAULT_MSG_PER_WINDOW,
  isValidMoveInput,
  isValidProfile,
  MAX_ID_LEN,
  RateLimiter,
} from "../server/limits";

describe("isValidMoveInput — форма/диапазон хода (анти-чит M1)", () => {
  const goodCells = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, 2],
  ]; // T-тетромино

  it("валидная фигура 1..5 клеток в [0,8] проходит", () => {
    expect(isValidMoveInput(goodCells, 3, 4)).toBe(true);
    expect(isValidMoveInput([[0, 0]], 0, 0)).toBe(true);
  });

  it("не массив / пусто / >5 клеток — отклонено", () => {
    expect(isValidMoveInput("нет", 0, 0)).toBe(false);
    expect(isValidMoveInput([], 0, 0)).toBe(false);
    expect(isValidMoveInput([[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5]], 0, 0)).toBe(false);
  });

  it("клетка не пара / нецелая / вне [0,8] — отклонено", () => {
    expect(isValidMoveInput([[0]], 0, 0)).toBe(false); // не пара
    expect(isValidMoveInput([[0, 1, 2]], 0, 0)).toBe(false); // тройка
    expect(isValidMoveInput([[0.5, 1]], 0, 0)).toBe(false); // дробь
    expect(isValidMoveInput([[9, 0]], 0, 0)).toBe(false); // 9 вне доски
    expect(isValidMoveInput([[-1, 0]], 0, 0)).toBe(false); // отрицательная
    expect(isValidMoveInput([["a", 0]], 0, 0)).toBe(false); // строка
  });

  it("r/c нецелые или вне диапазона — отклонено", () => {
    expect(isValidMoveInput(goodCells, 9, 0)).toBe(false);
    expect(isValidMoveInput(goodCells, 0, -1)).toBe(false);
    expect(isValidMoveInput(goodCells, 1.5, 0)).toBe(false);
    expect(isValidMoveInput(goodCells, "0", 0)).toBe(false);
  });
});

describe("isValidProfile — санитайз профиля (M6)", () => {
  const ok = { id: "u1", nick: "Алиса", avatar: "🦊" };

  it("валидный профиль проходит", () => {
    expect(isValidProfile(ok)).toBe(true);
  });

  it("не объект / null — отклонено", () => {
    expect(isValidProfile(null)).toBe(false);
    expect(isValidProfile("нет")).toBe(false);
    expect(isValidProfile(undefined)).toBe(false);
    expect(isValidProfile(42)).toBe(false);
  });

  it("пустые/отсутствующие поля — отклонено", () => {
    expect(isValidProfile({ id: "", nick: "A", avatar: "x" })).toBe(false);
    expect(isValidProfile({ id: "u", nick: "", avatar: "x" })).toBe(false);
    expect(isValidProfile({ id: "u", nick: "A" })).toBe(false); // нет avatar
  });

  it("слишком длинный id — отклонено (анти-раздувание)", () => {
    expect(isValidProfile({ ...ok, id: "x".repeat(MAX_ID_LEN + 1) })).toBe(false);
    expect(isValidProfile({ ...ok, id: "x".repeat(MAX_ID_LEN) })).toBe(true);
  });
});

describe("RateLimiter — оконный лимит (анти-DoS H4)", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  const conn = {} as never;

  it("пропускает ровно max сообщений, дропает сверх", () => {
    const rl = new RateLimiter();
    for (let i = 0; i < DEFAULT_MSG_PER_WINDOW; i++) {
      expect(rl.allow(conn)).toBe(true);
    }
    expect(rl.allow(conn)).toBe(false); // 41-е — дроп
    expect(rl.allow(conn)).toBe(false);
  });

  it("окно сбрасывается по истечении windowMs", () => {
    const rl = new RateLimiter(3, 1000);
    const c = {} as never;
    expect(rl.allow(c)).toBe(true);
    expect(rl.allow(c)).toBe(true);
    expect(rl.allow(c)).toBe(true);
    expect(rl.allow(c)).toBe(false); // лимит 3
    vi.advanceTimersByTime(1001); // новое окно
    expect(rl.allow(c)).toBe(true);
  });

  it("разные соединения лимитируются независимо", () => {
    const rl = new RateLimiter(1, 1000);
    const a = {} as never;
    const b = {} as never;
    expect(rl.allow(a)).toBe(true);
    expect(rl.allow(a)).toBe(false);
    expect(rl.allow(b)).toBe(true); // b — свой счётчик
  });
});
