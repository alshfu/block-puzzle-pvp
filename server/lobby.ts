import type {
  LobbyClient2Server,
  LobbyServer2Client,
  OnlineProfile,
} from "../party/protocol";
import type { Conn } from "./types";

const BOT_FALLBACK_AFTER_MS = 25_000;

interface QueueEntry {
  conn: Conn;
  profile: OnlineProfile;
  enqueuedAt: number;
}

export class Lobby {
  private queue: QueueEntry[] = [];
  private tickTimer: NodeJS.Timeout | null = null;

  constructor(private onCreateMatch: (a: OnlineProfile, b: OnlineProfile) => string) {}

  handleConnection(conn: Conn): void {
    conn.on("message", (data) => {
      let msg: LobbyClient2Server;
      try {
        msg = JSON.parse(String(data));
      } catch {
        return;
      }
      if (msg.type === "queue") this.onQueue(conn, msg.profile);
      else if (msg.type === "cancel") this.onCancel(conn);
    });
    conn.on("close", () => this.onCancel(conn));
  }

  private onQueue(conn: Conn, profile: OnlineProfile): void {
    if (!this.queue.some((q) => q.conn === conn)) {
      this.queue.push({ conn, profile, enqueuedAt: Date.now() });
    }
    this.ensureTick();
    this.tryMatch();
    this.broadcastPositions();
  }

  private onCancel(conn: Conn): void {
    this.queue = this.queue.filter((q) => q.conn !== conn);
    this.broadcastPositions();
    this.stopTickIfEmpty();
  }

  private ensureTick(): void {
    if (this.tickTimer) return;
    this.tickTimer = setInterval(() => this.tick(), 5000);
  }
  private stopTickIfEmpty(): void {
    if (this.queue.length === 0 && this.tickTimer) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }
  }
  private tick(): void {
    const now = Date.now();
    const still: QueueEntry[] = [];
    for (const q of this.queue) {
      if (now - q.enqueuedAt >= BOT_FALLBACK_AFTER_MS) {
        this.send(q.conn, { type: "bot_fallback" });
      } else {
        still.push(q);
      }
    }
    this.queue = still;
    this.broadcastPositions();
    this.stopTickIfEmpty();
  }

  private tryMatch(): void {
    while (this.queue.length >= 2) {
      const a = this.queue.shift()!;
      const b = this.queue.shift()!;
      try {
        const roomId = this.onCreateMatch(a.profile, b.profile);
        this.send(a.conn, { type: "matched", roomId, opponent: b.profile });
        this.send(b.conn, { type: "matched", roomId, opponent: a.profile });
      } catch (err) {
        console.error("[lobby] tryMatch failed:", err);
        this.queue.unshift(b, a);
        return;
      }
    }
  }

  private broadcastPositions(): void {
    const now = Date.now();
    this.queue.forEach((q, idx) => {
      this.send(q.conn, {
        type: "queued",
        position: idx + 1,
        waitedSec: Math.floor((now - q.enqueuedAt) / 1000),
      });
    });
  }

  private send(conn: Conn, msg: LobbyServer2Client): void {
    try {
      if (conn.readyState === 1) conn.send(JSON.stringify(msg));
    } catch {
      /* ignore */
    }
  }
}
