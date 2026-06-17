# Онлайн-трансляция Авто-шоу на YouTube Live

Режим **«📺 Авто-шоу»** (`/showcase`) умеет выходить в прямой эфир на YouTube.
Браузер не может пушить RTMP напрямую, поэтому используется **релей**, который
запускается **на вашей локальной машине** (VPS не нужен):

```
Браузер (Авто-шоу 9:16)            ваша машина                    YouTube
  getDisplayMedia → MediaRecorder ─ ws ─► stream-relay.ts ─ ffmpeg ─ RTMP ─► Live
  (WebM-чанки раз в секунду)              (npm run stream:relay)     (live2/<key>)
```

OAuth **не нужен** — используется «Ключ трансляции» из YouTube Studio.

## Локальный эфир — быстрый старт

### 1. Установить ffmpeg (один раз)

```bash
# macOS
brew install ffmpeg
# Ubuntu/Debian
sudo apt-get install -y ffmpeg
```

### 2. Запустить релей на своей машине

```bash
cd block_puzzle_pvp
npm run stream:relay      # WS на ws://localhost:2000
```

### 3. Получить ключ трансляции YouTube

YouTube Studio → **Трансляции** (Go Live) → **Потоковая передача** →
скопировать **«Ключ трансляции»** (вида `xxxx-xxxx-xxxx-xxxx`).

### 4. Выйти в эфир

1. Открыть Авто-шоу в Chrome на том же компьютере:
   - прод: `https://alshfu.github.io/block-puzzle-pvp/#/showcase`
     (браузер разрешает `ws://localhost` даже с https-страницы), **или**
   - локально: `flutter run -d chrome` → `/#/showcase`.
2. Нажать **«🎥 В эфир»** → ключ трансляции уже с `ws://localhost:2000` в поле
   релея → **«В эфир»**.
3. Выбрать вкладку с Авто-шоу для захвата (запрос браузера).
4. Через ~10–20 c в YouTube Studio появится сигнал — публикуйте эфир.
   Кнопка станет **«⏹ Стоп · завершить эфир»**.

> Если эфир не стартует — смотрите вывод `npm run stream:relay` (там логи
> ffmpeg). Часто причина: неверный ключ или не установлен ffmpeg.

## Без сервера — запись клипа

В диалоге эфира есть **«Только клип»**: запишет вертикальный WebM, который можно
вручную залить как YouTube Shorts. Релей при этом не нужен.

## Переменные окружения релея

- `STREAM_PORT` — порт WS (по умолчанию `2000`).
- `RTMP_BASE` — база ингеста (по умолчанию `rtmp://a.rtmp.youtube.com/live2`).
- `ALLOWED_ORIGINS` — CSV допустимых Origin (пусто → все; для локального не нужно).

## Удалённый релей (опционально, на будущее)

Если захотите вынести релей на VPS — поднять `npm run stream:relay`, проксировать
через nginx с TLS на путь `/stream` и указать `wss://host/stream` в поле релея:

```nginx
location /stream {
    proxy_pass http://127.0.0.1:2000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}
```

Сборка клиента с другим дефолтным релеем:
`flutter build web --release --dart-define=STREAM_RELAY=wss://host/stream`.

## TODO / ограничения

- Без аудио-захвата релей добавляет тихую дорожку (YouTube требует аудио).
- Автоматизация (создание трансляции, заголовок, превью) — через YouTube Live
  API + OAuth — отдельная надстройка поверх релея.
- Битрейт/кодеки заданы в `ffmpegArgs` (H.264 ~4500 kbps, AAC).
