# Развёртывание PvP-сервера на VPS

Standalone Node.js + ws сервер живёт в `server/`. Один процесс держит:
- лобби с матчмейкингом
- комнаты-матчи (server-authoritative)
- глобальный ELO-лидерборд (persistent JSON)

URL-формат: `wss://host/parties/<party>/<room>`. С ним совместимы оба клиента —
и legacy TS (через `VITE_PARTY_HOST`), и Flutter (через `--dart-define=PARTY_HOST`).

> **Статус (2026-06-10).** Этот документ покрывает два контура:
> 1. **PvP-сервер** (`server/`, разделы 1–7 ниже) — живой прод, **не изменился**
>    миграцией. Сервер импортирует игровое ядро из `legacy-ts/core` (TS-ядро
>    осталось живым). Перезапуск/обновление — как описано.
> 2. **Frontend** — cut-over **выполнен 2026-06-10**: прод Pages отдаёт
>    **Flutter Web** (`npm run deploy:flutter`, см. «Frontend cut-over» ниже).
>    Legacy TS-путь (`npm run deploy`) сохранён как **откат**. §7 ниже описывает
>    подключение TS-клиента и актуален только для отката.

---

## Предположения

- VPS на Ubuntu/Debian (24.04 LTS подойдёт).
- У вас есть SSH-доступ по ключу (`administrator@alshfu.com`). **Если до сих пор пользуетесь паролем — смените на ключ прямо сейчас.**
- DNS `pvp.alshfu.com` указывает A-записью на IP VPS. Если ещё нет — пропишите в DNS-панели до начала.

Всё ниже — команды **на VPS**, после `ssh administrator@alshfu.com`.

---

## 1. Установить Node.js LTS

```bash
sudo apt update
sudo apt install -y curl git
# Node 20.x LTS (через NodeSource)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node -v   # должно показать v20.x
```

## 2. Положить проект

Вариант A — клонируем напрямую с GitHub (репо публичный):

```bash
sudo mkdir -p /opt/blockduel
sudo chown $USER:$USER /opt/blockduel
cd /opt/blockduel
git clone https://github.com/alshfu/block-puzzle-pvp.git app
cd app
npm ci --production=false
```

Вариант B — копируем по `scp` (если не хотите git pull). Это для апдейтов проще автоматизируется потом.

## 3. Запустить сервер вручную для проверки

```bash
cd /opt/blockduel/app
PORT=1999 npm run server:start
```

В другом терминале:
```bash
curl http://localhost:1999/healthz   # → ok
```

Если работает — Ctrl+C, переходим к systemd-сервису.

## 4. systemd-сервис для автозапуска

```bash
sudo tee /etc/systemd/system/blockduel-pvp.service > /dev/null <<'EOF'
[Unit]
Description=BlockDuel PvP backend (Node WS)
After=network-online.target

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=/opt/blockduel/app
Environment=PORT=1999
Environment=LEADERBOARD_FILE=/opt/blockduel/data/leaderboard.json
ExecStart=/usr/bin/npx tsx server/index.ts
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Замените YOUR_USER на $USER (вашего обычного пользователя — НЕ root)
sudo sed -i "s/YOUR_USER/$USER/" /etc/systemd/system/blockduel-pvp.service

sudo mkdir -p /opt/blockduel/data
sudo chown -R $USER:$USER /opt/blockduel/data

sudo systemctl daemon-reload
sudo systemctl enable --now blockduel-pvp
sudo systemctl status blockduel-pvp     # должен быть active (running)
```

Логи:
```bash
sudo journalctl -u blockduel-pvp -f
```

## 5. nginx как reverse proxy + WebSocket upgrade

```bash
sudo apt install -y nginx
sudo tee /etc/nginx/sites-available/pvp.alshfu.com > /dev/null <<'EOF'
server {
    listen 80;
    server_name pvp.alshfu.com;

    location / {
        proxy_pass http://127.0.0.1:1999;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        # критично для WebSocket:
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/pvp.alshfu.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

Проверка по HTTP:
```bash
curl http://pvp.alshfu.com/healthz   # → ok
```

## 6. SSL через Let's Encrypt (бесплатно, обязательно для wss://)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d pvp.alshfu.com --non-interactive --agree-tos -m you@example.com
# certbot сам отредактирует nginx-конфиг и добавит 443+ssl, плюс настроит автообновление
```

Проверка по HTTPS:
```bash
curl https://pvp.alshfu.com/healthz   # → ok
```

## 7. Подключить клиент к новому серверу

> Ниже — **legacy TS-путь** (`npm run deploy`), актуальный пока прод на TS.
> Для Flutter-клиента хост вшивается при сборке (`--dart-define=PARTY_HOST`,
> см. раздел «Frontend cut-over»), `.env.local`/`VITE_PARTY_HOST` ему не нужны.

На вашей **локальной машине** (где делаете `npm run deploy`):

```bash
cd /Users/al_sh/WebstormProjects/block_puzzle_pvp
echo 'VITE_PARTY_HOST=pvp.alshfu.com' > .env.local
npm run deploy
```

`.env.local` не коммитится — это секрет, остаётся только у вас.

После деплоя на GitHub Pages онлайн на https://alshfu.github.io/block-puzzle-pvp/ начнёт подключаться к **вашему** серверу на `wss://pvp.alshfu.com/parties/...`.

---

## Обновления сервера потом

Когда я внесу изменения и запушу в `main`, на VPS:

```bash
cd /opt/blockduel/app
git pull
npm ci --production=false
sudo systemctl restart blockduel-pvp
```

## Бэкап лидерборда

ELO хранится в `/opt/blockduel/data/leaderboard.json`. Бэкап:

```bash
# одноразово
cp /opt/blockduel/data/leaderboard.json /opt/blockduel/data/leaderboard.bak.$(date +%F).json

# или в cron:
echo '15 4 * * * cp /opt/blockduel/data/leaderboard.json /opt/blockduel/data/leaderboard.bak.$(date +\%F).json' | crontab -
```

## Файрволл

Откройте только 80 + 443 на VPS:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

Порт 1999 закрыт для внешнего мира — nginx проксирует только локально.

---

## Если что-то сломалось

| Симптом | Что смотреть |
|---|---|
| `systemctl status blockduel-pvp` → failed | `journalctl -u blockduel-pvp -n 100` |
| curl /healthz возвращает 502 | сервис упал, см. journal |
| WebSocket не подключается с сайта | в браузере DevTools → Network → WS → смотрите код, чаще всего CORS/SSL |
| Высокий CPU | один процесс, ws connections не лимитируются — добавить `pm2`/cluster если надо |

В случае непонятной ошибки — пришлите вывод `journalctl -u blockduel-pvp -n 200` мне в чат, я разберу.

---

# Frontend cut-over (Фаза 8): TS/React → Flutter Web

Прод-фронт переключается с TS/React (Vite → `dist/`) на Flutter Web. Оба
публикуются на GitHub Pages в ветку `gh-pages`; различается только источник
сборки. Сервер PvP не трогаем — Flutter-клиент говорит с ним по тому же
WS-протоколу.

## Подготовка (уже в репо)

- Версия Flutter-приложения: `2.0.0+1` (major bump).
- Прод-хост и TLS вшиваются при сборке: `--dart-define=PARTY_HOST=pvp.alshfu.com
  --dart-define=PARTY_TLS=true`.
- `--base-href /block-puzzle-pvp/` (тот же путь, что у TS-версии на Pages).
- Роутинг Flutter-web — hash (`/#/...`), поэтому deep-link и F5 работают на
  Pages без `404.html`.
- One-shot миграция: при первом запуске Flutter-web автоматически переносит
  локальный прогресс старой TS-версии из `localStorage` (`storage/ts_import.dart`).

## Go-live

### Автодеплой через GitHub Actions (основной путь с 2026-06-10)

Каждый push в `main` запускает `.github/workflows/deploy.yml`:
`flutter analyze` → `flutter test` → `flutter build web` (те же prod-флаги,
что в `build:flutter`) → публикация `build/web` в ветку `gh-pages`.
Через ~30–60 c обновится https://alshfu.github.io/block-puzzle-pvp/.

- Правки только доков (`**.md`), `legacy*/`, `server/`, `party/`, `tests/`,
  `tools/`, `qa/` деплой **не** триггерят (`paths-ignore`).
- Запуск вручную: вкладка Actions → «Deploy to GitHub Pages» → Run workflow,
  либо `gh workflow run deploy.yml`.
- Красные analyze/test останавливают деплой — прод не получит сломанную сборку.
- Actions бесплатны: репозиторий публичный.

### Ручной деплой (запасной путь)

```bash
npm test                 # TS (Vitest) — зелёные
flutter test                     # Flutter — зелёные
npm run deploy:flutter   # build web (prod-флаги) + .nojekyll + gh-pages
```

`deploy:flutter` собирает `build/web` и публикует в `gh-pages` — тот же
механизм «deploy from branch», что и у Actions, конфликтов нет.

## Проверка после go-live

Открыть https://alshfu.github.io/block-puzzle-pvp/ и проверить:
- офлайн-игра (vs Bot / hot-seat / аркада), звук, темы;
- онлайн: матчмейкинг → матч → лидерборд (нужен запущенный сервер);
- Google вход + синк (Firebase);
- deep-link: `…/block-puzzle-pvp/#/stats`, `#/shop` открываются и переживают F5;
- консоль без критических ошибок; перенос локального профиля сработал.

## Post-cutover (на VPS, когда уверены, что старых TS-вкладок больше нет — ~1–2 дня)

Теперь прод обслуживает только Flutter-клиент (шлёт `roomToken`, Origin =
`https://alshfu.github.io`). Можно включить жёсткие проверки в systemd unit:

```ini
Environment=REQUIRE_ROOM_TOKEN=1
Environment=ALLOWED_ORIGINS=https://alshfu.github.io
```

```bash
sudo systemctl daemon-reload && sudo systemctl restart blockduel-pvp
```

> ⚠️ Не включать `REQUIRE_ROOM_TOKEN=1` ДО того, как старые TS-клиенты (которые
> не шлют токен) перестанут подключаться — иначе их `hello` отклонится. Нативные
> клиенты (iOS/Android/desktop) Origin не шлют — `ALLOWED_ORIGINS` их не блокирует.

## Откат (мгновенный)

```bash
npm run deploy           # пере-публикует TS-сборку (dist/) в gh-pages
```

Если уже включали `REQUIRE_ROOM_TOKEN=1` — снять его и перезапустить сервер
(старый TS-клиент токен не шлёт).

## Дальше (отдельной задачей)

Реструктуризация репо ВЫПОЛНЕНА (2026-06-09): `flutter/` → корень, `src/` →
`legacy-ts/`. Сервер импортирует ядро из `legacy-ts/core`.
