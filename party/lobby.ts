import type * as Party from "partykit/server";
import type {
  LobbyClient2Server,
  LobbyServer2Client,
  MatchSeed,
  OnlineProfile,
} from "./protocol";

interface QueueEntry {
  connId: string;
  profile: OnlineProfile;
  enqueuedAt: number;
}

const BOT_FALLBACK_AFTER_MS = 25_000;

/**
 * Singleton lobby: единая FIFO-очередь quick-play.
 * Когда в очереди ≥2 игроков — берём первых двух, создаём комнату через RPC
 * к party "room", шлём обоим "matched" с roomId.
 */
export default class LobbyServer implements Party.Server {
  queue: QueueEntry[] = [];
  /** Один alarm tick — каждые 5 секунд проверяем кому пора уходить к боту. */
  tickTimer: ReturnType<typeof setInterval> | null = null;

  constructor(readonly room: Party.Room) {}

  private ensureTick(): void {
    if (this.tickTimer) return;
    this.tickTimer = setInterval(() => this.onTick(), 5000);
  }
  private stopTickIfEmpty(): void {
    if (this.queue.length === 0 && this.tickTimer) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }
  }
  private onTick(): void {
    const now = Date.now();
    const stillWaiting: QueueEntry[] = [];
    for (const q of this.queue) {
      if (now - q.enqueuedAt >= BOT_FALLBACK_AFTER_MS) {
        const conn = this.room.getConnection(q.connId);
        if (conn) this.send(conn, { type: "bot_fallback" });
      } else {
        stillWaiting.push(q);
      }
    }
    this.queue = stillWaiting;
    this.broadcastQueuePositions();
    this.stopTickIfEmpty();
  }

  /** Регистрация подключения: ничего не делаем, ждём сообщения "queue". */
  onConnect(_conn: Party.Connection, _ctx: Party.ConnectionContext) {}

  onClose(connection: Party.Connection) {
    this.queue = this.queue.filter((q) => q.connId !== connection.id);
    this.broadcastQueuePositions();
  }

  async onMessage(message: string, sender: Party.Connection) {
    let msg: LobbyClient2Server;
    try {
      msg = JSON.parse(message);
    } catch {
      this.send(sender, { type: "error", reason: "bad json" });
      return;
    }

    if (msg.type === "queue") {
      if (!this.queue.some((q) => q.connId === sender.id)) {
        this.queue.push({ connId: sender.id, profile: msg.profile, enqueuedAt: Date.now() });
      }
      this.ensureTick();
      await this.tryMatch();
      this.broadcastQueuePositions();
      return;
    }

    if (msg.type === "cancel") {
      this.queue = this.queue.filter((q) => q.connId !== sender.id);
      this.broadcastQueuePositions();
      return;
    }
  }

  private async tryMatch(): Promise<void> {
    while (this.queue.length >= 2) {
      const a = this.queue.shift()!;
      const b = this.queue.shift()!;

      const roomId = `m_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
      const matchSeed = Math.floor(Math.random() * 0xffffffff);

      // RPC к комнате: создаём её и регистрируем участников.
      const roomParty = this.room.context.parties.room.get(roomId);
      const seedPayload: MatchSeed = {
        matchSeed,
        participants: [a.profile, b.profile],
      };
      try {
        await roomParty.fetch({
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(seedPayload),
        });
      } catch (err) {
        // Если что-то пошло не так — возвращаем игроков в очередь.
        this.queue.unshift(b, a);
        console.error("Failed to create room", err);
        return;
      }

      const aConn = this.room.getConnection(a.connId);
      const bConn = this.room.getConnection(b.connId);
      if (aConn) this.send(aConn, { type: "matched", roomId, opponent: b.profile });
      if (bConn) this.send(bConn, { type: "matched", roomId, opponent: a.profile });
    }
  }

  private broadcastQueuePositions(): void {
    const now = Date.now();
    this.queue.forEach((q, idx) => {
      const conn = this.room.getConnection(q.connId);
      if (conn) {
        this.send(conn, {
          type: "queued",
          position: idx + 1,
          waitedSec: Math.floor((now - q.enqueuedAt) / 1000),
        });
      }
    });
  }

  private send(conn: Party.Connection, msg: LobbyServer2Client): void {
    conn.send(JSON.stringify(msg));
  }
}
