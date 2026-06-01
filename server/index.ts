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
import { createServer, type IncomingMessage } from "node:http";
import { WebSocketServer, type WebSocket } from "ws";
import type { OnlineProfile } from "../party/protocol";
import { Leaderboard } from "./leaderboard";
import { Lobby } from "./lobby";
import { Room } from "./room";

const PORT = parseInt(process.env.PORT ?? "1999", 10);
const LEADERBOARD_FILE = process.env.LEADERBOARD_FILE ?? "./data/leaderboard.json";

const leaderboard = new Leaderboard(LEADERBOARD_FILE);

const rooms = new Map<string, Room>();

const lobby = new Lobby((a, b) => {
  const roomId = `m_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
  const seed = (Math.random() * 0xffffffff) | 0;
  rooms.set(
    roomId,
    new Room(
      roomId,
      { matchSeed: seed, participants: [a, b] },
      (report) => leaderboard.reportMatch(report),
      () => {
        // оба отвалились → удаляем room
        rooms.delete(roomId);
      },
    ),
  );
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

const wss = new WebSocketServer({ noServer: true });

httpServer.on("upgrade", (req, socket, head) => {
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
      try {
        const msg = JSON.parse(String(data)) as { type: string; myId?: string };
        if (msg.type === "subscribe") leaderboard.subscribe(ws, msg.myId ?? null);
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
