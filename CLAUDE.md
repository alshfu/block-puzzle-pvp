# BlockDuel 9×9

Соревновательный блок-пазл: два игрока по очереди ставят тетромино (I, O, T, S, Z, J, L) на общую доску 9×9. Заполненная строка / столбец / бокс 3×3 очищается, очки достаются игроку, чей ход вызвал очистку. Партия идёт до тупика; blitz-таймер + force-place гарантируют сходимость.

Полная спецификация: `TZ_BlockDuel_9x9.md` (RU, v1.0) — **источник истины** по правилам, балансу и фазам.

**Принято решение (2026-06-05):** проект мигрирует на **Dart + Flutter (+ Flame)** под все платформы. План — `MIGRATION_FLUTTER.md`. IDE — **IntelliJ IDEA Ultimate 2026.1.3**.

> ⚠️ **РЕСТРУКТУРИЗАЦИЯ РЕПО ВЫПОЛНЕНА (2026-06-09).** Flutter-проект теперь в
> **корне** репозитория (`lib/`, `test/`, `web/`, `pubspec.yaml`, `android/`,
> `ios/`, `macos/`, `integration_test/`, `assets/`). Старый TS/React-фронт
> перенесён в **`legacy-ts/`** (был `src/`) и считается legacy. Многие пути в
> разделах ниже (`src/core`, `flutter/lib/...`) **устарели** — читать как
> `legacy-ts/core` и `lib/...` соответственно.
>
> Важно: **Node-сервер `server/` (живой прод-бэкенд) импортирует ядро из
> `legacy-ts/core`** — TS-ядро остаётся живым как зависимость сервера, даже хотя
> React-UI ретайрнут. Flutter-команды (`flutter test/analyze/build`) и
> `npm run build:flutter`/`deploy:flutter` запускаются **из корня**.
> Cut-over прода (Pages: TS→Flutter) — см. `DEPLOY.md`, раздел «Frontend cut-over».

**Если ты новый AI-ассистент в этом проекте — прочитай `HANDOFF.md` перед началом работы.** Там карта проекта, хронология решений, правила работы, IDE setup.

## Текущий статус

Фазы 1–4 ТЗ реализованы: ядро, UI, vs Bot (3 уровня), Hot-seat, онлайн PvP, прогрессия, магазин, ачивки. Продакшн-сборка живёт на GitHub Pages, онлайн-сервер — на VPS.

### Слои и ключевые файлы

- **Ядро** (`src/core/index.ts`) — pure-TS: типы, PRNG `mulberry32`, 7-bag, доска, очистка, очки, перебор ходов, бот 3 уровней с `BOT_WEIGHTS`, дешёвый `opponentThreatGain` (missing=1), blitz-таймер (`turnTimeForRound`), `forcePlace`. **Единственный** источник правды по логике игры; импортируется и клиентом, и сервером.
- **Entry** — `src/main.tsx` + `src/ui/App.tsx` (роутинг экранов).
- **Главный хук** — `src/ui/useGame.ts` (useReducer + Bag/rng в refs, бот через setTimeout, blitz tick 100мс).
- **Экраны** (`src/ui/screens/`) — Menu, Setup, Game, Profile, Settings, Tutorial, Daily, Shop, Achievements, Leaderboard, OnlineMenu, OnlineGame, ResultOverlay.
- **Компоненты** (`src/ui/components/`) — Board, Hand, Scoreboard, PlayerCard, TurnTimer, TransformControls, Confetti, ComboFlash, ToastStack, PowerupsPanel, PauseOverlay, DragLayer, маскоты/декор (CartoonPony, Mascot, FloatingTheme, ThemeBackdrop, ThemeSwitch) и пр.
- **Темы** (`src/ui/themes.ts` + `styles.css`) — `neutral`, `candy`, `night`. CSS-переменные на `.app-root`.
- **Звук** — `src/ui/audio.ts` (синтез Web Audio) + `src/ui/music.ts` (фоновые темы).
- **Онлайн PvP** — `src/ui/online/{client.ts,useOnlineGame.ts}` (PartySocket-совместимый WS) ↔ `server/{index.ts,lobby.ts,room.ts,leaderboard.ts}` (Node WS на VPS, server-authoritative, ELO K=24).
- **Auth + sync** — `src/ui/auth/{auth.ts,firebase.ts,sync.ts}` (Google sign-in через Firebase + Firestore cross-device).
- **Магазин** — `src/ui/shop/{powerups.ts,skins.ts}` (валюта = кристаллы, без реальных платежей).
- **Ачивки** — `src/ui/achievements/{definitions.ts,engine.ts}` (~120: 15 базовых + 105 PvP).
- **Сохранение** — `src/ui/storage/*` (profile, stats, settings, saveGame с drawCounts для детерминистичного resume 7-bag).
- **Tests** — `tests/` Vitest, 7 файлов, **46 тестов**: clears, scoring, 7-bag, deadlock+forcePlace, бот (validity + timing + BOT_WEIGHTS), детерминизм (golden), таймер.
- **Tools** — `tools/bot-sim.ts` для калибровки бота.
- **PartyKit-вариант** — `party/*.ts` + `partykit.json` сохранены как опция, не задействованы (онлайн крутится на собственном VPS).
- **Legacy** — `legacy/blockduel-demo.html` и `legacy/blockduel-jsx-prototype/` инертный референс по визуалу. **Не подключены к сборке.** См. `legacy/README.md`.
- **Конфиги** — `vite.config.ts`, `vitest.config.ts`, `tsconfig.{app,node}.json`.

## Команды

```bash
npm run dev          # Vite dev server на http://localhost:5173
npm run build        # tsc -b && vite build → dist/
npm test             # Vitest (one-shot, 46 тестов)
npm run test:watch   # Vitest watch
npm run typecheck    # tsc -b --noEmit
npm run deploy       # build + gh-pages → Pages обновится ~30 сек
npm run server:dev   # локальный WS-сервер (PORT=1999)
npm run server:start # то же, для прода
npm run party:dev    # PartyKit-вариант (опционально, не используется)
npx tsx tools/bot-sim.ts --games 1000   # симулятор калибровки бота
```

## Архитектура

Жёсткое разделение слоёв (ТЗ § 6.1):

```
Презентация (UI, ввод, анимации)              ← src/ui/
    ↓
Игровое ядро (pure, детерминированное)         ← src/core/
    ↑
Сетевой слой (server-authoritative онлайн)     ← server/  (импортирует src/core)
```

**Ядро (`src/core/`) обязано оставаться pure и детерминированным:**
- никаких `Math.random()` — только переданный `rng: () => number` от `makeRng(seed)`;
- никакого `Date.now()`, `fetch`, `localStorage`, DOM, импортов UI-фреймворков;
- одинаковый `(matchSeed, RuleConfig, moveLog)` → одинаковое состояние (нужно для реплеев, server-authoritative онлайна, golden-тестов, анти-чита).

Презентационный код (drag-and-drop, анимации, звук, тикание таймера) — только в `src/ui/`. Серверный авторитет (таймер, anti-cheat ориентаций, ELO) — в `server/`, но игровая механика — через импорт из `src/core/`, не дублировать.

## Деплой

- **Frontend** — GitHub Pages, ветка `gh-pages`. После значимых изменений: `npm test && npm run deploy`. Actions workflow выключен (`.github/workflows/deploy.yml.disabled`) — биллинг.
- **Backend (PvP)** — VPS `pvp.alshfu.com`, Ubuntu 24.04, systemd unit `blockduel-pvp.service`, nginx + Let's Encrypt. Клиент указывает на сервер через `VITE_PARTY_HOST` в `.env.local` (gitignored). После правок `server/*.ts` нужен `git pull && systemctl restart blockduel-pvp` на VPS (делает пользователь).
- Подробности — в `DEPLOY.md`.

## Конвенции

- Идентификаторы и комментарии в коде — английский (`BoardCell`, `enumerateMoves`, `RuleConfig`).
- Документация и общение с пользователем — русский; технические термины можно оставлять английскими.
- Дефолты конфига зафиксированы в `DEFAULT_CONFIG` (`src/core/index.ts`) и в ТЗ § 15 — должны совпадать.
- Формула очков: `base = N*(N+1)/2`, `mult = 1 + 0.1·min(combo, comboCap)`, `+15` за perfect clear.
- 7-bag: у каждого игрока свой мешок (`sharedBag = false`).
- Blitz: `turnTimeStart=12`, `turnTimeDecay=0.4`, `turnTimeMin=3`, `onTimeout="forcePlace"`.

## Стек

ТЗ рекомендует **Flutter + Flame** как целевой стек. Текущая реализация — **TypeScript + React + Vite + Vitest** (фронт), **Node + ws + tsx** (сервер), **Firebase Auth + Firestore** (sync). Не предлагай миграцию на Flutter без явного запроса.

## Чего НЕ делать самостоятельно

- Не дублировать игровую логику в `src/ui/` или `server/` — всё через импорт из `src/core/`.
- Не править файлы в `legacy/` — они инертные.
- Не отходить от ТЗ по правилам/балансу без явного запроса.
- Не возвращать `.github/workflows/deploy.yml.disabled` обратно в `deploy.yml` без подтверждения, что биллинг разблокирован.
- Не пушить с красными тестами — Pages закэширует сломанный сайт.
- Не трогать `/etc/nginx/sites-enabled/alshfu-arena.conf` на VPS (это сторонний сайт пользователя).
