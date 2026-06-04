# BlockDuel 9×9 — Roadmap Checklist

Полный план реализации в виде чек-листа. Каждый пункт — конкретный
закрываемый шаг с привязкой к коду, тестам и деплою.

**Условные обозначения:**
- ✅ — сделано и в проде.
- 🟨 — в работе.
- ⬜ — запланировано.
- 🔒 — заблокировано зависимостью.

Текущая версия: **v1.6.1** (2026-06-04, см. [CHANGELOG.md](CHANGELOG.md)).
Источник истины по фичам и балансу — [TZ_BlockDuel_9x9.md](TZ_BlockDuel_9x9.md).

---

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

### 5.1. Архитектурный рефакторинг ⬜
- [ ] Извлечь интерфейс `GameRules` из текущего `src/core/index.ts`:
      `legalMoves`, `applyMove`, `scoreMove`, `endConditions`.
- [ ] Перенести 9×9 в `src/modes/blockduel/`.
- [ ] Создать `src/modes/<id>/index.ts` шаблон.
- [ ] Адаптировать `useGame` / `useOnlineGame` через `GameRules` injection.
- [ ] Тесты на back-compat: 55 текущих тестов проходят без изменений.

### 5.2. Memory Solo ⬜
- [ ] Реализация в `src/modes/memory-solo/`:
      pre-show раскладку на 3 сек → очистка → reconstruct phase.
- [ ] UI: countdown 3-2-1, hint «запомни», timer reconstruct.
- [ ] Scoring: точность (correctly placed / total) × time-bonus.
- [ ] Сохранение high-score в `storage/memory-solo.ts`.
- [ ] 5 уровней сложности (3 / 5 / 7 / 9 / 12 фигур).
- [ ] Тесты ядра mode (legalMoves, scoreMove).

### 5.3. Memory Duel ⬜
- [ ] Сетевой протокол: `memory-place` / `memory-show` / `memory-recall`.
- [ ] UI: фаза «расставь» (A) → фаза «смотри» (B) → фаза «повтори» (B).
- [ ] Server-authoritative scoring (защита от cheat).
- [ ] Отдельный ELO ladder «Memory Duel».
- [ ] Анти-чит на time-budget показа.

### 5.4. Co-op Tetris (turn-based 10×20) ⬜
- [ ] Поле 10×20 (вертикальный layout на мобиле).
- [ ] Тот же набор тетромино, но без падения — pure puzzle.
- [ ] Hand с 3 фигурами на каждого, по очереди.
- [ ] Очистка строк (НЕ боксов): row complete → clear, очки тому, кто
      сделал ход.
- [ ] UI-адаптация: на мобиле board теперь высокий, обвязка по бокам.
- [ ] Отдельный ELO ladder.

### 5.5. Match-3 PvP (зарезервировано) ⬜
- [ ] Поле 8×8 c 6 цветами.
- [ ] Ход = swap двух соседних.
- [ ] Серии ≥ 3 одного цвета → clear.
- [ ] По очереди, очки за каждую серию.
- [ ] Базовая графика «леденцов».

### 5.6. Composite-score и ladder-листы ⬜
- [ ] `src/ui/storage/ladders.ts` — снапшоты ELO по каждому моду.
- [ ] Сезонный сброс ELO ±20% к 1000 каждые 90 дней.
- [ ] UI: `LeaderboardScreen` с табами (General / 9×9 / Memory / Co-op / ...).
- [ ] Composite-score формула: `floor(0.4·E_general + 0.6·avg(E_modes))`.
- [ ] Server-side endpoint `/leaderboard/<mode-id>`.

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

## Фаза 8 — Глубокая прогрессия (уровни 1-100 + квесты) ⬜

### 8.1. Перебалансировка XP-формулы ⬜
- [ ] `xp = floor(baseXp · resultMult · diffMult · streakBonus)`.
- [ ] Победа `resultMult=1.0` / ничья `0.5` / поражение `0.0`.
- [ ] `diffMult` 0.7 (easy bot) … 1.6 (ranked +50 ELO).
- [ ] `streakBonus = 1 + 0.05·streak` (cap 1.5).
- [ ] Тесты в `tests/xp.test.ts`.

### 8.2. Кривая уровней 1-100 ⬜
- [ ] Triangular: `xpToLevel(n) = floor(50 · n · (n+1) / 2)`.
- [ ] Награды каждому уровню: см. таблицу в TZ § 17.1.
- [ ] UI: progress bar с указанием next-level reward.
- [ ] Hi-score при достижении 100 → бонусные piece-set unlock.

### 8.3. Гарантия валидного hand для новичков ≤ 10 ⬜
- [ ] В `freshInit` для player с level ≤ 10: проверить `hasAnyMove`.
- [ ] Если dead — реролл bag-snapshot до 3 попыток.
- [ ] Тест на 1000 свежих init'ов — у новичков 0 dead-старта.

### 8.4. Расширенная квестовая система ⬜
- [ ] `src/ui/quests/engine.ts` — общий движок triggers/conditions/rewards.
- [ ] Daily (3-5 шт., ротация в 00:00 UTC): «Очисть 5 строк», «Победи бота
      Hard», «Сыграй 3 матча онлайн», и т.д.
- [ ] Weekly (1-2 шт.): «10 побед подряд», «5 perfect clear'ов».
- [ ] Seasonal (1 шт., 90 дней): «Топ-10 в Bot Mastery», «25 онлайн-побед».
- [ ] Server-side validation квестов в `users/{uid}/quests`.
- [ ] UI: `QuestsScreen` с прогресс-барами, награда-claim.

### 8.5. Бонусный piece-set (100 уровень) ⬜
- [ ] 7 «mirror-фигур» — отражённые версии классических тетромино с
      diagonally cut углами.
- [ ] Применимо во всех режимах, опт-ин в Settings.
- [ ] Визуально отличаются скином.

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

- [ ] **E2E на всех релизах:** прогон `tools/e2e-mobile.ts` на 60 viewport-ах
      перед каждым деплоем.
- [ ] **Bot-calibration:** периодически (раз в квартал) запуск
      `tools/bot-sim.ts` для проверки балансa.
- [ ] **Lighthouse:** ≥ 95 / 100 / 100 (Perf / BP / SEO) на каждом деплое.
- [ ] **CHANGELOG.md:** обновлять при каждом значимом релизе.
- [ ] **Версионирование:** semver bump в `package.json` перед deploy.

---

## Принципы реализации

1. **Ядро остаётся pure и детерминированным.** Любая новая логика — через
   расширение `GameRules` или per-mode модуль. Никаких `Date.now()`,
   `Math.random()`, `fetch`/DOM в `src/core/`.
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
- Live: [alshfu.github.io/block-puzzle-pvp/](https://alshfu.github.io/block-puzzle-pvp/)
- Repo: [github.com/alshfu/block-puzzle-pvp](https://github.com/alshfu/block-puzzle-pvp)
