# Онлайн-трансляция Авто-шоу на YouTube Live

Режим **«📺 Авто-шоу»** (`/showcase`) умеет выходить в прямой эфир на YouTube.
Браузер не может пушить RTMP напрямую, поэтому используется серверный **релей**:

```
Браузер (Авто-шоу 9:16)               VPS                         YouTube
  getDisplayMedia → MediaRecorder  ─ WS ─►  stream-relay.ts ─ ffmpeg ─ RTMP ─►  Live
  (WebM-чанки раз в секунду)               (server/stream-relay.ts)     (live2/<key>)
```

OAuth **не нужен** — используется «Ключ трансляции» из YouTube Studio.

## 1. Развернуть релей на сервере (один раз)

На VPS (там же, где `pvp.alshfu.com`):

```bash
sudo apt-get install -y ffmpeg        # релею нужен ffmpeg
cd /path/to/block_puzzle_pvp
npm run stream:relay                  # поднимает WS на :2000 (STREAM_PORT)
```

Переменные окружения:
- `STREAM_PORT` — порт WS релея (по умолчанию `2000`).
- `RTMP_BASE` — база ингеста (по умолчанию `rtmp://a.rtmp.youtube.com/live2`).
- `ALLOWED_ORIGINS` — CSV допустимых Origin (например `https://alshfu.github.io`).

Для прод-доступа из браузера по `wss://` проксируйте релей через nginx с TLS,
например на путь `/stream`:

```nginx
location /stream {
    proxy_pass http://127.0.0.1:2000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}
```

Тогда адрес релея для клиента: `wss://pvp.alshfu.com/stream`.
(systemd-юнит по аналогии с `blockduel-pvp.service` — отдельно.)

## 2. Получить ключ трансляции YouTube

YouTube Studio → **Трансляции** (Go Live) → **Потоковая передача** →
скопировать **«Ключ трансляции»** (вида `xxxx-xxxx-xxxx-xxxx`).

## 3. Выйти в эфир

1. Открыть Авто-шоу на десктопе в Chrome: `/#/showcase`.
2. Нажать **«🎥 В эфир»** → вставить ключ трансляции и адрес релея → **«В эфир»**.
3. Выбрать вкладку с Авто-шоу для захвата (запрос браузера).
4. Релей запустит ffmpeg → через ~10–20 c в YouTube Studio появится сигнал и
   эфир можно публиковать. Кнопка станет **«⏹ Стоп · завершить эфир»**.

## Сборка клиента с дефолтным адресом релея

```bash
flutter build web --release --dart-define=STREAM_RELAY=wss://pvp.alshfu.com/stream
```

(Адрес также редактируется в диалоге эфира.)

## Ограничения / TODO

- **Требуется поднятый VPS + ffmpeg + развёрнутый релей.** Сейчас VPS
  чинится — до этого работает только запись клипа («Только клип» в диалоге →
  скачивается вертикальный WebM для ручной загрузки как Shorts).
- Без аудио-захвата релей добавляет тихую дорожку (YouTube требует аудио).
- Опциональная автоматизация (создание трансляции, заголовок, превью) — через
  **YouTube Live API + OAuth** — отдельная задача поверх релея.
- Битрейт/разрешение зафиксированы в `ffmpegArgs` (4500 kbps, 720/1080).
