# Changelog

История значимых релизов BlockDuel 9×9. Формат — обратный хронологический.

## Unreleased

### Фаза 8 — Глубокая прогрессия (в работе)

- **8.1 — структурированная XP-формула** (`lib/profile/xp_formula.dart`):
  `xp = floor(baseXp · resultMult · diffMult · streakBonus)` (baseXp=50; win 1.0
  / draw 0.5 / loss 0.0; diffMult 0.7…1.6 по боту/ELO; streakBonus 1+0.05·streak
  cap 1.5). Заменила плоские 60/20. Интегрирована в `recordResult` + game_screen.
- **8.2 — награды за уровни 1–100** (`lib/profile/level_rewards.dart`): монеты +
  кристаллы на вехах + unlock зеркального набора на 100-м; начисляются при
  повышении уровня. Кривая уровней (triangular) уже была.
- 18 новых тестов прогрессии; всего **251** Flutter-тест зелёный.

### Фаза 5 — PvP-платформа: расширение режимов (в работе)

- **5.1 — реестр режимов** (`lib/modes/game_mode_descriptor.dart`): каталог
  `GameModeDescriptor`/`gameModes` (id, иконка, заголовок, маршрут, категория,
  статус) — единый источник правды для меню/роутера. Аддитивно поверх ядра, без
  правок пути 9×9/онлайна. Полное извлечение `GameRules`-интерфейса отложено,
  чтобы не дестабилизировать работающую дуэль.
- **5.2 — режим «Память: соло»** (`lib/modes/memory_solo/`): новый одиночный
  жанр поверх общего ядра. Игроку показывают раскладку из N тетромино, затем
  доска очищается, и он воспроизводит её по памяти. Pure-ядро
  `memory_solo_puzzle.dart` (детерминированная генерация раскладки + скоринг
  «точность × тайм-бонус», 5 уровней 3/5/7/9/12 фигур), ViewModel
  `memory_solo_notifier.dart` (фазы показ→сборка→итог, переиспользует
  `BoardView`/`HandView`), экран `memory_solo_screen.dart`, рекорды
  per-difficulty в `SharedPreferences`. Маршрут `/memory`, пункт меню
  «🧠 Память: соло». Полностью локален и детерминирован — не требует сервера.
  16 новых тестов; всего **194** Flutter-теста зелёные, `flutter analyze` чист.
- **5.4 — режим «Co-op Tetris»** (`lib/modes/coop/`): turn-based hot-seat на
  поле 10×20 с очисткой только полных строк (без боксов/падения). Pure-ядро
  generic-доски W×H, ViewModel хода по очереди (очки ходившему, финал по
  тупику), виджет высокого поля `CoopBoardView` (CustomPaint), экран. Маршрут
  `/coop`, пункт меню «🧱 Co-op Tetris».
- **5.3 — режим «Memory Duel» (локальный)** (`lib/modes/memory_duel/`): hot-seat
  дуэль «A расставляет → B запоминает → B повторяет» со сменой ролей; reuse
  `scoreMemory`/`BoardView`/`HandView`. Маршрут `/memory-duel`. Сетевые
  server-authoritative/анти-чит/ELO части — инфра-блокер (нужен VPS).
- **5.5 — режим «Match-3 PvP»** (`lib/modes/match3/`): turn-based «три в ряд»
  8×8 с 6 цветами. Pure-ядро (генерация без серий, поиск серий, легальность
  свопа, каскады с гравитацией/досыпкой, скоринг), ViewModel (лимит ходов),
  виджет цветной доски, экран. Маршрут `/match3`.
- **5.6 — composite-score** (`lib/modes/ladder/composite_score.dart`): pure
  формула `floor(0.4·E_general + 0.6·avg(E_modes))` + тесты (per-mode
  ELO-ladders и серверные эндпоинты — инфра-надстройка, отдельно).
- **Премиальная графика и анимации** (`lib/ui/decor/cell_fx.dart`): глянцевые
  ячейки/«леденцы» (радиальный блик + хайлайт + тень), pop-появление клеток,
  пульс выбора (Match-3), вспышка очищенных строк (Co-op), всплывающий «+счёт»,
  конфетти на победу/perfect/крупную очистку, анимированные табло и оверлеи
  итога, fade-through переходы маршрутов новых режимов.
- **Панель управления фигурой** (`lib/ui/widgets/piece_controls.dart`): в
  Co-op Tetris, Memory Solo и Memory Duel добавлены явные кнопки «повернуть»
  (Material-иконка, отключается для O-фигуры) и «снять» + подсказка-инструкция —
  поворот стал наглядным (паритет с панелью главного экрана 9×9). В нотифайеры
  добавлен `deselect()`.
- **Адаптивная раскладка во всех режимах с доской** (9×9 bot/hotseat/botvbot/
  arcade, онлайн PvP, Co-op, Match-3, Memory Solo, Memory Duel): на широких
  экранах (≥720px) поле уходит влево, а «обвязка» (табло/таймер/рука/панель
  управления/power-ups/подсказка) — вертикальной панелью справа (ROADMAP § 5.4
  «обвязка по бокам»); на узких — прежняя вертикаль с прокруткой (без изменений).
  `LayoutBuilder` + ветвление `wide` в каждом игровом экране.
- **Fix**: `HandView` переносит большие руки (`Wrap` вместо `Row`) — Memory
  Duel (6 фигур) и Memory Solo (до 12) больше не переполняют ряд; 9×9 (3 фигуры)
  без изменений.
- Итог Фазы 5: 4 новых играбельных режима + реестр, премиальный UI с понятным
  управлением, **234** Flutter-теста зелёные, `flutter analyze` чист. Остаток
  фазы — сетевые ELO-ladders (🔒 VPS).

## 2.0.0 — 2026-06-09 — Миграция на Dart/Flutter

Полный порт приложения с TypeScript + React на **Dart + Flutter (+ Flame +
Riverpod)**, влитый в `main` (merge `8a63a82`). Архитектура — строго **MVVM**
(Model = ядро/репозитории, ViewModel = Riverpod-нотифайеры без `BuildContext`,
View = виджеты без логики). Подробный журнал — `MIGRATION_PROGRESS.md`.

- **Ядро портировано** в pure-Dart `lib/core/` — **bit-for-bit детерминизм** с
  TS-ядром доказан golden-тестами (VM + Web): PRNG `mulberry32`, 7-bag, доска/
  очистки, scoring v1.6, перебор ходов, бот 3 уровней, blitz/force-place.
- **UI на Flutter/Flame**: доска/рука/score, drag-and-place + tap-to-rotate,
  3 темы (neutral/candy/night) с дизайн-токенами 1:1, маскоты/ponies через
  `flutter_svg`, Confetti на Flame, ComboFlash, Toast/Pause-оверлеи.
- **Звук и музыка синтезируются в Dart** (порт Web Audio): SFX-каталог +
  зацикленные фоновые треки тем, без аудиофайлов.
- **Контент-паритет**: Storage/Profile/Settings, ~120 ачивок (15 базовых + 105
  PvP), Daily quests, детерминистичный resume сохранёнки, Arcade, Tutorial
  (5 шагов), магазин (две валюты, скины доски, power-ups в игре), 12 аватаров.
- **Онлайн PvP**: Dart-клиент `lib/online/` к существующему **Node/VPS-серверу**
  по кросс-протоколу (лобби, матчмейкинг, живой матч с reconnect+ремачом, ELO-
  лидерборд K=24), богатая онлайн-статистика + экран `/stats`, `myElo` для
  ELO-ачивок.
- **Auth + sync**: Google sign-in (Firebase `blockduel-web`, web popup) +
  Firestore cross-device sync (`users/{uid}`, merge).
- **Безопасность сервера**: аудит (`SECURITY_AUDIT_SERVER.md`) + SEC-1..3
  (hardening, аутентификация `roomToken` end-to-end, добивка хвостов).
- **Реструктуризация репо**: Flutter-проект → **корень** (`lib/`, `test/`,
  `web/`, `pubspec.yaml`), старый TS/React-фронт → **`legacy-ts/`**. TS-ядро
  `legacy-ts/core` остаётся живым как зависимость Node-сервера.
- **Сборка/деплой**: `npm run build:flutter` / `deploy:flutter` (Flutter Web →
  GitHub Pages). **176 тестов** зелёные, `flutter analyze` чист.
- **Cut-over прода выполнен 2026-06-10**: GitHub Pages переключён на Flutter
  Web (`deploy:flutter`, gh-pages `e6c30a1`); откат — `npm run deploy`
  (TS-сборка). См. `DEPLOY.md`.

## 1.6.1 — 2026-06-03

- **handSize=4 удалён.** В SetupScreen и OnlineMenuScreen остались только
  «1 · тетрис», «2», «3». Server валидация ограничена 1..3.
- **Антидубликат в руке.** Bag получил метод `drawAvoiding(types)`: если top
  of mешка совпадает с типом уже в руке — берётся следующий не-дубликат
  из bag (queue position сохраняется через splice). Полный 7-bag fairness
  не нарушен — каждая фигура всё ещё появляется по разу в каждом цикле.
  Применено в:
  - initial-hand при freshInit / makeP (offline + server),
  - newPiece при performMove / handleMove,
  - powerSwapHand,
  - пересоздание hand при requestedCfg на сервере.

## 1.6.0 — 2026-06-03

Расширенная система очков (5 направлений сразу).

- **Бонус за тип очистки.** Бокс 3×3 теперь даёт больше, чем строка/столбец
  (по умолчанию box=15, row=col=10 базовых очков).
- **Multi-clear мультипликатор.** За каждый дополнительный clear к первому
  добавляется +15% (1 → ×1.0, 2 → ×1.15, 3 → ×1.30, 4 → ×1.45 ...).
- **Экспоненциальное комбо.** После 3-го хода подряд с очисткой к линейному
  множителю (1 + 0.1·combo) добавляется квадратичная часть (0.02·(combo−3)²).
  Cap-комбо 10: множитель достигает ×2.98 (было ×2.0).
- **Speed-бонус.** Если игрок ходит, пока осталось > 50% времени хода
  (blitz), получает до +40% к финальному множителю — линейная шкала от 50%
  к 100% оставшегося времени.
- **Placement-бонус за фигуру.** Длинные/неудобные фигуры дают
  фиксированный бонус даже без очистки: I=+5, L=+3, J=+3, T=+1, S=+1, Z=+1,
  O=0. Стимулирует тратить тяжёлые фигуры.
- **Perfect clear bonus** поднят с 15 до 25.
- API: оставлена legacy `scoreForMove(N, combo, perfect, cfg)` для бота;
  добавлена `scoreMoveDetailed(input)` с полным breakdown (base, placement,
  multiClearMult, comboMult, speedMult, perfectBonus, total). Тесты:
  `scoring.test.ts` 6 → 11 кейсов.
- Score-popup получил информативный suffix: `×N box` / `×N` / `combo` /
  `fast` / `PERFECT!` в зависимости от того, какой множитель сработал.
- Сервер (`server/room.ts`) использует тот же `scoreMoveDetailed`, чтобы
  online-очки совпадали с offline.

## 1.5.0 — 2026-06-03

Mobile UX и тестирование.

- **Mobile-fit без скролла.** Game-screen теперь помещается в 100dvh даже
  при одновременно открытых URL-bar и toolbar мобильного браузера. Board
  остаётся родным квадратом (max-width 420 / 600 / 680), сжимается
  только обвязка.
- **Inline рука соперника.** Мини-фигуры соперника сидят прямо в его
  pcard (карточке со счётом) — отдельная watch-полоса убрана,
  экономия ~50px.
- **Pre-select.** Игрок может выбрать и повернуть фигуру до того, как
  ему разрешат ходить. Финальный place всё равно отвергается, пока
  не наша очередь.
- **Status-bar убран** — состояние («ходишь / ход соперника / отвалился»)
  переехало в заголовок своей руки.
- **bot×bot без лишней обвязки.** TransformControls и PowerupsPanel
  скрыты в наблюдательном режиме.
- **E2E mobile audit.** `tools/e2e-mobile.ts` — Playwright headless
  Chromium прогоняет 20 viewport-ов флагманов iPhone и Galaxy S
  (2015–2024) × 3 chrome-overhead режима (full / urlbar / urlbar+toolbar).
  Дамп метрик: viewport / board / gameOverflow.
- **UI Pilot.** `?pilot=1` — внешний робот-водитель, симулирует игрока
  через настоящие PointerEvent-ы на DOM. Лениво подгружается через
  dynamic import, в обычной сборке не попадает в initial bundle.
  Журналирует каждое действие.
- **Сетевые правила.** `OnlineMenuScreen` показывает выбор handSize /
  rotation / flip перед quick-play. Сервер принимает `cfg` от первого
  подключившегося клиента и пересоздаёт руки под нужный handSize.
- **Tetris-режим (handSize=1).** Доступен в offline; в онлайне передаётся
  через расширенный hello-протокол.
- Множество фиксов ориентации фигур: первый tap не крутит, drag
  сохраняет повёрнутую ориентацию, нормализация cells в Hand.

## 1.0.0 — 2026-06-01

Первый публичный релиз.

- Core: ядро игры — 9×9 board, 7-bag, scoring (триангулярный + combo +
  perfect), бот 3 уровней (easy/medium/hard), blitz-таймер.
- UI: vs Bot, hot-seat, arcade, bot×bot. Темы neutral/candy/night.
  Звук, музыка, vibration.
- Прогрессия: XP, daily quests, ~120 ачивок, магазин (power-ups + скины
  ячеек), валюта = кристаллы.
- Онлайн PvP: собственный Node WS-сервер на VPS pvp.alshfu.com,
  server-authoritative match, ELO-лидерборд K=24.
- Auth + sync: Google sign-in через Firebase + Firestore cross-device.
- Live на GitHub Pages: https://alshfu.github.io/block-puzzle-pvp/
