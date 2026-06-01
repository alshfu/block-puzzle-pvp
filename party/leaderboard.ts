import type * as Party from "partykit/server";
import type {
  LeaderboardClient2Server,
  LeaderboardEntry,
  LeaderboardMatchReport,
  LeaderboardServer2Client,
  OnlineProfile,
} from "./protocol";

/**
 * Глобальный лидерборд. Один экземпляр на всю игру (room "main").
 *
 * Хранилище — `room.storage` (PartyKit KV, persistent). Каждый игрок — отдельный
 * ключ `p:<id>` со своим LeaderboardEntry. Дополнительно держим в памяти отсортированный
 * Top-N кеш, инвалидируем при апдейтах.
 */

const TOP_N = 100;
const START_ELO = 1000;
const K = 24;

export default class LeaderboardServer implements Party.Server {
  /** Кеш TOP_N — пересоберется при следующем сэмплинге если invalid. */
  topCache: LeaderboardEntry[] | null = null;
  /** Сумма всех игроков (для ранга/общего количества). */
  totalPlayers = 0;
  loaded = false;

  constructor(readonly room: Party.Room) {}

  // ─── Загрузка кеша из storage при первом обращении ─────────────────────
  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    const all = await this.room.storage.list<LeaderboardEntry>({ prefix: "p:" });
    const arr: LeaderboardEntry[] = [];
    all.forEach((v) => arr.push(v));
    arr.sort((a, b) => b.elo - a.elo);
    this.topCache = arr.slice(0, TOP_N);
    this.totalPlayers = arr.length;
    this.loaded = true;
  }

  // ─── RPC от room.ts: внести результат матча ────────────────────────────
  async onRequest(req: Party.Request): Promise<Response> {
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
    let report: LeaderboardMatchReport;
    try {
      report = (await req.json()) as LeaderboardMatchReport;
    } catch {
      return new Response("bad json", { status: 400 });
    }
    await this.ensureLoaded();

    const [pa, pb] = report.participants;
    const a = await this.getEntry(pa);
    const b = await this.getEntry(pb);

    // Скор в формате ELO: 1 / 0.5 / 0.
    const sa = report.winner === 0 ? 1 : report.winner === -1 ? 0.5 : 0;
    const sb = 1 - sa;
    const ea = 1 / (1 + Math.pow(10, (b.elo - a.elo) / 400));
    const eb = 1 - ea;
    const newA = Math.round(a.elo + K * (sa - ea));
    const newB = Math.round(b.elo + K * (sb - eb));

    const now = Date.now();
    const updA: LeaderboardEntry = {
      ...a,
      elo: newA,
      wins: a.wins + (report.winner === 0 ? 1 : 0),
      losses: a.losses + (report.winner === 1 ? 1 : 0),
      draws: a.draws + (report.winner === -1 ? 1 : 0),
      updatedAt: now,
    };
    const updB: LeaderboardEntry = {
      ...b,
      elo: newB,
      wins: b.wins + (report.winner === 1 ? 1 : 0),
      losses: b.losses + (report.winner === 0 ? 1 : 0),
      draws: b.draws + (report.winner === -1 ? 1 : 0),
      updatedAt: now,
    };
    await this.room.storage.put(`p:${updA.id}`, updA);
    await this.room.storage.put(`p:${updB.id}`, updB);

    // Инвалидация кеша + ребродкаст всем подписчикам
    this.topCache = null;
    await this.ensureLoaded();
    this.broadcastSnapshot();

    return Response.json({ a: updA, b: updB });
  }

  // ─── WS-клиенты (UI экрана Leaderboard) ────────────────────────────────
  async onConnect(_conn: Party.Connection): Promise<void> {
    await this.ensureLoaded();
  }

  async onMessage(message: string, sender: Party.Connection): Promise<void> {
    let msg: LeaderboardClient2Server;
    try {
      msg = JSON.parse(message);
    } catch {
      return;
    }
    if (msg.type === "subscribe") {
      await this.ensureLoaded();
      this.sendSnapshot(sender, msg.myId ?? null);
    } else if (msg.type === "ping") {
      // no-op
    }
  }

  // ─── helpers ───────────────────────────────────────────────────────────
  private async getEntry(p: OnlineProfile): Promise<LeaderboardEntry> {
    const cur = await this.room.storage.get<LeaderboardEntry>(`p:${p.id}`);
    if (cur) {
      // обновим nick/avatar на случай если игрок их сменил
      return { ...cur, nick: p.nick, avatar: p.avatar };
    }
    this.totalPlayers += 1;
    return {
      id: p.id,
      nick: p.nick,
      avatar: p.avatar,
      elo: START_ELO,
      wins: 0,
      losses: 0,
      draws: 0,
      updatedAt: Date.now(),
    };
  }

  private async sendSnapshot(conn: Party.Connection, myId: string | null): Promise<void> {
    const top = this.topCache ?? [];
    let you: LeaderboardEntry | undefined;
    let yourRank: number | undefined;
    if (myId) {
      const idx = top.findIndex((e) => e.id === myId);
      if (idx >= 0) {
        you = top[idx];
        yourRank = idx + 1;
      } else {
        // не в топе — берём из storage
        const me = await this.room.storage.get<LeaderboardEntry>(`p:${myId}`);
        if (me) {
          you = me;
          // приблизительный ранг: сколько игроков имеет elo выше
          const all = await this.room.storage.list<LeaderboardEntry>({ prefix: "p:" });
          let above = 0;
          all.forEach((v) => { if (v.elo > me.elo) above++; });
          yourRank = above + 1;
        }
      }
    }
    const out: LeaderboardServer2Client = {
      type: "snapshot",
      top,
      you,
      yourRank,
      totalPlayers: this.totalPlayers,
    };
    conn.send(JSON.stringify(out));
  }

  private broadcastSnapshot(): void {
    // ленивый бродкаст: всем подключённым повторно посылаем snapshot.
    // Они присылали "subscribe" с myId — но мы его не помним. Поэтому шлём
    // общий snapshot без `you` — пусть клиент потом сам ресабскрайбится.
    const out: LeaderboardServer2Client = {
      type: "snapshot",
      top: this.topCache ?? [],
      totalPlayers: this.totalPlayers,
    };
    const text = JSON.stringify(out);
    for (const conn of this.room.getConnections()) conn.send(text);
  }
}
