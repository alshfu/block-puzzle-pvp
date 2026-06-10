# BlockDuel 9×9

Соревновательный блок-пазл: два игрока по очереди ставят тетромино (I, O, T, S, Z, J, L) на общую доску 9×9. Заполненная строка / столбец / бокс 3×3 очищается, очки достаются игроку, чей ход вызвал очистку. Партия идёт до тупика; blitz-таймер + force-place гарантируют сходимость.

Полная спецификация: `TZ_BlockDuel_9x9.md` (RU, v1.0) — **источник истины** по правилам, балансу и фазам.

**Если ты новый AI-ассистент в этом проекте — прочитай `HANDOFF.md` перед началом работы.** Там карта проекта, хронология решений, правила работы, IDE setup.

## Текущий статус

- **Основное приложение — Dart + Flutter** (миграция с TS/React завершена, фазы 0–8 в `MIGRATION_FLUTTER.md` закрыты). Flutter-проект живёт в **корне** репозитория (`lib/`, `test/`, `web/`, `pubspec.yaml`, `android/`, `ios/`, `macos/`, `integration_test/`, `assets/`). Версия `2.0.0+1`, Flutter 3.44 / Riverpod 3.3 / Flame 1.37. IDE — **IntelliJ IDEA Ultimate**.
- **Прод переключён на Flutter Web (cut-over 2026-06-10):** GitHub Pages отдаёт сборку `npm run deploy:flutter`. Откат на TS-сборку — `npm run deploy` (см. `DEPLOY.md`).
- **Старый TS/React-фронт** — в `legacy-ts/` (бывший `src/`), ретайрнут как UI, **но `legacy-ts/core` остаётся живой зависимостью Node-сервера** `server/` (прод-бэкенд PvP на VPS).
- Фазы 1–4 ТЗ реализованы: ядро, UI, vs Bot (3 уровня), Hot-seat, онлайн PvP, прогрессия, магазин, ~120 ачивок. В работе — macOS-сборка (auth ждёт значений из Firebase Console, см. `MACOS_AUTH_SETUP.md`); релиз v2.0.0 отложен.

### Слои и ключевые файлы (Flutter, актуально)

- **Ядро** (`lib/core/`) — pure Dart, порт TS-ядра бит-в-бит: `rng.dart` (mulberry32), `bag.dart` (7-bag), `pieces.dart`, `board.dart` (постановка/очистки), `scoring.dart`, `moves.dart` (перебор ходов), `bot.dart` (3 уровня, `botWeights`), `timer.dart` (blitz `turnTimeForRound`), `types.dart` (включая `RuleConfig`/`defaultConfig`), фасад `core.dart`. **Единственный** источник правды по игровой логике на Dart-стороне.
- **Entry** — `lib/main.dart` + `lib/app.dart`; роутинг — `lib/ui/router.dart`.
- **ViewModel-слой (Riverpod-нотифайеры, без `BuildContext`)** — `lib/game/game_notifier.dart` (офлайн-матч: бот, blitz tick, save/resume), `lib/online/online_game_notifier.dart` (онлайн-матч, reconnect), контроллеры в `lib/{achievements,audio,auth,daily,profile,settings,shop,tutorial}/`.
- **View-слой** (`lib/ui/`) — `screens/` (Menu, Setup, Game, Profile, Settings, Tutorial, Daily, Shop, Achievements, Leaderboard, OnlineMenu, OnlineGame, Stats…), `widgets/` (BoardView, HandView, TurnTimer, MiniPiece…), `decor/` (маскоты, конфетти, ComboFlash), `theme/` + `design_tokens.dart` (темы `neutral`, `candy`, `night`), `responsive.dart`.
- **Звук** — `lib/audio/` (синтез, фоновые темы; порт Web Audio-подхода).
- **Онлайн PvP** — `lib/online/` (wire-протокол, маппинг в GameState) ↔ `server/{index.ts,lobby.ts,room.ts,leaderboard.ts,limits.ts}` (Node WS на VPS, server-authoritative, ELO K=24, **импортирует `legacy-ts/core`**).
- **Auth + sync** — `lib/auth/` + `lib/firebase_options.dart` (Google sign-in через Firebase, проект `blockduel-web`, Firestore cross-device sync; правила — `firestore.rules`).
- **Хранилище** — `lib/storage/` (profile, stats, settings, saveGame; детерминистичный resume 7-bag).
- **Tests** — `test/` — **176 тестов** в 32 файлах (core, game, online, achievements, audio, decor, pilot…), включая golden-тесты детерминизма **бит-в-бит с TS-ядром** (`test/golden/determinism_golden_test.dart`, `test/core/rng_golden_test.dart`). Плюс `integration_test/`.
- **Legacy-TS тесты** — `tests/` Vitest, 8 файлов, **55 тестов** (покрывают `legacy-ts/core` + серверную логику; гоняются `npm test`).
- **Tools** — `tools/bot-sim.ts` (калибровка бота, по TS-ядру), `tools/gen_test_plan.py` (QA-планы в `qa/`), `tools/pentest_local.mjs`.
- **PartyKit-вариант** — `party/*.ts` + `partykit.json` сохранены как инертная опция, не задействованы (онлайн крутится на собственном VPS). Пакет `partykit` удалён из зависимостей (тянул уязвимый undici); для реанимации варианта — `npm i -D partykit` и вернуть скрипты `party:dev`/`party:deploy`.
- **Legacy** — `legacy/blockduel-demo.html` и `legacy/blockduel-jsx-prototype/` — инертный визуальный референс, не в сборке (`legacy/README.md`); `legacy-ts/` — бывший фронт, см. выше.
- **Конфиги** — `pubspec.yaml`, `analysis_options.yaml`, `firebase.json`; TS-обвязка: `vite.config.ts`, `vitest.config.ts`, `tsconfig.{app,node}.json`.

## Команды

```bash
# Flutter (основное приложение) — из корня
flutter run -d chrome          # dev-запуск Web
flutter test                   # 176 тестов
flutter analyze                # статический анализ
npm run build:flutter          # release-сборка Web (PARTY_HOST=pvp.alshfu.com)
npm run deploy:flutter         # build + gh-pages → прод Pages (~30 сек)
npm run build:macos            # release-сборка macOS
npm run run:macos:prod         # flutter run -d macos с прод PARTY_HOST
npm run deploy:rules           # firebase deploy --only firestore:rules

# Legacy-TS ядро + сервер
npm test                       # Vitest (one-shot, 55 тестов: ядро + сервер)
npm run typecheck              # tsc -b --noEmit
npm run server:dev             # локальный WS-сервер (PORT=1999)
npm run server:start           # то же, для прода (systemd на VPS)
npm run dev / build / deploy   # старый TS-фронт (только как откат прода)
npx tsx tools/bot-sim.ts --games 1000   # симулятор калибровки бота
```

## Архитектура

Жёсткое разделение слоёв (ТЗ § 6.1) + **MVVM** на Flutter-стороне:

```
View (lib/ui/ — widgets, без логики)
    ↓ props / callbacks
ViewModel (Riverpod-нотифайеры: lib/game, lib/online, контроллеры; без BuildContext)
    ↓
Model: игровое ядро (lib/core/, pure Dart) + репозитории (lib/storage/, lib/auth/)
    ↑
Сетевой слой (server-authoritative онлайн)  ← server/ (Node, импортирует legacy-ts/core)
```

**Ядро (`lib/core/`, зеркально `legacy-ts/core`) обязано оставаться pure и детерминированным:**
- никаких `Random()`/`Math.random()` — только переданный `rng` от `makeRng(seed)` (mulberry32);
- никакого `DateTime.now()`/`Date.now()`, I/O, таймеров, импортов Flutter/DOM;
- одинаковый `(matchSeed, RuleConfig, moveLog)` → одинаковое состояние (нужно для реплеев, server-authoritative онлайна, golden-тестов, анти-чита);
- **два ядра (Dart и TS) должны совпадать бит-в-бит** — паритет охраняют golden-тесты; правишь логику в одном — правь во втором и обновляй golden.

Презентационный код (drag-and-drop, анимации, звук, тикание таймера) — только в `lib/ui/` + нотифайерах. Серверный авторитет (таймер, anti-cheat ориентаций, ELO) — в `server/`, но игровая механика — через импорт из `legacy-ts/core`, не дублировать.

## Деплой

- **Frontend** — GitHub Pages, ветка `gh-pages`, **Flutter Web**. **Автодеплой через GitHub Actions** (включён 2026-06-10, репо публичный → Actions бесплатны): push в `main` → `.github/workflows/deploy.yml` (analyze + test + build web + публикация в `gh-pages`); правки только доков/legacy/server деплой не триггерят (`paths-ignore`). Ручной деплой `npm run deploy:flutter` остаётся как запасной путь.
- **Backend (PvP)** — VPS `pvp.alshfu.com`, Ubuntu 24.04, systemd unit `blockduel-pvp.service`, nginx + Let's Encrypt. Flutter-клиент получает адрес через `--dart-define=PARTY_HOST/PARTY_TLS` (зашиты в npm-скрипты); TS-клиент — через `VITE_PARTY_HOST` в `.env.local` (gitignored). После правок `server/*.ts` нужен `git pull && systemctl restart blockduel-pvp` на VPS (делает пользователь).
- Подробности — в `DEPLOY.md` (включая post-cutover hardening: `REQUIRE_ROOM_TOKEN=1`, `ALLOWED_ORIGINS`).

## Конвенции

- Идентификаторы и комментарии в коде — английский (`BoardCell`, `enumerateMoves`, `RuleConfig`); константы в Dart — `lowerCamelCase`.
- Каждый Dart-файл начинается с подробной шапки-комментария (что за модуль, ключевые функции/классы).
- Документация и общение с пользователем — русский; технические термины можно оставлять английскими.
- MVVM обязателен: логика — в ядре/репозиториях, состояние — в нотифайерах, виджеты — тупые.
- Дефолты конфига зафиксированы в `defaultConfig` (`lib/core/types.dart`), `DEFAULT_CONFIG` (`legacy-ts/core/index.ts`) и ТЗ § 15 — должны совпадать.
- Формула очков: `base = N*(N+1)/2`, `mult = 1 + 0.1·min(combo, comboCap)`, `+15` за perfect clear.
- 7-bag: у каждого игрока свой мешок (`sharedBag = false`).
- Blitz: `turnTimeStart=12`, `turnTimeDecay=0.4`, `turnTimeMin=3`, `onTimeout="forcePlace"`.
- Версия приложения — в `pubspec.yaml` (`2.0.0+1`). `version` в `package.json` **намеренно** остаётся `1.6.1`: это версия legacy TS-фронта (прокидывается в его About через `__APP_VERSION__`), не поднимать при релизах Flutter.

## Стек

**Основной:** Dart + Flutter (+ Flame) + Riverpod — все платформы (Web в проде, macOS в работе, Android/iOS собираются). **Сервер:** Node + ws + tsx (`server/`, ядро из `legacy-ts/core`). **Auth/sync:** Firebase Auth + Firestore (проект `blockduel-web`). **Тесты:** flutter_test + Vitest (legacy-ядро/сервер).

## Чего НЕ делать самостоятельно

- Не дублировать игровую логику в `lib/ui/`, нотифайерах или `server/` — всё через ядро (`lib/core/` / `legacy-ts/core`).
- Не ломать паритет ядер: правка игровой логики только синхронно в обоих ядрах + golden-тесты.
- Не править файлы в `legacy/` — они инертные. `legacy-ts/ui` тоже не развивать (только критические фиксы для отката прода).
- Не отходить от ТЗ по правилам/балансу без явного запроса.
- Не пушить в `main` с красными тестами: push автодеплоит прод (CI-гейты analyze+test это ловят, но не насилуй их). Не отключать workflow `deploy.yml` без запроса пользователя.
- Не трогать `/etc/nginx/sites-enabled/alshfu-arena.conf` на VPS (это сторонний сайт пользователя).
