# BlockDuel 9×9 — Roadmap Checklist

Полный план реализации в виде чек-листа. Каждый пункт — конкретный
закрываемый шаг с привязкой к коду, тестам и деплою.

**Условные обозначения:**
- ✅ — сделано и в проде.
- 🟨 — в работе.
- ⬜ — запланировано.
- 🔒 — заблокировано зависимостью.

Текущая версия: **v2.0.0** (Flutter-порт; см. [CHANGELOG.md](CHANGELOG.md)).
Источник истины по фичам и балансу — [TZ_BlockDuel_9x9.md](TZ_BlockDuel_9x9.md).



---

## Фаза M — Миграция на Flutter ✅ (влита в main)

- [x] Pure-Dart порт ядра `lib/core/` — bit-for-bit детерминизм с TS-ядром
      (golden-gate).
- [x] Flame-рендер доски/руки, drag-and-place, blitz/force-place.
- [x] Дизайн-токены 1:1 с TS (3 темы), маскоты через `flutter_svg`, Confetti/
      ComboFlash, Toast/Pause, фоновая музыка — в `lib/audio/`/`lib/ui/`.
- [x] Storage/Profile/Settings/Achievements (~120)/Daily/Save-Resume/Arcade/
      Tutorial/Pilot — паритет с TS (чеклист `INTERFACE_PARITY.md`).
- [x] Онлайн PvP: Dart-клиент `lib/online/` к существующему Node/VPS-серверу
      (кросс-протокол), лобби, живой матч (reconnect+ремач), ELO, онлайн-стата.
- [x] Auth + sync: `lib/auth/` — Google sign-in (Firebase `blockduel-web`) +
      Firestore cross-device sync.
- [x] Реструктуризация репо: Flutter → корень, `src/` → `legacy-ts/`.
- [x] Security-аудит PvP-сервера (`SECURITY_AUDIT_SERVER.md`) + SEC-1..3.
- [x] 176 тестов зелёные, `flutter analyze` чист, `flutter build web` собирается.

### Near-term — прод cut-over ✅
- [x] **2026-06-10** — `npm run deploy:flutter`: GitHub Pages переключён на
      Flutter Web (gh-pages `e6c30a1`, live отдаёт `flutter_bootstrap.js`).
- [x] Post-cutover (на VPS, когда старых TS-вкладок не осталось): включить
      `REQUIRE_ROOM_TOKEN=1` + `ALLOWED_ORIGINS` (см. DEPLOY.md).
- [x] **2026-06-10** — ветка `flutter-migration` заархивирована: тег
      `archive/flutter-migration` (→ `49a813e`), ветка удалена (local + origin).

---

> **Фазы 0–4 ниже** описывают исходную фичу-базу (реализована в TS, в проде на
> Pages) — она **портирована на Flutter** в рамках Фазы M (см. выше). Пути в них
> читать как `lib/...`.

## Фаза 0 — Прототип ядра ✅

- [x] Pure-TS ядро `src/core/index.ts` без UI/I/O.
- [x] Детерминированный PRNG `mulberry32` + `makeRng(seed)`.
- [x] 7-bag генератор фигур (`Bag.draw`, `Bag.drawAvoiding`).
- [x] Тетромино I/O/T/S/Z/J/L + `normalize` / `rotate90` / `flipH` / `orientations`.
- [x] Доска 9×9, `canPlace`, `place`, `findClears`, `applyClears`,
      `isPerfectClear`, `hasAnyMove`, `forcePlace`.
- [x] Scoring (расширенный v1.6): `scoreForMove` (legacy) + `scoreMoveDetailed`.
- [x] Blitz: `turnTimeForRound`.
- [x] Vitest: 55 тестов (clears, scoring, bag, deadlock, determinism, timer, bot, pilot).

## Фаза 1 — MVP: ядро + бот ✅

- [x] Vite + React 18 + TS, Hot Module Reload.
- [x] Экраны: Menu, Setup, Game, ResultOverlay, Pause, Profile, Settings.
- [x] Drag-and-place + tap-to-rotate + click-to-place (desktop).
- [x] Темы: `neutral`, `candy`, `night` (CSS-переменные на `.app-root`).
- [x] Бот 3 уровней (easy / medium / hard) с `BOT_WEIGHTS`.
- [x] Дешёвый `opponentThreatGain` (missing=1), hard <300мс.
- [x] Синтезированный звук (place / clear-N / perfect / win / lose / draw).
- [x] Локальное автосохранение (drawCounts + полный snapshot).
- [x] Прогон bot-vs-bot для калибровки (`tools/bot-sim.ts`).

## Фаза 2 — Локальный мультиплеер + контент ✅

- [x] Hot-seat (два игрока на одном устройстве).
- [x] Arcade (соло на рекорд).
- [x] Bot×bot спектатор.
- [x] XP / уровни / win-streaks.
- [x] Базовые ачивки (15 шт.), daily quests.
- [x] Магазин: power-ups + скины ячеек, валюта = кристаллы.
- [x] Темная фоновая музыка (`src/ui/music.ts`).
- [x] Тутор 5-шаговый онбординг.
- [x] Settings: volumes, motion, gameplay, data export/import, about.

## Фаза 3 — Онлайн PvP ✅

- [x] Собственный Node WS сервер на VPS `pvp.alshfu.com`.
- [x] systemd unit `blockduel-pvp.service`, nginx + Let's Encrypt.
- [x] Lobby + matchmaking + bot fallback (25 сек).
- [x] Server-authoritative room: 60с timer, orientation anti-cheat, rematch.
- [x] Глобальный ELO лидерборд (K=24, start 1000).
- [x] 105 ачивок PvP + расширенная стата онлайн-матчей.
- [x] Server-pcm config через hello: `handSize`, `rotationEnabled`, `flipEnabled`.

## Фаза 4 — Auth, монетизация v1, оптимизация ✅

- [x] Google sign-in через Firebase + Firestore cross-device sync.
- [x] Lazy-load Firebase (через dynamic import) — не блокирует FCP.
- [x] Skip Firebase для гостей (флаг `bd_auth_signed_in` в localStorage).
- [x] Lighthouse: Performance 98 / Best Practices 100 / SEO 100.
- [x] PWA-like мобильный layout (no-scroll, board родного размера).
- [x] UI Pilot (`?pilot=1`) для E2E через реальные PointerEvent.
- [x] E2E mobile audit (Playwright 20 устройств × 3 chrome-overhead).
- [x] Расширенная scoring formula v1.6: типы очисток, multi-clear,
      exp-combo, speed-bonus, placement-бонус.
- [x] 7-bag anti-duplicate в hand (`Bag.drawAvoiding`).
- [x] Online setup screen с выбором `handSize`/`rotation`/`flip`.
- [x] Inline opponent hand в pcard.
- [x] Pre-select piece пока ход соперника.
- [x] Versioning + CHANGELOG.md, версия в Settings → About.

---

## Фаза 5 — PvP-платформа: расширение режимов ⬜

**Цель:** превратить BlockDuel из одной игры в платформу с несколькими
жанрами поверх общего ядра.

### 5.1. Архитектурный рефакторинг 🟨
- [x] **2026-06-17** — реестр режимов `lib/modes/game_mode_descriptor.dart`
      (`GameModeDescriptor`/`gameModes`: id/иконка/заголовок/маршрут/категория/
      статус) — единый источник правды для меню/роутера, аддитивно поверх ядра,
      без правок 9×9/онлайна.
- [ ] Извлечь интерфейс `GameRules` из `lib/core/`:
      `legalMoves`, `applyMove`, `scoreMove`, `endConditions` (отложено — чтобы
      не ломать работающий путь дуэли/онлайна).
- [ ] Перенести 9×9 в `lib/modes/blockduel/`.
- [ ] Адаптировать `GameNotifier` / `OnlineGameNotifier` через injection.

### 5.2. Memory Solo ✅ (2026-06-17)
- [x] Реализация `lib/modes/memory_solo/` (pure-ядро `memory_solo_puzzle.dart`):
      pre-show раскладку → очистка → reconstruct, детерминированная генерация.
- [x] UI `lib/ui/screens/memory_solo_screen.dart`: показ с обратным отсчётом,
      hint «запомни», timer сборки, экран итога; ViewModel `memory_solo_notifier`.
- [x] Scoring `scoreMemory`: точность (correctly placed / total) × time-bonus,
      штраф за лишние клетки, perfect-бонус.
- [x] Сохранение high-score `lib/modes/memory_solo/memory_solo_store.dart`
      (per-difficulty в SharedPreferences).
- [x] 5 уровней сложности (3 / 5 / 7 / 9 / 12 фигур).
- [x] Тесты `test/modes/` (16: генерация-детерминизм, скоринг, фазы notifier).

### 5.3. Memory Duel 🟨 (локальный hot-seat готов 2026-06-17)
- [x] UI-поток: «расставь» (A) → «смотри» (B) → «повтори» (B), смена ролей,
      сравнение точности (`lib/modes/memory_duel/`, экран `memory_duel_screen`).
- [x] Локальный scoring через `scoreMemory` (reuse Memory Solo). Маршрут
      `/memory-duel`, пункт меню «🃏 Memory Duel».
- [ ] 🔒 Сетевой протокол `memory-place` / `memory-show` / `memory-recall`
      (инфра-блокер: требует Node-сервер на VPS).
- [ ] 🔒 Server-authoritative scoring + анти-чит на time-budget показа.
- [ ] 🔒 Отдельный ELO ladder «Memory Duel».

### 5.4. Co-op Tetris (turn-based 10×20) ✅ (2026-06-17, локально)
- [x] Поле 10×20 (`lib/modes/coop/coop_core.dart`, generic W×H).
- [x] Тот же набор тетромино без падения — pure puzzle.
- [x] Hand из 3 фигур у каждого, ходы по очереди (`coop_notifier`).
- [x] Очистка строк (НЕ боксов): row complete → clear, очки ходившему.
- [x] UI: высокое поле `CoopBoardView` (CustomPaint), табло, экран `coop_screen`.
- [ ] 🔒 Отдельный ELO ladder (инфра-блокер: онлайн-надстройка).

### 5.5. Match-3 PvP ✅ (2026-06-17, локально)
- [x] Поле 8×8 c 6 цветами (`lib/modes/match3/match3_core.dart`).
- [x] Ход = swap двух соседних (легален лишь создающий серию).
- [x] Серии ≥ 3 одного цвета → clear, каскады (гравитация + досыпка).
- [x] По очереди, очки за серию с каскад-бонусом (`match3_notifier`).
- [x] Графика «леденцов» `Match3BoardView`, экран `match3_screen`, маршрут
      `/match3`.

### 5.7. Классический Tetris (живое падение) ✅ (2026-06-18, локально)
- [x] Pure-ядро `lib/modes/tetris/tetris_core.dart`: поле 10×20, 4 состояния
      поворота (через `rotate90`), wall-kick, drop-distance, СХЛОПЫВАЮЩАЯ очистка
      строк (классика, не row-in-place), таблица очков (100/300/500/800×уровень),
      кривые `tetrisLevelForLines`/`tetrisGravitySeconds`.
- [x] ViewModel `tetris_notifier.dart`: гравитация через `tick(dt)` (темп —
      Ticker во View, ядро без таймеров), move/soft/hard drop, повороты CW/CCW,
      hold (раз за фигуру), очередь NEXT, рекорд в SharedPreferences.
- [x] View `tetris_board_view.dart` (классическая 7-цветная палитра, призрак
      приземления, вспышка очисток) + `tetris_screen.dart` (HUD score/lines/
      level/NEXT/HOLD, адаптивная раскладка, оверлеи паузы/конца).
- [x] **Грамотное управление с клавиатуры (web/desktop):** ← → двигать, ↓ soft
      drop, ↑/X поворот CW, Z/Ctrl поворот CCW, Space hard drop, C/Shift hold,
      P/Esc пауза, Enter рестарт; DAS (авто-повтор) для движения/soft drop +
      экранные кнопки для тача.
- [x] Реестр режимов (`game_mode_descriptor` id `tetris`), маршрут `/tetris`,
      пункт меню «🧩 Классический Tetris».
- [x] Тесты `test/modes/tetris_test.dart` (геометрия/очистка/счёт + ViewModel).
- [ ] 🔒 ELO-ladder (онлайн-надстройка).

### 5.6. Composite-score и ladder-листы 🟨
- [x] Composite-score формула `floor(0.4·E_general + 0.6·avg(E_modes))`
      (`lib/modes/ladder/composite_score.dart`, pure + тесты).
- [ ] 🔒 Снапшоты ELO по каждому моду + сезонный сброс (инфра: серверный ELO).
- [ ] 🔒 UI `LeaderboardScreen` с табами (General / 9×9 / Memory / Co-op / …).
- [ ] 🔒 Server-side endpoint `/leaderboard/<mode-id>`.

> **Статус Фазы 5 (2026-06-17):** все локальные/офлайн-проверяемые части
> закрыты — реестр режимов (5.1) и четыре новых режима (Memory Solo, Memory
> Duel, Co-op Tetris, Match-3) играбельны, покрыты тестами (233 Flutter-теста
> зелёные) и доведены до **премиального вида** (глянцевая графика, pop/вспышки/
> конфетти/floating-счёт, fade-переходы — `lib/ui/decor/cell_fx.dart`). **Остаток — сетевые надстройки** (🔒): server-authoritative
> scoring, анти-чит и per-mode ELO-ladders требуют живого Node-сервера на VPS
> (сейчас в ремонте, см. `[[project-macos-finish]]`), поэтому реализуются и
> верифицируются отдельно. Полный `GameRules`-рефактор (5.1) отложен, чтобы не
> дестабилизировать работающую 9×9-дуэль/онлайн.

---

## Фаза 6 — LAN PvP (без интернета) ⬜

**Цель:** играть на двух устройствах в одной локальной сети — поезд,
самолёт, дача.

### 6.1. mDNS / Wi-Fi Direct ⬜
- [ ] Использовать `Bonjour` (Capacitor plugin) для discovery.
- [ ] Host создаёт WebSocket-сервер на устройстве (порт 1999).
- [ ] Клиент сканирует mDNS и подключается через `ws://<host-ip>:1999/parties/room/lan-<uuid>`.
- [ ] Reuse существующего `party/protocol.ts` без изменений.

### 6.2. BLE peer-to-peer ⬜
- [ ] Capacitor Bluetooth LE plugin.
- [ ] Сервис UUID + JSON-frame transport (по 20 байт пакетами).
- [ ] Reliable delivery layer (ack + retry).
- [ ] Fallback когда нет общей Wi-Fi.

### 6.3. QR pairing ⬜
- [ ] Host отображает QR с `{ip, port, room-id}`.
- [ ] Клиент сканирует камерой через `@capacitor-community/barcode-scanner`.
- [ ] Используется когда нет mDNS и BLE.

### 6.4. UI и навигация ⬜
- [ ] Новый экран `LANMenuScreen`: «Создать комнату» / «Присоединиться».
- [ ] Список найденных соседей с pin'ом устройства.
- [ ] Индикация типа транспорта (mDNS / BLE / QR) в HUD матча.
- [ ] LAN-матчи **не** учитываются в глобальном ELO.

### 6.5. Тесты ⬜
- [ ] Two-process integration test (запуск двух node-процессов, обмен).
- [ ] Manual test plan: iPhone + Android в одной Wi-Fi.

---

## Фаза 7 — Социальная система и анти-абуз ⬜

### 7.1. Друзья ⬜
- [ ] Firestore collection `users/{uid}/friends`.
- [ ] Поиск по `nick` (case-insensitive, prefix), по `id` UUID, по QR.
- [ ] Состояния: pending / accepted / blocked.
- [ ] Лимит 100 друзей.
- [ ] UI: `FriendsScreen` со списком, статусом «онлайн / в матче / оффлайн».

### 7.2. Приглашения и комнаты ⬜
- [ ] Direct invite: «Сыграй со мной — режим X, cfg Y».
- [ ] Push-уведомление о приглашении (Фаза 11).
- [ ] Принять / отклонить → joins онлайн-матча.
- [ ] Custom-room с любым cfg (handSize, время, режим).

### 7.3. Управление матчем ⬜
- [ ] Кнопка «Предложить ничью» (доступна с 10-го хода).
- [ ] Принять/отклонить от соперника. При принятии — XP и ELO как ничья.
- [ ] Кнопка «Сдаюсь» — мгновенное поражение для сдавшегося.
- [ ] Кнопка «Завершить досрочно» (auto-judgement по текущему счёту).
- [ ] Server-side state machine для draw-offers.

### 7.4. Анти-абуз (penalties) ⬜
- [ ] `quit_penalty`: выход без resign → −10 ELO + 24h ranked cooldown.
- [ ] `afk_penalty`: 3 force-place подряд → авто-resign.
- [ ] `rage_quit_detector`: 3 quit-penalty за 24ч → 7-дневный suspension.
- [ ] Server-side tracking в `users/{uid}/sanctions`.
- [ ] UI: предупреждение перед quit, виден остаток cooldown.

### 7.5. Чат комнат ⬜
- [ ] Текстовый чат в OnlineGameScreen (опционально).
- [ ] Quick-emote'ы (👍 😅 🔥 🤔 GG).
- [ ] Toxicity filter (basic word-list).

---

## Фаза 8 — Глубокая прогрессия (уровни 1-100 + квесты) 🟨 (в работе с 2026-06-18)

### 8.1. Перебалансировка XP-формулы ✅ (2026-06-18)
- [x] `xp = floor(baseXp · resultMult · diffMult · streakBonus)` —
      `lib/profile/xp_formula.dart` (baseXp=50).
- [x] Победа `resultMult=1.0` / ничья `0.5` / поражение `0.0`.
- [x] `diffMult` по уровню бота (0.7/1.0/1.3) и по разнице ELO (зажат 0.7…1.6).
- [x] `streakBonus = 1 + 0.05·streak` (cap 1.5), серия из stats.
- [x] Тесты `test/profile/xp_formula_test.dart` (11). Интегрировано в
      `ProfileController.recordResult` + `game_screen`.

### 8.2. Кривая уровней 1-100 🟨
- [x] Triangular: `xpToReachLevel(n) = floor(50 · n · (n+1) / 2)` —
      `lib/profile/profile.dart` (уже было).
- [x] Награды каждому уровню — `lib/profile/level_rewards.dart`
      (монеты + кристаллы на вехах + unlock на 100), начисляются при level-up
      в `ProfileController`. Тесты `test/profile/level_rewards_test.dart` (7).
- [x] **2026-06-18** UI: карточка next-level reward на экране профиля
      (`_NextRewardCard` в `profile_screen.dart`: «До уровня N: X XP» + награда).
- [x] Достижение 100 → unlock `mirror-pieces` (потребляется § 8.5).

### 8.3. Гарантия валидного hand для новичков ≤ 10 ✅ (2026-06-18)
- [x] `lib/game/opening_hand.dart` — `dealOpeningHand(bag, k, board, cfg)`:
      проверяет `hasAnyMove`, при dead-руке перераздаёт до 3 раз. Подключено в
      `GameNotifier._freshState` для игрока 0 (на пустой доске reroll не нужен —
      последовательность мешка та же, это защитная гарантия).
- [x] Тест `test/game/opening_hand_test.dart` (1000 свежих init'ов — 0 dead;
      идентичность обычной раздаче на пустой доске; не зацикливается на full).

### 8.4. Расширенная квестовая система 🟨 (2026-06-18)
- [x] Обобщённый движок `lib/quests/quest.dart` (метрики/цели/награды, периоды,
      детерминированный выбор, QuestEvent, QuestPeriodState с кум./max-метриками).
- [x] Daily — существующий `lib/daily/` (3 квеста, ротация по дню).
- [x] Weekly (3 из пула): 10 побед, 5 perfect, серия 5, 150 линий, Hard×3, 20 игр.
- [x] Seasonal (2 из пула, 90 дней): 25 онлайн-побед, 100 побед, 25 perfect,
      серия 10.
- [x] UI `lib/ui/screens/quests_screen.dart` — 3 вкладки, прогресс-бары, claim
      (монеты+кристаллы). Маршрут `/quests`, иконка 🎯 в меню.
      Тесты `test/quests/quest_test.dart` (8).
- [ ] 🔒 Server-side validation квестов в `users/{uid}/quests` (требует VPS).

### 8.5. Бонусный piece-set (100 уровень) ✅ (2026-06-18)
- [x] `lib/profile/mirror_pieces.dart` — зеркальный набор: горизонтальное
      отражение тетромино = переотображение типов `mirrorOf` (S↔Z, J↔L; I/O/T
      самосимметричны) + `mirrorShape` для превью/тестов. Pure, тесты
      `test/profile/mirror_pieces_test.dart`.
- [x] Опт-ин в Settings (`mirrorPiecesEnabled`), тумблер виден/доступен только
      при достижении 100-го уровня (иначе 🔒-подсказка).
- [x] Применение в режиме «Tetris» (`TetrisNotifier(mirror: …)`) — не трогает
      parity-связанное ядро 9×9.
- [ ] Применение в 9×9/онлайне отложено: потребует синхронной правки TS-ядра
      (golden-паритет), поэтому вне этого инкремента.

---

## Фаза 9 — Puzzle Silhouettes ⬜

### 9.1. Игровой режим ⬜
- [ ] `src/modes/puzzle/`: маска-шаблон + ограниченный hand.
- [ ] N ходов на решение, zone outside mask заблокирована.
- [ ] Скоринг: solved/unsolved + бонус за оставшиеся ходы.

### 9.2. Не-стандартный piece-set ⬜
- [ ] `BASE_SHAPES_PUZZLE` в отдельном модуле.
- [ ] L-shape с закруглением, T-shape со скосом, Plus, Mini (1×1),
      Pentomino-варианты, Diagonal-step.
- [ ] SVG-рендер для закруглений (вместо grid-of-squares).

### 9.3. Контент-pack ⬜
- [ ] 50-100 силуэтов к старту: животные (кот, мишка, пони, дельфин),
      объекты (домик, машина, дерево), мемы (sus, sigma).
- [ ] In-house level editor (внутренний tool).
- [ ] JSON-схема `puzzles/<id>.json`.

### 9.4. Прогрессия и рейтинг ⬜
- [ ] «Puzzle Speedrun» ladder — лучшее суммарное время для season-pack.
- [ ] Уровни сложности: Easy / Medium / Hard / Expert.
- [ ] Награда за каждое прохождение: 10-100 coins.

---

## Фаза 10 — Монетизация v2 (IAP + кастомизация) ⬜

### 10.1. In-app purchase ⬜
- [ ] Pack-of-100 / 500 / 1500 / 5000 кристаллов с бонусом за объём.
- [ ] Интеграция с RuStore (РФ), App Store (iOS), Play Store (Android),
      web Stripe (для desktop-версии).
- [ ] Server-side receipt validation.
- [ ] Анти-fraud: лимиты, fingerprint, refund handling.

### 10.2. Конструктор тем ⬜
- [ ] Премиум-инструмент за 5000 кристаллов.
- [ ] Выбор цветов p0/p1, фона, шрифта, эффектов.
- [ ] Preview в реальном времени.
- [ ] Сохранение в `users/{uid}/customThemes`.
- [ ] Опциональная публикация в маркетплейс с модерацией.

### 10.3. Трансляция скинов соперника ⬜
- [ ] `OnlineGameState.players[i].skinId` → клиент рендерит board ячейки
      с этим skin'ом.
- [ ] Исключение: если у нашего клиента включен `accessibility` режим —
      все скины проигнорированы, нейтральная палитра.
- [ ] UI-индикатор «соперник использует пак X».

### 10.4. Сезонный pass ⬜
- [ ] 90-дневный pass за 990 кристаллов.
- [ ] 50 уровней с reward'ами (free track + premium track).
- [ ] Прогресс через любую игру (XP-based).

### 10.5. Расширенный магазин ⬜
- [ ] Категории: themes / cell-skins / backgrounds / clear-effects / music
      / avatars / power-ups.
- [ ] Bundles (theme+music+effect за скидку).
- [ ] Limited-time offers (24-48ч).
- [ ] Wishlist + push при скидке.

---

## Фаза 11 — Платформенный rollout (нативный mobile) ⬜

### 11.1. Capacitor wrapping ⬜
- [ ] `@capacitor/core` + `@capacitor/ios` + `@capacitor/android`.
- [ ] Reuse Vite build → нативная WebView оболочка.
- [ ] Adaptive icons + splash для iOS и Android.

### 11.2. Push-уведомления ⬜
- [ ] FCM (Android) + APNs (iOS) integration через Capacitor.
- [ ] Server endpoint для отправки: invite от друга, начало сезона,
      ход соперника, daily quest reminder.
- [ ] Opt-in management в Settings.

### 11.3. Single account across devices ⬜
- [ ] Apple Sign-in + Telegram OAuth + Google + Email.
- [ ] Session-management: при логине на новом устройстве — уведомление
      на старое.
- [ ] Conflict-resolver «max wins» по XP/coins/achievements; ELO
      server-authoritative.

### 11.4. On-demand assets ⬜
- [ ] CDN-хранение тяжёлых ассетов (темы, музыка, фоны).
- [ ] Lazy-download при первом использовании.
- [ ] Локальный кеш с очисткой LRU при нехватке места.

### 11.5. Store submission ⬜
- [ ] App Store: метаданные, скриншоты, политика, review.
- [ ] Google Play: то же + Android App Bundle.
- [ ] RuStore: версия для РФ-региона.
- [ ] In-app rating prompt (после 5+ матчей).

---

## Кросс-фазовые задачи (постоянные)

- [ ] **E2E на всех релизах:** прогон `integration_test/app_test.dart` (pilot)
      перед каждым деплоем; QA-планы по платформам — в `qa/`.
- [ ] **Bot-calibration:** периодически (раз в квартал) запуск
      `tools/bot-sim.ts` для проверки балансa.
- [ ] **Lighthouse:** ≥ 95 / 100 / 100 (Perf / BP / SEO) на каждом деплое.
- [ ] **CHANGELOG.md:** обновлять при каждом значимом релизе.
- [ ] **Версионирование:** semver bump в `pubspec.yaml` (`version:`) перед deploy.

---

## Принципы реализации

1. **Ядро остаётся pure и детерминированным.** Любая новая логика — через
   расширение `GameRules` или per-mode модуль. Никаких `DateTime.now()`,
   незасеянного RNG, I/O или импортов UI в `lib/core/`. TS-ядро `legacy-ts/core`
   держим bit-for-bit идентичным Dart-ядру (golden-gate), пока оно питает сервер.
2. **Server-authoritative для ranked.** Все режимы с ELO должны иметь
   server-side validation (anti-cheat).
3. **Backward compat при изменениях scoring.** Legacy `scoreForMove`
   сохраняется для бота; новые поля идут через optional fields в cfg.
4. **Mobile-first UI.** Каждая новая страница тестируется через e2e на
   iPhone 6s (worst-case) и iPhone 16 Pro Max (best-case).
5. **Накопительная документация.** Каждый сделанный пункт roadmap
   → запись в CHANGELOG + (если нужно) обновление TZ.

---

## Ссылки

- [TZ_BlockDuel_9x9.md](TZ_BlockDuel_9x9.md) — источник истины по фичам.
- [CHANGELOG.md](CHANGELOG.md) — история релизов.
- [CLAUDE.md](CLAUDE.md) — инструкции для AI-помощника.
- [HANDOFF.md](HANDOFF.md) — карта проекта и хронология решений.
- [MIGRATION_FLUTTER.md](MIGRATION_FLUTTER.md) — план миграции; [MIGRATION_PROGRESS.md](MIGRATION_PROGRESS.md) — живой чеклист.
- [DEPLOY.md](DEPLOY.md) — деплой Pages + VPS, frontend cut-over.
- Live: [alshfu.github.io/block-puzzle-pvp/](https://alshfu.github.io/block-puzzle-pvp/)
- Repo: [github.com/alshfu/block-puzzle-pvp](https://github.com/alshfu/block-puzzle-pvp)
