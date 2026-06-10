/**
 * online-bot-client.ts — headless-клиент-оппонент для E2E-проверки онлайн PvP.
 *
 * За что отвечает файл:
 *   Подключается к WS-серверу (lobby → quickmatch → room) как обычный игрок
 *   и автоматически играет матч ходами из ядра (`chooseBotMove`), пока матч
 *   не закончится. Нужен, чтобы вживую проверять онлайн на одном устройстве:
 *   реальный клиент (Flutter web/macos с пилотом) против этого бота.
 *   Свой профиль (id `e2e-bot-<рандом>`) — не коллидирует с профилем клиента.
 *
 * Протокол: party/protocol.ts (lobby `queue`→`matched`; room `hello`→
 * `joined`/`state`, ходы `move {pieceId, cells, r, c}`).
 *
 * Запуск (сервер должен быть запущен, см. npm run server:dev):
 *   npx tsx tools/online-bot-client.ts                  # localhost:1999
 *   HOST=pvp.alshfu.com TLS=1 npx tsx tools/online-bot-client.ts
 *
 * Env:
 *   HOST     — host:port сервера (default localhost:1999)
 *   TLS      — 1 → wss:// (default ws://)
 *   NICK     — ник бота (default PilotBot)
 *   LEVEL    — easy|medium|hard (default medium)
 *   DELAY_MS — пауза «обдумывания» перед ходом (default 600)
 *   REMATCH  — 1 → соглашаться на ремач и играть дальше (default выход после матча)
 *   MAX_TURNS — сдаться на своём ходу после N общих ходов (default 400).
 *     Нужен, потому что два сильных бота играют практически бесконечно:
 *     тупик не наступает, а серверный blitz/forcePlace их не давит
 *     (отвечают быстрее таймера). resign — штатный конец матча.
 */
import WebSocket from "ws";
import {
  chooseBotMove,
  makeRng,
  type BotLevel,
} from "../legacy-ts/core";
import type {
  LobbyServer2Client,
  OnlineGameState,
  OnlineProfile,
  RoomServer2Client,
} from "../party/protocol";

const HOST = process.env.HOST ?? "localhost:1999";
const SCHEME = process.env.TLS === "1" ? "wss" : "ws";
const NICK = process.env.NICK ?? "PilotBot";
const LEVEL = (process.env.LEVEL ?? "medium") as BotLevel;
const DELAY_MS = Number(process.env.DELAY_MS ?? 600);
const REMATCH = process.env.REMATCH === "1";
const MAX_TURNS = Number(process.env.MAX_TURNS ?? 400);

const me: OnlineProfile = {
  id: `e2e-bot-${Math.random().toString(36).slice(2, 10)}`,
  nick: NICK,
  avatar: "🤖",
};
const rng = makeRng(Date.now() & 0xffff);

function log(msg: string): void {
  console.log(`[bot ${new Date().toISOString().slice(11, 19)}] ${msg}`);
}

// ─── Lobby: queue → matched ──────────────────────────────────────────────

function joinLobby(): void {
  const ws = new WebSocket(`${SCHEME}://${HOST}/parties/lobby/main`);
  ws.on("open", () => {
    log(`лобби открыто (${HOST}), профиль ${me.id} «${me.nick}», queue…`);
    ws.send(JSON.stringify({ type: "queue", profile: me }));
  });
  ws.on("message", (data) => {
    const msg = JSON.parse(String(data)) as LobbyServer2Client;
    if (msg.type === "queued") {
      log(`в очереди: позиция ${msg.position}, ждём ${msg.waitedSec}с`);
    } else if (msg.type === "bot_fallback") {
      log("сервер предложил bot_fallback (долгое ожидание) — встаю в очередь снова");
      ws.send(JSON.stringify({ type: "queue", profile: me }));
    } else if (msg.type === "matched") {
      log(`matched! room=${msg.roomId}, соперник «${msg.opponent.nick}» (${msg.opponent.id})`);
      ws.close();
      joinRoom(msg.roomId, msg.token);
    } else if (msg.type === "error") {
      log(`ошибка лобби: ${msg.reason}`);
    }
  });
  ws.on("error", (e) => {
    log(`лобби: ошибка соединения: ${String(e)}`);
    process.exit(1);
  });
}

// ─── Room: hello → play until over ───────────────────────────────────────

function joinRoom(roomId: string, token: string): void {
  const ws = new WebSocket(`${SCHEME}://${HOST}/parties/room/${roomId}`);
  let you: 0 | 1 = 0;
  /** Ключ последнего хода (matchId:turnCount) — защита от дабл-сенда. */
  let actedAt = "";

  function maybeMove(state: OnlineGameState): void {
    if (state.status !== "playing" || state.current !== you) return;
    const key = `${state.matchId}:${state.turnCount}`;
    if (actedAt === key) return;
    actedAt = key;
    setTimeout(() => {
      if (state.turnCount >= MAX_TURNS) {
        log(`достигнут MAX_TURNS=${MAX_TURNS} — сдаюсь (штатное завершение E2E)`);
        ws.send(JSON.stringify({ type: "resign" }));
        return;
      }
      const player = state.players[you];
      const move = chooseBotMove(state.board, player.hand, LEVEL, state.cfg, rng);
      if (!move) {
        log("ходов нет (ядро вернуло null) — жду forcePlace/конца от сервера");
        return;
      }
      ws.send(
        JSON.stringify({
          type: "move",
          pieceId: move.pieceId,
          cells: move.cells,
          r: move.r,
          c: move.c,
        }),
      );
      log(`ход #${state.turnCount}: ${move.pieceId} → (${move.r},${move.c})`);
    }, DELAY_MS);
  }

  ws.on("open", () => {
    log(`комната ${roomId}: hello…`);
    ws.send(JSON.stringify({ type: "hello", profile: me, token }));
  });
  ws.on("message", (data) => {
    const msg = JSON.parse(String(data)) as RoomServer2Client;
    switch (msg.type) {
      case "joined":
        you = msg.you;
        log(`joined: я игрок ${you}, статус ${msg.state.status}`);
        maybeMove(msg.state);
        break;
      case "state": {
        const s = msg.state;
        if (s.status === "over") {
          const res = s.result;
          const score = s.players.map((p) => p.score).join(":");
          log(`матч окончен: победитель=${res?.winner ?? "?"} (${res?.reason ?? ""}), счёт ${score}`);
          if (REMATCH) {
            log("REMATCH=1 → запрашиваю ремач");
            ws.send(JSON.stringify({ type: "rematch_request" }));
          } else {
            setTimeout(() => process.exit(0), 800);
          }
        } else {
          maybeMove(s);
        }
        break;
      }
      case "move_rejected":
        log(`move_rejected: ${msg.reason}`);
        break;
      case "opponent_left":
        log(`соперник отвалился (таймаут ${msg.willTimeoutMs}мс)`);
        break;
      case "opponent_reconnected":
        log("соперник вернулся");
        break;
      case "rematch_status":
        log(`ремач: мой=${msg.yours} их=${msg.theirs}`);
        break;
      case "error":
        log(`ошибка комнаты: ${msg.reason}`);
        break;
    }
  });
  ws.on("close", () => log("комната: соединение закрыто"));
  ws.on("error", (e) => log(`комната: ошибка: ${String(e)}`));
}

joinLobby();
