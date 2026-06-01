/**
 * Глобальный лидерборд. Singleton в памяти + persistent JSON-файл.
 * ELO K=24, старт 1000. Победа = 1, ничья = 0.5, проигрыш = 0.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import type {
  LeaderboardEntry,
  LeaderboardMatchReport,
  LeaderboardServer2Client,
  OnlineProfile,
} from "../party/protocol";
import type { Conn } from "./types";

const TOP_N = 100;
const START_ELO = 1000;
const K = 24;

export class Leaderboard {
  private entries = new Map<string, LeaderboardEntry>();
  private subscribers = new Map<Conn, string | null>(); // conn → myId

  constructor(private storagePath: string) {
    this.load();
  }

  private load(): void {
    try {
      const raw = readFileSync(this.storagePath, "utf8");
      const arr = JSON.parse(raw) as LeaderboardEntry[];
      for (const e of arr) this.entries.set(e.id, e);
      console.log(`[leaderboard] loaded ${this.entries.size} entries from ${this.storagePath}`);
    } catch (err: unknown) {
      const e = err as { code?: string };
      if (e.code !== "ENOENT") console.warn(`[leaderboard] load failed:`, err);
    }
  }

  private save(): void {
    try {
      mkdirSync(dirname(this.storagePath), { recursive: true });
      writeFileSync(this.storagePath, JSON.stringify([...this.entries.values()], null, 2));
    } catch (err) {
      console.warn(`[leaderboard] save failed:`, err);
    }
  }

  reportMatch(report: LeaderboardMatchReport): void {
    const [pa, pb] = report.participants;
    const a = this.getOrCreate(pa);
    const b = this.getOrCreate(pb);

    const sa = report.winner === 0 ? 1 : report.winner === -1 ? 0.5 : 0;
    const sb = 1 - sa;
    const ea = 1 / (1 + Math.pow(10, (b.elo - a.elo) / 400));
    const eb = 1 - ea;
    const newA = Math.round(a.elo + K * (sa - ea));
    const newB = Math.round(b.elo + K * (sb - eb));
    const now = Date.now();

    const updA: LeaderboardEntry = {
      ...a,
      nick: pa.nick,
      avatar: pa.avatar,
      elo: newA,
      wins: a.wins + (report.winner === 0 ? 1 : 0),
      losses: a.losses + (report.winner === 1 ? 1 : 0),
      draws: a.draws + (report.winner === -1 ? 1 : 0),
      updatedAt: now,
    };
    const updB: LeaderboardEntry = {
      ...b,
      nick: pb.nick,
      avatar: pb.avatar,
      elo: newB,
      wins: b.wins + (report.winner === 1 ? 1 : 0),
      losses: b.losses + (report.winner === 0 ? 1 : 0),
      draws: b.draws + (report.winner === -1 ? 1 : 0),
      updatedAt: now,
    };
    this.entries.set(updA.id, updA);
    this.entries.set(updB.id, updB);
    this.save();
    this.broadcastSnapshot();
  }

  private getOrCreate(p: OnlineProfile): LeaderboardEntry {
    const cur = this.entries.get(p.id);
    if (cur) return cur;
    const fresh: LeaderboardEntry = {
      id: p.id,
      nick: p.nick,
      avatar: p.avatar,
      elo: START_ELO,
      wins: 0,
      losses: 0,
      draws: 0,
      updatedAt: Date.now(),
    };
    this.entries.set(p.id, fresh);
    return fresh;
  }

  subscribe(conn: Conn, myId: string | null): void {
    this.subscribers.set(conn, myId);
    this.sendSnapshot(conn, myId);
  }

  unsubscribe(conn: Conn): void {
    this.subscribers.delete(conn);
  }

  private top(): LeaderboardEntry[] {
    return [...this.entries.values()].sort((a, b) => b.elo - a.elo).slice(0, TOP_N);
  }

  private sendSnapshot(conn: Conn, myId: string | null): void {
    const top = this.top();
    let you: LeaderboardEntry | undefined;
    let yourRank: number | undefined;
    if (myId) {
      const idx = top.findIndex((e) => e.id === myId);
      if (idx >= 0) {
        you = top[idx];
        yourRank = idx + 1;
      } else {
        const me = this.entries.get(myId);
        if (me) {
          you = me;
          let above = 0;
          for (const e of this.entries.values()) if (e.elo > me.elo) above++;
          yourRank = above + 1;
        }
      }
    }
    const out: LeaderboardServer2Client = {
      type: "snapshot",
      top,
      you,
      yourRank,
      totalPlayers: this.entries.size,
    };
    safeSend(conn, JSON.stringify(out));
  }

  private broadcastSnapshot(): void {
    for (const [conn, myId] of this.subscribers) this.sendSnapshot(conn, myId);
  }
}

function safeSend(conn: Conn, text: string): void {
  try {
    if (conn.readyState === 1 /* OPEN */) conn.send(text);
  } catch {
    /* ignore */
  }
}
