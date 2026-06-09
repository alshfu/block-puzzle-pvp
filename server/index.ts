/**
 * BlockDuel multiplayer backend — standalone Node.js + ws.
 *
 * URL format: совместим с PartySocket → ws://host/parties/<party>/<roomId>
 *   - /parties/lobby/main         — singleton-лобби (matchmaking)
 *   - /parties/room/<roomId>      — отдельная комната-матч
 *   - /parties/leaderboard/main   — глобальный ELO-лидерборд
 *
 * Запуск:
 *   npx tsx server/index.ts
 * Переменные окружения:
 *   PORT                — порт (по умолчанию 1999)
 *   LEADERBOARD_FILE    — путь к persistent JSON (по умолч. ./data/leaderboard.json)
 */
import { randomInt, randomUUID } from "node:crypto";
import { createServer, type IncomingMessage } from "node:http";
import { WebSocketServer, type WebSocket } from "ws";
import type { OnlineProfile } from "../party/protocol";
import { Leaderboard } from "./leaderboard";
import { RateLimiter } from "./limits";
import { Lobby } from "./lobby";
import { Room } from "./room";

const PORT = parseInt(process.env.PORT ?? "1999", 10);
const LEADERBOARD_FILE = process.env.LEADERBOARD_FILE ?? "./data/leaderboard.json";

/** M2: потолок числа одновременных комнат (анти-флуд созданием матчей). */
const MAX_ROOMS = 2_000;

/** M2: TTL пустой waiting-комнаты — удаляем, если матч так и не начался. */
const WAITING_ROOM_TTL_MS = 120_000;

/** M5: allow-list Origin (CSV в env). Пусто → разрешаем все (не ломаем прод). */
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const leaderboard = new Leaderboard(LEADERBOARD_FILE);

const rooms = new Map<string, Room>();

const lobby = new Lobby((a, b, tokenA, tokenB) => {
  if (rooms.size >= MAX_ROOMS) throw new Error("room cap reached"); // M2
  // L1/L2: непредсказуемые roomId и seed (crypto вместо Math.random/времени).
  const roomId = `m_${randomUUID()}`;
  const seed = randomInt(0, 0x1_0000_0000);
  rooms.set(
    roomId,
    new Room(
      roomId,
      { matchSeed: seed, participants: [a, b] },
      [tokenA, tokenB],
      (report) => leaderboard.reportMatch(report),
      () => {
        // оба отвалились → удаляем room
        rooms.delete(roomId);
      },
    ),
  );
  // M2: подчищаем комнату, если матч не стартовал за TTL (клиенты не пришли).
  setTimeout(() => {
    const r = rooms.get(roomId);
    if (r && r.state.status === "waiting") rooms.delete(roomId);
  }, WAITING_ROOM_TTL_MS);
  return roomId;
});

// ─── HTTP + WS upgrade ─────────────────────────────────────────────────────
const httpServer = createServer((req, res) => {
  if (req.method === "GET" && req.url === "/healthz") {
    res.writeHead(200, { "content-type": "text/plain" });
    res.end("ok");
    return;
  }
  res.writeHead(404, { "content-type": "text/plain" });
  res.end("not found");
});

// maxPayload (H4): кадр > 16 KiB отвергается на уровне ws — отсекает oversized.
const wss = new WebSocketServer({ noServer: true, maxPayload: 16 * 1024 });

// Rate-limit подписок лидерборда (H4); лобби/комната держат свои лимитеры.
const leaderboardLimiter = new RateLimiter();

httpServer.on("upgrade", (req, socket, head) => {
  // M5 (CSWSH): если задан ALLOWED_ORIGINS — пускаем только эти Origin.
  // Запросы без Origin (нативные клиенты Flutter/desktop, curl) пропускаем.
  if (ALLOWED_ORIGINS.length > 0) {
    const origin = req.headers.origin;
    if (origin && !ALLOWED_ORIGINS.includes(origin)) {
      socket.write("HTTP/1.1 403 Forbidden\r\n\r\n");
      socket.destroy();
      return;
    }
  }
  const route = parseRoute(req);
  if (!route) {
    socket.write("HTTP/1.1 404 Not Found\r\n\r\n");
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit("connection", ws, req, route);
  });
});

wss.on("connection", (ws: WebSocket, _req: IncomingMessage, route: Route) => {
  // ОБЯЗАТЕЛЬНО: без обработчика 'error' любая ошибка сокета (в т.ч.
  // превышение maxPayload, code 1009) эмитит unhandled 'error' и роняет ВЕСЬ
  // процесс. Гасим на уровне соединения — закрываем только этот сокет.
  ws.on("error", () => {
    try {
      ws.close();
    } catch {
      /* ignore */
    }
  });

  if (route.party === "lobby") {
    lobby.handleConnection(ws);
    return;
  }
  if (route.party === "room") {
    let room = rooms.get(route.roomId);
    if (!room) {
      // комната не создана через lobby → отказываем
      try {
        ws.send(JSON.stringify({ type: "error", reason: "room not initialised" }));
        ws.close();
      } catch {
        /* ignore */
      }
      return;
    }
    room.handleConnection(ws);
    return;
  }
  if (route.party === "leaderboard") {
    ws.on("message", (data) => {
      if (!leaderboardLimiter.allow(ws)) return; // H4: дропаем флуд
      try {
        const msg = JSON.parse(String(data)) as { type: string; myId?: string };
        // myId должен быть строкой ограниченной длины (анти-мусор).
        const myId = typeof msg.myId === "string" && msg.myId.length <= 64 ? msg.myId : null;
        if (msg.type === "subscribe") leaderboard.subscribe(ws, myId);
      } catch {
        /* ignore */
      }
    });
    ws.on("close", () => leaderboard.unsubscribe(ws));
    return;
  }
});

httpServer.listen(PORT, () => {
  console.log(`[server] listening on :${PORT} (leaderboard at ${LEADERBOARD_FILE})`);
});

// ─── route parsing ─────────────────────────────────────────────────────────
interface Route {
  party: "lobby" | "room" | "leaderboard";
  roomId: string;
}

function parseRoute(req: IncomingMessage): Route | null {
  if (!req.url) return null;
  // ws://host/parties/<party>/<roomId>   совместимо с PartySocket
  const m = req.url.match(/^\/parties\/(lobby|room|leaderboard)\/([^/?#]+)/);
  if (!m) return null;
  return { party: m[1] as Route["party"], roomId: decodeURIComponent(m[2]) };
}

// также экспорт типа для совместимости с другими файлами
export type { OnlineProfile };
