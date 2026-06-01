import { describe, expect, it } from "vitest";
import { ALL_TYPES, Bag, makeRng } from "../src/core";

describe("Bag (7-bag)", () => {
  it("первые 7 фигур содержат каждую ровно один раз", () => {
    const bag = new Bag(42);
    const first7 = Array.from({ length: 7 }, () => bag.next()).sort();
    expect(first7).toEqual([...ALL_TYPES].sort());
  });

  it("следующие 7 — также полный набор (каждый мешок честный)", () => {
    const bag = new Bag(42);
    for (let i = 0; i < 7; i++) bag.next();
    const next7 = Array.from({ length: 7 }, () => bag.next()).sort();
    expect(next7).toEqual([...ALL_TYPES].sort());
  });

  it("детерминизм: один и тот же seed → одна и та же последовательность", () => {
    const a = new Bag(123);
    const b = new Bag(123);
    for (let i = 0; i < 50; i++) expect(a.next()).toBe(b.next());
  });

  it("разные seed → разные последовательности (на достаточном горизонте)", () => {
    const a = new Bag(1);
    const b = new Bag(2);
    const sa: string[] = [];
    const sb: string[] = [];
    for (let i = 0; i < 50; i++) { sa.push(a.next()); sb.push(b.next()); }
    expect(sa.join(",")).not.toBe(sb.join(","));
  });

  it("draw() выдаёт уникальные id и нормализованные клетки", () => {
    const bag = new Bag(7);
    const ids = new Set<string>();
    for (let i = 0; i < 20; i++) {
      const p = bag.draw();
      expect(ids.has(p.id)).toBe(false);
      ids.add(p.id);
      const minR = Math.min(...p.cells.map((c) => c[0]));
      const minC = Math.min(...p.cells.map((c) => c[1]));
      expect(minR).toBe(0);
      expect(minC).toBe(0);
    }
  });

  it("makeRng детерминирован", () => {
    const r1 = makeRng(99);
    const r2 = makeRng(99);
    for (let i = 0; i < 100; i++) expect(r1()).toBe(r2());
  });
});
