/**
 * BlockDuel stream relay — браузер → ffmpeg → YouTube Live (RTMP).
 *
 * Зачем: браузер не умеет пушить RTMP (только так YouTube принимает эфир).
 * Этот релей принимает по WebSocket поток WebM-чанков от клиента (Авто-шоу
 * захватывает вкладку через MediaRecorder) и через ffmpeg транскодирует его в
 * H.264/AAC и пушит на ингест YouTube. Ключ трансляции (Stream key) клиент
 * присылает первым сообщением — OAuth не нужен (ключ берётся в YouTube Studio →
 * «Трансляции» → «Ключ трансляции»).
 *
 * Протокол:
 *   1) первый текстовый фрейм: JSON `{ "type":"start", "streamKey":"xxxx-xxxx-..." }`
 *   2) далее — бинарные фреймы с WebM-чанками (из MediaRecorder timeslice)
 *   3) закрытие сокета → конец stdin ffmpeg → завершение эфира
 *
 * Требования на сервере (VPS): установленный ffmpeg (`apt install ffmpeg`).
 * Запуск: `npx tsx server/stream-relay.ts` (порт STREAM_PORT, по умолч. 2000).
 * Переменные окружения:
 *   STREAM_PORT      — порт WS (по умолчанию 2000)
 *   RTMP_BASE        — база ингеста (по умолч. rtmp://a.rtmp.youtube.com/live2)
 *   ALLOWED_ORIGINS  — CSV допустимых Origin (пусто → все)
 *
 * ⚠️ Деплой и проверку реального эфира делает пользователь на VPS — здесь
 * только код релея (на VPS он сейчас не развёрнут).
 */
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createServer, type IncomingMessage } from "node:http";
import { WebSocketServer, type WebSocket } from "ws";

const STREAM_PORT = parseInt(process.env.STREAM_PORT ?? "2000", 10);
const RTMP_BASE =
  process.env.RTMP_BASE ?? "rtmp://a.rtmp.youtube.com/live2";
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

/** Допустимый формат ключа трансляции YouTube (буквы/цифры/дефис, 8..60). */
const STREAM_KEY_RE = /^[A-Za-z0-9-]{8,60}$/;

/** Старт-сообщение клиента. */
interface StartMessage {
  type: "start";
  streamKey: string;
}

/** Строит команду ffmpeg: WebM(pipe) + тихая аудиодорожка → FLV/RTMP. */
function ffmpegArgs(rtmpUrl: string): string[] {
  return [
    "-hide_banner",
    "-loglevel",
    "warning",
    // Вход 1 — WebM-поток из stdin.
    "-i",
    "pipe:0",
    // Вход 2 — тишина (YouTube требует аудиодорожку в эфире).
    "-f",
    "lavfi",
    "-i",
    "anullsrc=channel_layout=stereo:sample_rate=44100",
    // Видео H.264 для RTMP.
    "-c:v",
    "libx264",
    "-preset",
    "veryfast",
    "-pix_fmt",
    "yuv420p",
    "-b:v",
    "4500k",
    "-maxrate",
    "4500k",
    "-bufsize",
    "9000k",
    "-g",
    "60",
    // Аудио AAC.
    "-c:a",
    "aac",
    "-b:a",
    "128k",
    "-ar",
    "44100",
    "-shortest",
    "-f",
    "flv",
    rtmpUrl,
  ];
}

/** Сессия одного эфира: ffmpeg-процесс на время жизни сокета. */
class StreamSession {
  private ffmpeg: ChildProcessWithoutNullStreams | null = null;
  private started = false;

  constructor(private readonly ws: WebSocket) {}

  /** Обрабатывает первый текстовый фрейм (старт) и запускает ffmpeg. */
  handleStart(raw: string): void {
    if (this.started) return;
    let msg: StartMessage;
    try {
      msg = JSON.parse(raw) as StartMessage;
    } catch {
      this.fail("bad start message");
      return;
    }
    if (msg.type !== "start" || !STREAM_KEY_RE.test(msg.streamKey ?? "")) {
      this.fail("invalid stream key");
      return;
    }
    const rtmpUrl = `${RTMP_BASE}/${msg.streamKey}`;
    const ff = spawn("ffmpeg", ffmpegArgs(rtmpUrl));
    ff.on("error", (e) => this.fail(`ffmpeg spawn failed: ${e.message}`));
    // EPIPE и прочие ошибки stdin (ffmpeg умер между write и событием close) —
    // ловим, иначе unhandled 'error' на потоке уронил бы весь процесс релея.
    ff.stdin.on("error", (e) => this.fail(`ffmpeg stdin error: ${e.message}`));
    // Backpressure: если stdin переполнен — приостанавливаем приём чанков.
    ff.stdin.on("drain", () => { try { this.ws.resume(); } catch { /* ignore */ } });
    ff.stderr.on("data", (d) => process.stderr.write(`[ffmpeg] ${d}`));
    ff.on("close", (code) => {
      this.send({ type: "ended", code });
      this.close();
    });
    this.ffmpeg = ff;
    this.started = true;
    this.send({ type: "live" });
  }

  /** Пишет бинарный WebM-чанк в stdin ffmpeg (с учётом backpressure). */
  handleChunk(data: Buffer): void {
    if (!this.ffmpeg || this.ffmpeg.stdin.destroyed) return;
    // write() вернёт false при переполнении буфера — тогда приостанавливаем
    // приём из сокета до события 'drain', чтобы память не росла безгранично.
    const ok = this.ffmpeg.stdin.write(data);
    if (!ok) {
      try { this.ws.pause(); } catch { /* ignore */ }
    }
  }

  /** Завершает stdin (конец эфира). */
  end(): void {
    if (this.ffmpeg && !this.ffmpeg.stdin.destroyed) {
      this.ffmpeg.stdin.end();
    }
  }

  private fail(reason: string): void {
    this.send({ type: "error", reason });
    this.close();
  }

  private send(obj: unknown): void {
    if (this.ws.readyState === this.ws.OPEN) {
      this.ws.send(JSON.stringify(obj));
    }
  }

  private close(): void {
    try {
      this.ffmpeg?.kill("SIGKILL");
    } catch {
      // already gone
    }
    this.ffmpeg = null;
    if (this.ws.readyState === this.ws.OPEN) this.ws.close();
  }
}

const server = createServer();
// maxPayload ограничивает размер одного бинарного фрейма (анти-DoS по памяти).
const wss = new WebSocketServer({ noServer: true, maxPayload: 4 * 1024 * 1024 });

// Last-line defense: кривой ввод/промис не должен ронять процесс релея целиком.
process.on("uncaughtException", (err) => console.error("[relay] uncaughtException:", err));
process.on("unhandledRejection", (err) => console.error("[relay] unhandledRejection:", err));

server.on("upgrade", (req: IncomingMessage, socket, head) => {
  const origin = req.headers.origin;
  if (
    ALLOWED_ORIGINS.length > 0 &&
    origin !== undefined &&
    !ALLOWED_ORIGINS.includes(origin)
  ) {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws, req));
});

wss.on("connection", (ws: WebSocket) => {
  const session = new StreamSession(ws);
  ws.on("message", (data: Buffer, isBinary: boolean) => {
    if (isBinary) {
      session.handleChunk(data);
    } else {
      session.handleStart(data.toString("utf8"));
    }
  });
  ws.on("close", () => session.end());
  ws.on("error", () => session.end());
});

server.listen(STREAM_PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`[stream-relay] WS on :${STREAM_PORT} → ${RTMP_BASE}/<key>`);
});
