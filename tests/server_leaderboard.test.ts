/**
 * server_leaderboard.test.ts — тесты ELO-лидерборда PvP-сервера.
 *
 * Прод-критичная логика рейтинга, до 2026-08-23 без единого теста. Покрывает:
 * формулу Elo (K=24), W/L/D-счётчики, анти-абьюз само-матча, персистентность
 * (round-trip через файл) и устойчивость к повреждённому файлу (L-C: бэкап
 * вместо тихой потери). Соединения — лёгкий FakeConn.
 */
import { existsSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { Leaderboard } from "../server/leaderboard";

class FakeConn {
  sent: Record<string, unknown>[] = [];
  readyState = 1;
  on(): this {
    return this;
  }
  send(data: string): void {
    this.sent.push(JSON.parse(data));
  }
  close(): void {
    this.readyState = 3;
  }
  last(): Record<string, unknown> {
    return this.sent[this.sent.length - 1];
  }
}

const A = { id: "a", nick: "Алиса", avatar: "🦊" };
const B = { id: "b", nick: "Боб", avatar: "🐼" };

let dir: string;
let path: string;
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "bd-lb-"));
  path = join(dir, "leaderboard.json");
});
afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

/** Читает запись игрока из свежего снапшота подписки. */
function entryOf(lb: Leaderboard, id: string): Record<string, unknown> | undefined {
  const c = new FakeConn();
  lb.subscribe(c as never, id);
  return c.last().you as Record<string, unknown> | undefined;
}

describe("Leaderboard — формула Elo (K=24)", () => {
  it("равные рейтинги, победа A → +12 / -12 (симметрично)", () => {
    const lb = new Leaderboard(path);
    const [na, nb] = lb.reportMatch({ participants: [A, B], winner: 0 });
    expect(na).toBe(1012);
    expect(nb).toBe(988);
  });

  it("ничья равных не меняет рейтинг", () => {
    const lb = new Leaderboard(path);
    const [na, nb] = lb.reportMatch({ participants: [A, B], winner: -1 });
    expect(na).toBe(1000);
    expect(nb).toBe(1000);
  });

  it("W/L/D-счётчики растут по исходу", () => {
    const lb = new Leaderboard(path);
    lb.reportMatch({ participants: [A, B], winner: 0 }); // A win, B loss
    lb.reportMatch({ participants: [A, B], winner: -1 }); // draw
    const a = entryOf(lb, "a")!;
    const b = entryOf(lb, "b")!;
    expect(a.wins).toBe(1);
    expect(a.draws).toBe(1);
    expect(a.losses).toBe(0);
    expect(b.losses).toBe(1);
    expect(b.draws).toBe(1);
  });

  it("само-матч (одинаковый id) не меняет ELO — анти-фарм", () => {
    const lb = new Leaderboard(path);
    lb.reportMatch({ participants: [A, B], winner: 0 }); // A→1012
    const [na, nb] = lb.reportMatch({ participants: [A, A], winner: 0 });
    expect(na).toBe(1012);
    expect(nb).toBe(1012);
    expect(entryOf(lb, "a")!.wins).toBe(1); // не прибавилось от само-матча
  });
});

describe("Leaderboard — персистентность", () => {
  it("round-trip: запись переживает перезапуск через файл", async () => {
    const lb = new Leaderboard(path);
    lb.reportMatch({ participants: [A, B], winner: 0 });
    await lb.flushNow();
    expect(existsSync(path)).toBe(true);

    const lb2 = new Leaderboard(path); // новый инстанс читает файл
    expect(entryOf(lb2, "a")!.elo).toBe(1012);
    expect(entryOf(lb2, "b")!.elo).toBe(988);
  });
});

describe("Leaderboard — устойчивость к битому файлу (L-C)", () => {
  it("повреждённый JSON не роняет и бэкапится в .corrupt-*", () => {
    writeFileSync(path, "не json {{{{");
    // Конструктор не должен бросать.
    const lb = new Leaderboard(path);
    // Стартует пустым.
    const c = new FakeConn();
    lb.subscribe(c as never, null);
    expect(c.last().totalPlayers).toBe(0);
    // Битый файл отодвинут в бэкап.
    const backups = readdirSync(dir).filter((f) => f.includes(".corrupt-"));
    expect(backups.length).toBe(1);
  });
});
