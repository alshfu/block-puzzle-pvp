# Миграция BlockDuel 9×9 → Dart + Flutter

**Статус:** план, не реализация. Источник правды по правилам и балансу — `TZ_BlockDuel_9x9.md`.
**Дата:** 2026-06-05.
**Целевая версия Dart/Flutter:** Dart 3.5+, Flutter 3.24+ (stable channel).

---

## 1. Цель

Полностью перенести проект с **TypeScript + React + Vite + Node** на **Dart + Flutter (+ Flame)** так, чтобы:

1. Одна кодовая база собиралась на **Web, iOS, Android, macOS, Windows, Linux** без форков.
2. Игровое ядро (`core/`) оставалось **pure и детерминированным** — то же `(seed, RuleConfig, moveLog) → state`, что и сейчас в TS.
3. Серверный авторитет онлайна сохранялся; протокол (формат WS-сообщений) **не меняется** в момент миграции — клиент-Dart должен говорить с текущим Node-сервером, чтобы можно было раскатывать клиент и сервер независимо.
4. Все 46 существующих тестов (Vitest) имели зеркало в Dart (`package:test` + `flame_test`), включая golden-детерминизм.
5. **Дизайн сохраняется на 100%:** цвета, шрифты, радиусы, тени, отступы, анимации, маскоты, темы (`neutral` / `candy` / `night`) — пиксель-в-пиксель. Это явное требование пользователя; см. §6 «Сохранение дизайна 1:1».
6. После завершения миграции **дальнейшая разработка идёт только на Dart/Flutter**; TS-кодовая база замораживается, ветка `legacy-ts` сохраняется для отката.

ТЗ § «Стек» уже рекомендует Flutter + Flame как целевой — это документ описывает *как* туда дойти.

---

## 2. Целевой стек

| Слой | Сейчас (TS) | Цель (Dart/Flutter) |
|------|-------------|---------------------|
| Языковая база | TypeScript 5.5 | Dart 3.5 (sound null safety, sealed/pattern matching) |
| UI-фреймворк | React 18 + CSS | Flutter 3.24 (Material 3 / Cupertino опционально) |
| Игровой рендер | DOM + CSS-grid (Board.tsx) | **Flame 1.18+** (CustomPainter-альтернатива возможна, но Flame даёт готовые жесты, тики, эффекты) |
| Состояние | useReducer + refs | **Riverpod 2.5** (provider + state notifier) |
| Async-поток событий | EventEmitter-style | `Stream`/`StreamController`, `riverpod` AsyncValue |
| Drag-and-drop | HTML5 Drag API + кастомный DragLayer | Flutter `Draggable`/`DragTarget` + жесты Flame |
| Анимация | CSS transitions + requestAnimationFrame | `AnimationController` + Flame Effects |
| Сеть (WS) | `partysocket` | `web_socket_channel` (универсально), `socket_channel` для web |
| Auth + sync | `firebase` JS SDK | `firebase_core` + `firebase_auth` + `cloud_firestore` (FlutterFire) |
| Звук | Web Audio API (синтез нот) | `flame_audio` для семплов; **синтез нот в Web Audio переписать на пре-рендеренные .wav** (Web Audio API из Dart недоступен напрямую — проще запечь короткие тоны в семплы оффлайн) |
| Хранилище | `localStorage` | `shared_preferences` для мелочи, **Hive** (или `isar`) для профиля/сохранёнки |
| Сервер | Node + `ws` + `tsx` | **Этап 1:** оставить как есть. **Этап 2 (опционально):** Dart `shelf` + `shelf_web_socket` |
| Тесты | Vitest | `package:test` + `flame_test` для виджетов |
| Сборка Web | Vite | Flutter Web (CanvasKit или WASM-renderer когда стабилизируется) |
| CI/CD Web | gh-pages branch | gh-pages branch (то же — `flutter build web` → `build/web` → push) |

### Архитектурный паттерн: MVVM (обязателен)

Весь Flutter-код строится по **MVVM** (Model–View–ViewModel) поверх Riverpod.
Это решение пользователя; отклоняться нельзя.

| Слой MVVM | Что это у нас | Где живёт | Правила |
|-----------|---------------|-----------|---------|
| **Model** | Pure-ядро игры + модели данных + репозитории (storage, online-клиент, auth, shop, achievements) | `lib/core/`, `lib/*/storage/`, `lib/online/client.dart`, `lib/auth/`, `lib/shop/`, `lib/achievements/` | Без Flutter/BuildContext. Ядро — детерминированное (ТЗ §6.1). |
| **ViewModel** | Riverpod-нотифайеры: держат UI-состояние, выставляют команды, дёргают Model. Аналог `useGame.ts` | `lib/game/game_notifier.dart`, `lib/online/online_notifier.dart`, и по нотифайеру на экран при необходимости | **Никакого `BuildContext`, виджетов, `dart:ui`.** Только Riverpod (`Notifier`/`AsyncNotifier`) + Model. Тестируется без виджетов. |
| **View** | Flutter-виджеты: только рисуют состояние ViewModel и пробрасывают намерения пользователя | `lib/ui/screens/`, `lib/ui/widgets/`, Flame-компоненты Board | **Никакой бизнес-логики.** `ConsumerWidget`/`ConsumerStatefulWidget` читают провайдеры. UI — классами-виджетами, не методами `_buildXxx()`. |

Поток данных однонаправленный: **View → (intent) → ViewModel → (вызов) → Model
→ (новое состояние) → ViewModel → (rebuild) → View**. View не обращается к
Model напрямую; ViewModel не знает о конкретных виджетах.

Почему MVVM + Riverpod, а не Bloc/GetX/Provider: текущий `useGame.ts` — это
reducer с side-effects (бот, blitz tick, force-place), что ровно ложится на
ViewModel-нотифайер. Riverpod даёт `Notifier`/`AsyncNotifier` + DI без
BuildContext, что и обеспечивает чистое разделение слоёв MVVM и раздельные
unit-тесты Model и ViewModel.

### Почему Flame, а не чистый Flutter

Board 9×9 рисуется часто (drag-preview, комбо-вспышки, конфетти), и Flame даёт:
- Готовый game-loop с фиксированным таймстепом (для blitz-тикинга);
- Компоненты с lifecycle (Confetti, ComboFlash, FloatingTheme — натурально ложатся);
- Дешёвый rendering клеток (один Canvas vs 81 виджет).

Меню/настройки/магазин/ачивки остаются обычными Flutter-виджетами поверх Flame-сцены (когда нужно).

---

## 3. Структура нового проекта

```
block_puzzle_pvp/                       # тот же репо, новые поддиректории
├── flutter/                            # ← новый код Flutter-приложения
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── lib/
│   │   ├── main.dart                   # ← из src/main.tsx
│   │   ├── app.dart                    # ← из src/ui/App.tsx (роутер)
│   │   ├── core/                       # ← pure Dart, зеркало src/core/
│   │   │   ├── core.dart               # барель
│   │   │   ├── types.dart              # BoardCell, Piece, RuleConfig, Move...
│   │   │   ├── rng.dart                # mulberry32
│   │   │   ├── bag.dart                # 7-bag
│   │   │   ├── board.dart              # доска, размещение, очистка
│   │   │   ├── scoring.dart            # формула очков, комбо
│   │   │   ├── moves.dart              # enumerateMoves, opponentThreatGain
│   │   │   ├── bot.dart                # 3 уровня, BOT_WEIGHTS
│   │   │   ├── timer.dart              # turnTimeForRound, forcePlace
│   │   │   └── pieces.dart             # I, O, T, S, Z, J, L + повороты
│   │   ├── game/                       # ← из src/ui/useGame.ts
│   │   │   ├── game_notifier.dart      # StateNotifier (reducer)
│   │   │   ├── game_state.dart         # immutable state
│   │   │   ├── bot_runner.dart         # setTimeout → Timer
│   │   │   └── blitz_ticker.dart
│   │   ├── ui/
│   │   │   ├── screens/                # ← src/ui/screens/*.tsx
│   │   │   │   ├── menu_screen.dart
│   │   │   │   ├── setup_screen.dart
│   │   │   │   ├── game_screen.dart
│   │   │   │   ├── profile_screen.dart
│   │   │   │   ├── settings_screen.dart
│   │   │   │   ├── tutorial_screen.dart
│   │   │   │   ├── daily_screen.dart
│   │   │   │   ├── shop_screen.dart
│   │   │   │   ├── achievements_screen.dart
│   │   │   │   ├── leaderboard_screen.dart
│   │   │   │   ├── online_menu_screen.dart
│   │   │   │   ├── online_game_screen.dart
│   │   │   │   └── result_overlay.dart
│   │   │   ├── widgets/                # ← src/ui/components/*.tsx
│   │   │   │   ├── board_widget.dart           # Flame GameWidget
│   │   │   │   ├── board_game.dart             # FlameGame с компонентами
│   │   │   │   ├── hand_widget.dart
│   │   │   │   ├── scoreboard.dart
│   │   │   │   ├── player_card.dart
│   │   │   │   ├── turn_timer.dart
│   │   │   │   ├── transform_controls.dart
│   │   │   │   ├── confetti.dart               # Flame Component
│   │   │   │   ├── combo_flash.dart            # Flame Component
│   │   │   │   ├── toast_stack.dart
│   │   │   │   ├── powerups_panel.dart
│   │   │   │   ├── pause_overlay.dart
│   │   │   │   ├── drag_layer.dart             # обёртка над Draggable
│   │   │   │   ├── mascot.dart
│   │   │   │   ├── cartoon_pony.dart           # SVG → CustomPaint
│   │   │   │   ├── floating_theme.dart
│   │   │   │   ├── theme_backdrop.dart
│   │   │   │   └── theme_switch.dart
│   │   │   ├── themes.dart             # ← src/ui/themes.ts (ThemeData + extension)
│   │   │   ├── audio/
│   │   │   │   ├── sfx.dart            # flame_audio обёртка
│   │   │   │   └── music.dart          # фоновые темы
│   │   │   ├── design_tokens.dart      # ← src/ui/themes.ts: per-theme цвета, радиусы, шрифты, веса (single source of truth)
│   │   │   ├── theme_extension.dart    # ThemeExtension<BlockDuelTheme> + ThemeData neutral/candy/night
│   │   │   ├── responsive.dart         # порты CSS clamp() + breakpoint-ы 480 / 900 / 1200 + safe area
│   │   │   └── styles.dart             # глобальные стили (взамен styles.css), все вынесены в виджет-стиль
│   │   ├── online/                     # ← src/ui/online/
│   │   │   ├── client.dart             # ← client.ts (web_socket_channel)
│   │   │   ├── online_notifier.dart    # ← useOnlineGame.ts
│   │   │   └── protocol.dart           # типы сообщений (зеркало server/types.ts)
│   │   ├── auth/                       # ← src/ui/auth/
│   │   │   ├── auth.dart               # firebase_auth Google sign-in
│   │   │   ├── firebase_init.dart      # ← firebase.ts
│   │   │   └── sync.dart               # cloud_firestore profile sync
│   │   ├── shop/
│   │   │   ├── powerups.dart
│   │   │   └── skins.dart
│   │   ├── achievements/
│   │   │   ├── definitions.dart        # ~120 achievements (data)
│   │   │   └── engine.dart
│   │   └── storage/
│   │       ├── profile_store.dart      # Hive box
│   │       ├── stats_store.dart
│   │       ├── settings_store.dart
│   │       └── save_game_store.dart    # включая drawCounts для resume 7-bag
│   ├── test/                           # ← tests/
│   │   ├── core/
│   │   │   ├── clears_test.dart
│   │   │   ├── scoring_test.dart
│   │   │   ├── bag_test.dart
│   │   │   ├── deadlock_test.dart
│   │   │   ├── determinism_test.dart   # golden (тот же seed → тот же лог)
│   │   │   └── timer_test.dart
│   │   ├── bot/
│   │   │   └── bot_test.dart
│   │   └── pilot_test.dart
│   ├── assets/
│   │   ├── audio/                      # пре-рендеренные .wav вместо Web Audio синтеза
│   │   ├── images/                     # SVG/PNG скинов, маскоты, fallback PNG
│   │   ├── fonts/                      # Bricolage Grotesque, DM Mono, Fredoka, Baloo 2, Oswald, Share Tech Mono (см. §6.3)
│   │   └── pieces/                     # необязательно, если рисуем кодом
│   ├── web/                            # Flutter Web shell (index.html, manifest)
│   ├── ios/ android/ macos/ windows/ linux/   # генерится `flutter create .`
│   └── tools/
│       └── bot_sim.dart                # ← tools/bot-sim.ts
├── server/                             # ← без изменений на Этапе 1
├── src/                                # ← заморозить после миграции
├── legacy/                             # без изменений
├── TZ_BlockDuel_9x9.md
├── ROADMAP.md
├── MIGRATION_FLUTTER.md                # этот файл
└── CLAUDE.md                           # обновить после миграции
```

**Почему в подпапке `flutter/`, а не в корне:**
- Сосуществование с TS-кодом во время миграции (можно билдить и старый сайт, и новый Flutter Web для A/B и регресса).
- `pubspec.yaml` и `package.json` в одном корне путают редакторы и хуки.
- После Этапа 7 (cut-over) — переместить содержимое `flutter/` в корень, `src/` → `legacy-ts/`.

---

## 4. Маппинг файлов TS → Dart

### 4.1 Ядро (`src/core/index.ts` → `flutter/lib/core/`)

Текущий `index.ts` — 611 строк, всё в одном файле. Разбиваем на ~9 файлов (см. структуру выше).

| TS | Dart | Заметки |
|----|------|---------|
| `type BoardCell = 0 \| 1 \| 2 \| 3` | `typedef BoardCell = int` (или `enum`) | enum даёт type safety, но int быстрее в массивах |
| `interface Piece` | `class Piece` (immutable, `@immutable`) | + `==`/`hashCode` через `equatable` или `freezed` |
| `interface RuleConfig` | `class RuleConfig` через `freezed` | freezed → `copyWith`, JSON, value-equality |
| `mulberry32(seed)` | `Mulberry32(seed)` class | **Критично:** битовые операции должны давать тот же результат, что в JS (см. §7) |
| `makeBag(rng, sharedBag)` | `Bag(rng: Rng, shared: bool)` | хранит `drawCounts` для детерминистичного resume |
| `enumerateMoves(board, piece)` | `List<Move> enumerateMoves(board, piece)` | hot path — профилировать |
| `botMove(state, level)` | `Move botMove(GameState, BotLevel)` | `BOT_WEIGHTS` — `const Map<BotLevel, BotWeights>` |
| `turnTimeForRound(round, cfg)` | `double turnTimeForRound(int round, RuleConfig cfg)` | без изменений |
| `forcePlace(state)` | `GameState forcePlace(GameState)` | без изменений |
| `DEFAULT_CONFIG` | `static const DEFAULT_CONFIG = RuleConfig(...)` | **держать синхронным с ТЗ § 15** |

**Запрещено в `core/`:**
- `dart:io` (нет файлов/сети);
- `dart:html` / `package:flutter` (нет UI);
- `DateTime.now()`, `Random()` (без переданного RNG);
- любые async без явного контракта — ядро остаётся синхронным, как сейчас.

### 4.2 Хук `useGame.ts` (937 строк) → `flutter/lib/game/game_notifier.dart`

Самый сложный кусок. Текущий useReducer + refs → Riverpod `StateNotifier<GameState>`:

```dart
@riverpod
class GameNotifier extends _$GameNotifier {
  late final Mulberry32 _rng;
  late final Bag _bag;
  Timer? _botTimer;
  Timer? _blitzTicker;

  @override
  GameState build(MatchConfig cfg) { ... }

  void placePiece(Move move) { ... }
  void rotatePiece(int handIndex) { ... }
  void usePowerup(PowerupId id) { ... }
  // ...
}
```

Бот через `setTimeout` → `Timer(Duration(milliseconds: ...), ...)`.
Blitz tick 100мс → `Timer.periodic`.

### 4.3 UI

| TS компонент | Flutter эквивалент | Заметки |
|--------------|--------------------|---------|
| `App.tsx` + роутинг | `go_router` | screen ↔ route 1:1 |
| `Board.tsx` (DOM grid) | `BoardGame extends FlameGame` + `BoardWidget` | Flame для рисования, виджет — обёртка |
| `Hand.tsx` | `HandWidget` (`Row` + `Draggable`) | каждый piece — `Draggable<Move>` |
| `DragLayer.tsx` | встроено в `Draggable.feedback` | отдельный слой не нужен |
| `TransformControls.tsx` | `Row` с `IconButton`-ами | |
| `Confetti.tsx` | `ConfettiComponent extends Component` (Flame) | Particle Effects |
| `ComboFlash.tsx` | `ComboFlashComponent` (Flame) | OpacityEffect + ScaleEffect |
| `ToastStack.tsx` | `OverlayEntry` + `flutter_animate` | |
| `ThemeSwitch.tsx` + `themes.ts` | `Theme.of(context).extension<BlockDuelTheme>()` | кастомный ThemeExtension |
| `audio.ts` (Web Audio синтез) | **переписать:** запечь короткие тоны в .wav, грузить через `flame_audio` | синтез нот рантайм в Dart на всех платформах сложен |
| `music.ts` | `flame_audio.bgm` | поддерживает loop |
| `styles.css` | `lib/ui/styles.dart` + `Theme.of` | CSS-переменные → ThemeExtension |

### 4.4 Онлайн (`src/ui/online/`)

| TS | Dart |
|----|------|
| `client.ts` (partysocket) | `OnlineClient` поверх `WebSocketChannel.connect(uri)` |
| `useOnlineGame.ts` | `OnlineNotifier` (Riverpod AsyncNotifier) |
| Протокол сообщений | **Не менять.** JSON-схема та же, что у сервера. |

**Совместимость:** клиент-Dart подключается к текущему Node-серверу на `pvp.alshfu.com`. Это позволяет раскатать новый клиент не трогая сервер.

### 4.5 Auth + sync

| TS | Dart |
|----|------|
| `firebase.ts` (initializeApp) | `firebase_core` + `firebase_options.dart` (генерится `flutterfire configure`) |
| `auth.ts` (Google sign-in) | `firebase_auth` + `google_sign_in` (на mobile), для web — popup |
| `sync.ts` (Firestore) | `cloud_firestore` |

**Важно:** существующие данные пользователей в Firestore остаются. Схема документа не меняется — DAO в Dart мапит ровно те же поля.

### 4.6 Сервер

**Этап 1 миграции:** Node-сервер остаётся как есть. Это сокращает риск и поверхность изменений.
**Этап 2 (опционально, после стабилизации клиента):** переписать на Dart `shelf` + `shelf_web_socket` + импорт того же `core/` пакета — это устранит дублирование Move validation между клиентом и сервером, что было бы большим выигрышем.

Если на Этапе 2 переходим — выделить ядро в отдельный pub-пакет `core/` в monorepo (`melos`), чтобы клиент Flutter и сервер Dart импортировали один и тот же код. **Это самый сильный аргумент за миграцию сервера**: сейчас core продублирован (TS-импорт работает, но при разделении на Dart-сервер потребуется shared package в любом случае).

---

## 5. Зависимости (`flutter/pubspec.yaml`)

```yaml
name: block_duel
description: Competitive 9x9 block puzzle
publish_to: none
version: 2.0.0+1                       # major bump — миграция

environment:
  sdk: ^3.5.0
  flutter: ^3.24.0

dependencies:
  flutter:
    sdk: flutter
  flame: ^1.18.0
  flame_audio: ^2.10.0

  # State
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Data
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  equatable: ^2.0.5

  # Storage
  shared_preferences: ^2.3.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.4

  # Network
  web_socket_channel: ^3.0.1
  http: ^1.2.2

  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  google_sign_in: ^6.2.1

  # Routing
  go_router: ^14.2.7

  # Design (см. §6)
  google_fonts: ^6.2.1                # все 6 шрифтов из themes.ts — оффлайн-бандл через assets/fonts
  flutter_svg: ^2.0.10                # mascots, favicon, иконки
  vector_graphics: ^1.1.11            # AOT-компиляция SVG для перфоманса
  flutter_animate: ^4.5.0             # декларативные анимации (CSS-keyframes эквивалент)
  flutter_displaymode: ^0.6.0         # 120Hz/ProMotion (Android/iOS)

  # Utils
  collection: ^1.18.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flame_test: ^1.18.0
  test: ^1.25.0
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.3
  hive_generator: ^2.0.1
  flutter_lints: ^4.0.0
  custom_lint: ^0.6.7
  riverpod_lint: ^2.3.13

flutter:
  uses-material-design: true
  assets:
    - assets/audio/
    - assets/images/
  fonts:
    # Шрифты бандлятся локально (не подтягиваем через google_fonts runtime),
    # чтобы оффлайн и PWA-кэш работали корректно; имена FontFamily должны
    # точно соответствовать упоминаниям в themes.ts (см. §6.3).
    - family: BricolageGrotesque
      fonts:
        - asset: assets/fonts/BricolageGrotesque-Regular.ttf
        - asset: assets/fonts/BricolageGrotesque-Bold.ttf
          weight: 800
    - family: DMMono
      fonts:
        - asset: assets/fonts/DMMono-Regular.ttf
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
        - asset: assets/fonts/Fredoka-SemiBold.ttf
          weight: 700
    - family: Baloo2
      fonts:
        - asset: assets/fonts/Baloo2-Regular.ttf
    - family: Oswald
      fonts:
        - asset: assets/fonts/Oswald-Regular.ttf
        - asset: assets/fonts/Oswald-Bold.ttf
          weight: 700
    - family: ShareTechMono
      fonts:
        - asset: assets/fonts/ShareTechMono-Regular.ttf
```

---

## 6. Сохранение дизайна 1:1 (КРИТИЧНО)

Дизайн — **отдельный артефакт**, который нельзя «приблизительно повторить». Текущая реализация — 868 строк CSS, 3 темы (`neutral`, `candy`, `night`) с разными радиусами/шрифтами/цветами, ручные SVG-маскоты (`CartoonPony` — 197 строк), декоративные слои (`FloatingTheme`, `ThemeBackdrop`), эффекты (`Confetti`, `ComboFlash`), fluid typography через `clamp()`, безопасные зоны iOS (`env(safe-area-inset-*)`), `100dvh`-вёрстка, breakpoints `480/900/1200`. Всё это переносим **без визуальных изменений**.

### 6.1 Дизайн-токены — single source of truth

Создаём `lib/ui/design_tokens.dart` как **прямой порт** `src/ui/themes.ts` — каждое значение цвета/радиуса/шрифта копируется hex-в-hex / px-в-px:

```dart
@immutable
class BlockDuelTheme extends ThemeExtension<BlockDuelTheme> {
  final Color bg, bg2, panel, panel2, line;
  final Color ink, muted;
  final Color p0, p0d, p1, p1d;
  final Color good, bad, cell, cellLine;
  final double boardRadius, cardRadius, btnRadius, cellRadius, miniRadius;
  final String fontDisplay, fontMono;
  final FontWeight displayWeight;
  final double displaySpacing;
  final Brightness kind;
  // ...
  static const neutral = BlockDuelTheme(
    bg: Color(0xFF0E1116), bg2: Color(0xFF0B0E13),
    panel: Color(0xFF161B22), /* ... */
    boardRadius: 18, cardRadius: 14, btnRadius: 10, cellRadius: 5, miniRadius: 4,
    fontDisplay: 'BricolageGrotesque', fontMono: 'DMMono',
    displayWeight: FontWeight.w800, displaySpacing: -0.01,
    kind: Brightness.dark,
  );
  static const candy = BlockDuelTheme(/* hex-в-hex из themes.ts */);
  static const night = BlockDuelTheme(/* hex-в-hex из themes.ts */);
}
```

**Правило:** ни одна цифра из `themes.ts` или `styles.css` не вводится «на глаз». Если в CSS `--p0: #ff9d42` — в Dart `Color(0xFFFF9D42)`. Расхождение даже на 1 единицу значит регресс дизайна.

### 6.2 Запекание CSS-переменных по компонентам

Компонентные стили из `styles.css` (`.pcard`, `.board`, `.hand`, `.cell`, `.combo-flash` и т.п.) переносятся **в соответствующие виджеты**, не в один глобальный «styles.dart». Это идиоматичный Flutter и сохраняет локальность дизайна.

Маппинг:

| `styles.css` селектор | Куда в Flutter |
|----------------------|----------------|
| `.app-root`, `body` | `MaterialApp.theme.scaffoldBackgroundColor` + `ThemeData` |
| `.phone` (frame `max-width:460/680/760`) | `lib/ui/responsive.dart` — `PhoneFrame` widget |
| `.backdrop` | `ThemeBackdrop` (`Stack` base layer) |
| `.screen` / `.game-screen` | `Scaffold` body + `SafeArea` + `Padding` |
| `.board`, `.cell`, `.cell.ghost-*` | `BoardWidget` / `BoardGame` (Flame) |
| `.hand`, `.hand-slot`, `.mini-piece` | `HandWidget`, `MiniPieceWidget` |
| `.pcard`, `.pcard-score`, `.dot` | `PlayerCard` widget |
| `.turn-timer`, `.tt-num`, `.turn-pill` | `TurnTimer` widget |
| `.combo-flash`, `.combo-flash-title` | `ComboFlashComponent` (Flame) с тем же FontSize-clamp |
| `.tc-btn`, `.hero-btn`, `.btn` | `lib/ui/widgets/buttons.dart` |
| `.logo.big`, `.logo.mini` | `Logo` widget |

### 6.3 Шрифты

В `themes.ts` 6 разных Google Fonts. Все **бандлятся в `assets/fonts/`** (а не подтягиваются через `google_fonts` runtime), чтобы:
- работало оффлайн (PWA, mobile без интернета);
- не было FOUT/FOIT при первом запуске;
- сетка/метрики были одинаковыми на всех платформах.

**Action item Фазы 0:** скачать TTF-файлы с Google Fonts (Bricolage Grotesque, DM Mono, Fredoka, Baloo 2, Oswald, Share Tech Mono), положить в `flutter/assets/fonts/`, прописать в `pubspec.yaml` (см. §5). Имена `family:` в pubspec должны 1:1 соответствовать строкам `fontDisplay`/`fontMono` в `BlockDuelTheme`.

### 6.4 Fluid typography (`clamp()`)

В CSS использован `clamp(min, vw, max)` — например `font-size: clamp(36px, 6.5vw, 58px)` для `.logo.big`. У Flutter нет встроенного эквивалента — реализуем хелпер в `lib/ui/responsive.dart`:

```dart
double clampFontSize(BuildContext ctx, {required double min, required double prefVw, required double max}) {
  final w = MediaQuery.sizeOf(ctx).width;
  return (w * prefVw / 100).clamp(min, max);
}
```

И таблицу `lib/ui/responsive.dart` с теми же 18 `clamp()`-правилами из `styles.css` (логотип, тайминг таймера, score, и т.п.) — копируем построчно.

### 6.5 Breakpoints и safe area

CSS `@media (min-width: 480px / 900px / 1200px)` → `LayoutBuilder` + константы `kBpPhone = 480`, `kBpTablet = 900`, `kBpDesktop = 1200`.

CSS `env(safe-area-inset-bottom)` → `SafeArea(bottom: true)` + `MediaQuery.viewPaddingOf(context).bottom`.

CSS `100dvh` (динамическая высота viewport, учитывающая mobile chrome) → на Flutter Web дополнительно вешаем JS-snippet в `web/index.html`, который проставляет `--vh` через `window.visualViewport`, и используем его в SizedBox-обёртке. На native — обычный `Scaffold` уже учитывает inset.

### 6.6 Маскоты и декоративная графика

| Источник (TS/CSS/SVG) | Перенос в Flutter |
|-----------------------|--------------------|
| `CartoonPony.tsx` (197 строк SVG inline) | **Вариант A (рекомендуется):** экспорт SVG → `assets/images/pony.svg` → `SvgPicture.asset` через `flutter_svg`. Параметризация цветов тела/гривы — через перекрашивание группы SVG (используем `vector_graphics` для AOT) или 3 версии. **Вариант B:** портировать SVG-paths в `CustomPainter` (полный контроль, но больше работы) |
| `Mascot.tsx` | Аналогично — SVG + `flutter_svg` |
| `FloatingTheme.tsx` (анимированные декоры) | `Stack` + `AnimatedBuilder` + `Transform` (или Flame `Component` если поверх Board) |
| `ThemeBackdrop.tsx` (градиенты + блюр) | `CustomPaint` + `BackdropFilter` + `RadialGradient` |
| `Confetti.tsx` | Flame `ParticleSystemComponent` |
| `ComboFlash.tsx` | Flame `Component` с `OpacityEffect` + `ScaleEffect` |
| `public/favicon.svg` | `assets/images/favicon.svg` + Web manifest |

### 6.7 Анимации и тайминги

CSS-transitions/keyframes → `flutter_animate` (декларативный API, очень близок к CSS-классам). Каждая анимация портируется с тем же `duration`/`curve`:

- CSS `transition: .4s ease` (backdrop swap) → `.fadeIn(duration: 400.ms, curve: Curves.ease)`
- CSS `@keyframes` (вспышки combo) → `.scale(begin: .8, end: 1.2)` + `.fadeOut`
- Hover/active состояния → `MouseRegion` + `StatefulWidget` (web/desktop)

**Правило:** длительности и easing-curve копируются миллисекунда-в-миллисекунду. Если в CSS `cubic-bezier(.2, .8, .2, 1)` — в Flutter `Curves.easeOutCubic` (либо точный `Cubic(.2, .8, .2, 1)` — последнее предпочтительнее).

### 6.8 Скриншот-тесты (golden) дизайна

Чтобы дизайн не «уехал» в процессе миграции — заводим **golden screenshot тесты** на ключевые экраны:

- `test/golden/menu_neutral.png`
- `test/golden/menu_candy.png`
- `test/golden/menu_night.png`
- `test/golden/game_neutral_midgame.png`
- `test/golden/result_overlay_win.png`
- ... (минимум 12 артефактов = 4 экрана × 3 темы)

Эталоны генерируются **из текущей TS-версии** (Playwright скриншоты в детерминированном состоянии, фиксированный seed). Каждая Dart-сборка сверяется с эталоном через `flutter_test` `matchesGoldenFile` с допуском 0% (или ≤1px для anti-aliasing).

### 6.9 Acceptance gate дизайна

Перед мержем **любой** фазы UI (2, 4, 5, 7) проводится визуальная сверка:
1. Открыть текущую TS-версию и Dart-версию рядом, в каждой из 3 тем.
2. Проверить чеклист: цвета совпадают (color-picker), радиусы совпадают (DevTools inspector / Flutter Inspector), шрифты те же, иконки/маскоты на месте, анимации той же длительности, layout идентичен в breakpoints 360/480/900/1200.
3. Golden-screenshot тесты проходят (см. 6.8).

Если хотя бы один пункт фейлит — фаза не принимается, доделываем.

---

## 7. Сохранение детерминизма ядра (КРИТИЧНО)

ТЗ § 6.1 и `CLAUDE.md` требуют: то же `(matchSeed, RuleConfig, moveLog)` → то же state. Это нужно для:
- golden-тестов;
- server-authoritative онлайна (сервер реплеит ходы и валидирует);
- сохранёнок (resume in-place);
- анти-чита.

### 7.1 Подводные камни перевода TS → Dart

| Тема | JS/TS | Dart | Что делать |
|------|-------|------|-----------|
| Целочисленные битовые операции | 32-bit signed, через `\| 0`, `>>> 0` | int — 64-bit на VM, JS-numbers на Web → возможны расхождения VM↔Web | Использовать `int` + явные маски `& 0xFFFFFFFF`, тестировать на **обоих** таргетах (VM и Web) |
| `Math.imul` | builtin | нет | реализовать вручную: `(a & 0xFFFF) * b + ((a >> 16) * (b & 0xFFFF) << 16) & 0xFFFFFFFF` или использовать пакет `fixnum` |
| Деление вещественных | IEEE 754 | IEEE 754 | OK, но на Web Dart-double → JS-number, идентичность не гарантирована для длинных цепочек. Для PRNG это **не нужно** — мы возвращаем `int / 2^32`, что эквивалентно. |
| Порядок итерации `Map` | insert-order | LinkedHashMap insert-order | OK |
| Сортировка | stable (ES2019+) | не гарантирована стабильность | заменить на `package:collection` `mergeSort` где порядок важен |
| Сериализация JSON для seed | `JSON.stringify({a:1})` детерминистичен по полям | `jsonEncode` не гарантирует порядок ключей | если хэшируем JSON — сортировать ключи вручную |

### 7.2 Контракт детерминизма

Написать в `core/` тест `determinism_test.dart`, который:
1. Берёт **тот же golden seed**, что текущий `tests/determinism.test.ts`.
2. Прогоняет ту же последовательность ходов.
3. Сверяет финальное состояние **байт-в-байт** с дампом из TS-версии.

Если расхождение — **миграция блокируется**, пока не починим PRNG/bag.

Дамп TS-версии готовим на Этапе 1 (см. §8): сохраняем `JSON.stringify(state)` в файл, коммитим в репо как `flutter/test/golden/determinism_match.json`.

---

## 8. Фазы миграции

Каждая фаза — отдельный PR (или серия), с зелёными тестами **по обоим стекам** до cut-over.

### Фаза 0 — подготовка (1–2 дня)
- [ ] Этот документ закоммичен и согласован.
- [ ] Установлен Flutter SDK 3.24, проверены целевые платформы (`flutter doctor`).
- [ ] **IntelliJ IDEA Ultimate** настроена: плагины **Flutter** + **Dart** + **Android** (Settings → Plugins → Marketplace). Указан путь Flutter SDK в Settings → Languages & Frameworks → Flutter. Создан Run Configuration `flutter run -d chrome` и `flutter run -d <ios-sim>`. Включён Hot Reload (Ctrl+\\ / Cmd+\\).
- [ ] Xcode установлен (для iOS-симулятора, нужен на macOS), Android SDK через Android-плагин в IDEA (без отдельной Android Studio).
- [ ] Создан скелет `flutter/` через `flutter create --org com.alshfu --platforms web,ios,android,macos,windows,linux .`.
- [ ] Добавлен `pubspec.yaml` (см. §5), `flutter pub get` зелёный.
- [ ] Настроен `analysis_options.yaml` (включая `riverpod_lint`).
- [ ] **Дизайн-подготовка (см. §6):** скачаны 6 TTF-шрифтов в `assets/fonts/`; экспортированы SVG `CartoonPony` / `Mascot` / `favicon` в `assets/images/`; собраны эталонные screenshot-ы текущей TS-версии в 3 темах через Playwright → `flutter/test/golden/source/*.png`.
- [ ] Сгенерирован `flutter/test/golden/determinism_match.json` из текущего TS-ядра (одноразовый скрипт `tools/dump-golden.ts`).
- [ ] Заведена ветка `flutter-migration`. Основной разработки на ней нет — мерж в `main` поэтапно.

### Фаза 1 — портирование ядра (3–5 дней)
- [ ] `core/types.dart` + `freezed` для immutable.
- [ ] `core/rng.dart` — mulberry32 + unit-тесты на **5+ известных seed → известная последовательность** (взять из TS).
- [ ] `core/pieces.dart` — формы + повороты (статика, можно сверить с TS-дампом).
- [ ] `core/board.dart` — placement + clears + perfect clear.
- [ ] `core/scoring.dart` — формула, комбо-cap.
- [ ] `core/bag.dart` — 7-bag, `sharedBag=false`, `drawCounts` для resume.
- [ ] `core/moves.dart` — enumerateMoves, opponentThreatGain.
- [ ] `core/bot.dart` — 3 уровня + `BOT_WEIGHTS` **идентичны TS**.
- [ ] `core/timer.dart` — turnTimeForRound + forcePlace.
- [ ] Зеркало всех 46 тестов из `tests/` → `flutter/test/`.
- [ ] **Golden-тест проходит.**
- [ ] `dart run flutter/tools/bot_sim.dart --games 1000` даёт ~то же распределение win-rate, что Node-версия (±2% из-за RNG-микроразниц допустимо? — нет, должно быть бит-в-бит).

**Gate:** без зелёного golden-теста дальше не идём.

### Фаза 2 — UI shell + Board + design tokens (4–5 дней)
- [ ] `main.dart` + `app.dart` + `go_router`.
- [ ] **`lib/ui/design_tokens.dart`** — все 3 темы как `BlockDuelTheme` (см. §6.1), цвета/радиусы/шрифты 1:1 из `themes.ts`. Unit-тест на каждое поле — должен совпасть с hex-значением CSS-переменной.
- [ ] **`lib/ui/responsive.dart`** — clamp-хелперы, breakpoints, PhoneFrame (см. §6.4–6.5).
- [ ] Подключение шрифтов через `pubspec.yaml` (см. §6.3) + smoke-тест: TextStyle с `fontFamily: 'BricolageGrotesque'` рендерится корректно на всех платформах.
- [ ] `MenuScreen` — полный визуал, не только навигация. **Golden-тест на MenuScreen во всех 3 темах должен совпасть с эталоном из TS (см. §6.8).**
- [ ] `GameScreen` с `BoardGame` (Flame) и `HandWidget` — визуально соответствует TS.
- [ ] `GameNotifier` (Riverpod) поверх `core/`.
- [ ] Drag-and-drop размещения piece (с feedback-визуалом ghost-good/ghost-bad как в `.cell.ghost-*`).
- [ ] Rotate/flip контролы (`TransformControls` идентичен по виду).

**Gate:** (1) hot-seat матч до тупика играется на iOS/Android/Web; (2) golden-тест MenuScreen во всех 3 темах проходит; (3) визуальная сверка дизайна с TS-версией пройдена (см. §6.9).

### Фаза 3 — бот, blitz, force-place (1–2 дня)
- [ ] `BotRunner` (Timer-based, как `setTimeout`).
- [ ] `BlitzTicker` (Timer.periodic 100ms).
- [ ] `ForcePlace` интеграция при таймауте.
- [ ] vs Bot все 3 уровня играбельны.

### Фаза 4 — Storage + Profile + Achievements (2–3 дня)
- [ ] Hive boxes для profile/stats/save.
- [ ] `ProfileScreen`, `SettingsScreen`.
- [ ] `achievements/definitions.dart` (~120) + `engine.dart`.
- [ ] `AchievementsScreen`.
- [ ] Daily quests (`DailyScreen`).
- [ ] Resume игры из save (включая 7-bag через `drawCounts`).

### Фаза 5 — декоративный слой, анимации, звук (3–5 дней)
*Дизайн-токены уже в Фазе 2 — здесь добавляем «вишенки»: декор/анимации/звук.*
- [ ] `Mascot`, `CartoonPony` через `SvgPicture.asset` (`flutter_svg` + `vector_graphics` AOT). Параметризация цветов тела/гривы — через перекрашивание SVG-групп.
- [ ] `FloatingTheme` — анимированные декоративные элементы поверх backdrop (`AnimatedBuilder` + `Transform`).
- [ ] `ThemeBackdrop` — градиенты, блюр, особенности per-theme (candy = блёстки, night = неон-нуар).
- [ ] `ConfettiComponent` (Flame ParticleSystem) — идентичный по плотности/скорости/цвету.
- [ ] `ComboFlashComponent` (Flame + OpacityEffect + ScaleEffect) — те же длительности и font-size-clamp по уровням 1/2/3.
- [ ] `ToastStack`, `PauseOverlay`, `ResultOverlay` — анимации появления/исчезновения через `flutter_animate` с теми же `duration`/`curve`.
- [ ] Все CSS-transitions портированы с точными таймингами (см. §6.7).
- [ ] Запечь .wav семплы из Web Audio синтеза (одноразовый скрипт в браузере → скачать → положить в `assets/audio/`).
- [ ] `flame_audio` SFX + bgm — те же звуки, те же громкости.
- [ ] **Полная визуальная сверка с TS-версией (см. §6.9)** во всех 3 темах: golden-тесты на 12+ экранов проходят с допуском ≤1px.

**Gate:** дизайн принят на 100% — побочный аудит пользователя или Claude в режиме review подтверждает pixel-parity.

### Фаза 6 — Online PvP + Auth + Sync (3–4 дня)
- [ ] `OnlineClient` поверх `web_socket_channel`. **URL берётся из --dart-define** (аналог `VITE_PARTY_HOST`).
- [ ] `OnlineNotifier` (Riverpod AsyncNotifier).
- [ ] `OnlineMenuScreen`, `OnlineGameScreen`, `LeaderboardScreen`.
- [ ] FlutterFire: `flutterfire configure` → `firebase_options.dart`.
- [ ] Google sign-in (web popup + native flow).
- [ ] Firestore sync (та же схема документа).
- [ ] Тест: матч новый-клиент vs старый-клиент идёт корректно (проверка протокол-совместимости).

### Фаза 7 — Shop + Power-ups (1–2 дня)
- [ ] `shop/powerups.dart`, `shop/skins.dart`.
- [ ] `ShopScreen`.
- [ ] `PowerupsPanel` + интеграция в `GameNotifier`.

### Фаза 8 — Cut-over (1 день)
- [ ] Перенести `flutter/*` в корень репо.
- [ ] `src/` → `legacy-ts/` (или удалить — git хранит историю).
- [ ] Обновить `package.json` → удалить frontend-зависимости, оставить только серверные (если оставляем Node).
- [ ] Обновить `CLAUDE.md`: новый стек, новые команды, новая структура.
- [ ] Обновить `DEPLOY.md`: `flutter build web --release --base-href /block_puzzle_pvp/` → `build/web` → `gh-pages`.
- [ ] Обновить `ROADMAP.md`: фазы 5-11 переписать под Dart.
- [ ] Закрыть ветку `legacy-ts` тегом `v1.6.1-final-ts` для отката.

### Фаза 9 (опционально) — Dart-сервер (3–4 дня)
- [ ] Вынести `core/` в pub-пакет (monorepo через `melos`).
- [ ] `server-dart/` с `shelf` + `shelf_web_socket`.
- [ ] Импорт того же `core/` для валидации ходов.
- [ ] ELO + лидерборд (зеркало Node-версии).
- [ ] Канареечный деплой на VPS (порт 2000), миграция трафика через nginx upstream.
- [ ] Снос Node-сервера после недели стабильности.

---

## 9. Платформенные особенности

### 9.1 Web
- **Renderer:** CanvasKit (по умолчанию) — даёт стабильный рендер Flame, но +2МБ к бандлу. Альтернатива — HTML renderer (легче, но Flame работает хуже). Когда Flutter WASM-renderer стабилизируется (вероятно 2026) — переключиться.
- **Base href:** `/block_puzzle_pvp/` для GitHub Pages.
- **PWA:** Flutter Web из коробки даёт `manifest.json` + service worker. Сохранить иконки/manifest от текущей версии.
- **Firebase Auth Web:** требует `firebase-auth-compat.js` + popup-flow. Проверить cross-origin для Pages.

### 9.2 iOS / Android
- **Firebase:** `flutterfire configure` сгенерирует `GoogleService-Info.plist` / `google-services.json`. **Положить в .gitignore**, как и сейчас.
- **Google Sign-In Android:** SHA-1 ключа подписи нужно зарегистрировать в Firebase Console.
- **iOS minimum:** iOS 13+ (Flutter requirement).
- **Android minSdk:** 21+ (Flutter 3.24 default).

### 9.3 Desktop (macOS / Windows / Linux)
- В принципе работают «бесплатно», но онлайн через WS требует SSL для production (есть, через nginx).
- Firebase Auth на desktop — частично; Google sign-in на Linux/Windows ограничен. Для desktop-релиза, возможно, оставить только anonymous + Apple/Microsoft sign-in, или ограничиться offline режимом.
- **Решение:** desktop поддерживать «as-is», но в публичный релиз не выкладывать на Этапе 8 — только Web + iOS + Android.

---

## 10. Тестирование

### 10.1 Unit-тесты ядра
- Зеркало всех 46 Vitest-тестов на `package:test`.
- Прогон в двух режимах: VM (`dart test`) и Web (`dart test -p chrome`) — чтобы поймать расхождения 32/64-bit.

### 10.2 Виджет-тесты
- `flutter_test` для экранов.
- `flame_test` для `BoardGame` компонентов.

### 10.3 Integration / e2e
- Текущие Playwright-тесты переписать на `integration_test` (Flutter) для web/mobile.

### 10.4 Performance
- `flutter run --profile` + DevTools для board-рендера.
- Целевой FPS: 60 на iPhone 12 / Pixel 5 / десктоп. Если Flame проседает — переключить board на чистый `CustomPaint` (меньше overhead на 81 клетке).

### 10.5 Регресс-тестирование online
- Перед мержем Фазы 6: матч новый-Dart-клиент vs старый-TS-клиент (через прод-сервер) — должен идти без расхождений.
- Сценарии: dropdown в середине матча, reconnect, timeout, forcePlace.

---

## 11. CI / CD

### 11.1 GitHub Actions (workflow выключен из-за биллинга — решение пользователя)
Если/когда разблокируется:
```yaml
# .github/workflows/flutter-ci.yml
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0', channel: stable }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: dart test -p chrome  # для core/ на Web
  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
      # ... flutter build web --base-href /block_puzzle_pvp/
      # ... peaceiris/actions-gh-pages
```

### 11.2 Локальный деплой Web (взамен `npm run deploy`)
```bash
cd flutter
flutter test
flutter build web --release --base-href /block_puzzle_pvp/ \
  --dart-define=PARTY_HOST=pvp.alshfu.com
npx gh-pages -d build/web -m "deploy: $(date -u +%FT%TZ)"
```

### 11.3 Сервер (Этап 1)
Без изменений: `git pull && systemctl restart blockduel-pvp` на VPS, как сейчас (делает пользователь).

---

## 12. Риски и митигация

| Риск | Вероятность | Митигация |
|------|-------------|-----------|
| PRNG/golden не сходится бит-в-бит | средняя | Гейт Фазы 1; написать дамп TS-state ДО начала Dart-портирования, использовать `package:fixnum` Int32 при сомнениях |
| Flame на Web проседает по FPS | низкая | Готов fallback на чистый CustomPaint; board — всего 81 клетка, рендер дешёвый |
| Web Audio синтез не повторить в Dart | средняя | Запечь .wav оффлайн (одноразово в браузере), сложить в assets |
| FlutterFire web ↔ existing Firestore схема не совпадёт | низкая | Схема не меняется, поля те же — проверить DAO 1:1 |
| Drag-and-drop UX хуже, чем сейчас | средняя | Прототипировать в Фазе 2; Flutter Draggable + custom feedback обычно лучше HTML5 DnD на mobile |
| Размер Web-бандла вырос | высокая | CanvasKit +2МБ — терпимо для one-time download + service worker кэширует; альтернатива — HTML renderer на Web (хуже выглядит) |
| Десктопные платформы тянут вниз | средняя | Не релизить desktop на Этапе 8, добавить позже |
| Сломаем существующих игроков онлайна | средняя | Не менять WS-протокол на Этапе 6; новый клиент должен играть со старым |
| Миграция растягивается на 2 месяца | высокая | Чёткие фазы с gate; не начинать Фазу N+1 пока N не зелёная |
| **Дизайн «уезжает»: шрифт рендерится иначе, цвета чуть тусклее, радиусы не совпадают** | **высокая** | §6: дизайн-токены 1:1 из CSS, бандленные TTF, CanvasKit renderer на Web, golden-screenshot тесты в 3 темах, ручная сверка в §6.9 перед мержем Фаз 2/5 |
| Шрифты разных Google Fonts недоступны на отдельных платформах | низкая | Бандлим все 6 TTF в assets, не полагаемся на runtime google_fonts |
| SVG-маскоты выглядят иначе (Flutter SVG renderer ≠ браузерный) | средняя | `vector_graphics` AOT + golden-тесты; в крайнем случае — CustomPainter для `CartoonPony` |

---

## 13. Что **не** портируем

- `legacy/` — игнор, не трогаем.
- `party/*.ts` + `partykit.json` — PartyKit-вариант сервера, и сейчас не используется; удалить или оставить inert.
- `.github/workflows/deploy.yml.disabled` — оставить выключенным (биллинг).
- `tools/bot-sim.ts` — портируем (`tools/bot_sim.dart`), полезен для калибровки.

---

## 14. Команды после миграции (раздел в новом CLAUDE.md)

Все команды работают **из IntelliJ IDEA Ultimate** через Run Configurations или Terminal panel (Alt+F12). Hot Reload — Cmd+\\ / Ctrl+\\. Hot Restart — Shift+Cmd+\\. Flutter Inspector — View → Tool Windows → Flutter Inspector. Dart DevTools — открывается из toolbar после `flutter run`.

```bash
cd flutter

flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # генерация freezed/riverpod/hive

flutter run -d chrome                          # web dev (Run в IDEA: Chrome target)
flutter run -d "iPhone 15"                     # iOS simulator (Xcode должен быть установлен)
flutter run -d emulator-5554                   # Android emulator (через AVD Manager в IDEA Android plugin)
flutter run -d macos                           # desktop

flutter analyze                                # IDEA подсвечивает то же в реальном времени
flutter test                                   # все Dart-тесты (IDEA: правый клик по test/ → Run)
flutter test --update-goldens                  # обновить golden-screenshot эталоны (см. §6.8)
dart test -p chrome test/core                  # core тесты на Web (детерминизм)

flutter build web --release --base-href /block_puzzle_pvp/ \
  --dart-define=PARTY_HOST=pvp.alshfu.com
flutter build ipa --release
flutter build apk --release
flutter build appbundle --release              # для Play Store

# Деплой Web (Pages):
npx gh-pages -d build/web

# Сервер (Этап 1, без изменений):
npm run server:dev
```

### IntelliJ IDEA Ultimate — Run Configurations (зафиксировать в `.idea/runConfigurations/` и закоммитить)

- `Flutter (Web)` — target Chrome, `--web-port 5173` (тот же что Vite, чтобы не путаться при сравнении со старой версией)
- `Flutter (iOS)` — target iPhone 15 simulator
- `Flutter (Android)` — target Pixel 5 emulator
- `Flutter Test (all)` — `flutter test`
- `Flutter Test (core)` — `dart test test/core`
- `Generate (build_runner)` — `flutter pub run build_runner build --delete-conflicting-outputs`
- `Update Goldens` — `flutter test --update-goldens`

---

## 15. Чеклист (top-level)

- [ ] §3 структура проекта согласована
- [ ] §5 pubspec.yaml зафиксирован
- [ ] §6 дизайн-стратегия одобрена; эталонные screenshot-ы и шрифты собраны
- [ ] Фаза 0: skeleton + IDE настроена + golden dump из TS + дизайн-эталоны
- [x] Фаза 1: ядро Dart + golden детерминизма зелёный
- [x] Фаза 2: UI shell + design tokens + Board + hot-seat играется (golden MenuScreen — отложен)
- [x] Фаза 3: бот + blitz
- [x] Фаза 4: storage + ачивки + daily + resume
- [ ] Фаза 5: декор + анимации + звук + **полный pixel-parity дизайна**
- [ ] Фаза 6: online + auth + sync, кросс-протокол OK
- [ ] Фаза 7: shop + powerups
- [ ] Фаза 8: cut-over, CLAUDE/ROADMAP/DEPLOY обновлены
- [ ] Фаза 9 (опц.): Dart-сервер + monorepo shared core

---

## 16. Оценка трудозатрат

При full-time темпе одного разработчика + Claude в режиме pair:

| Фаза | Дней (оптимистично) | Дней (реалистично) |
|------|---------------------|--------------------|
| 0 — подготовка (+ IDE setup + дизайн-эталоны) | 1 | 3 |
| 1 — ядро | 3 | 5 |
| 2 — UI shell + design tokens + Board | 4 | 6 |
| 3 — бот + blitz | 1 | 2 |
| 4 — storage + ачивки | 2 | 4 |
| 5 — декор + анимации + звук + дизайн pixel-parity | 3 | 5 |
| 6 — online + auth | 3 | 6 |
| 7 — shop + powerups | 1 | 2 |
| 8 — cut-over | 1 | 2 |
| **Итого до релиза** | **19** | **35** |
| 9 — Dart-сервер (опц.) | 3 | 6 |

Заложить **+30% буфер** на непредвиденное (FlutterFire на каждой платформе, перфоманс Web, регресс, точность шрифтов/SVG).

---

## 17. Открытые вопросы (требуют решения пользователя)

**Закрыто:**
- ~~IDE~~ — **IntelliJ IDEA Ultimate** + плагины Flutter/Dart/Android (см. memory `user_ide`).
- ~~State management~~ — **Riverpod** (codegen).
- ~~Архитектурный паттерн~~ — **MVVM** (Model=ядро/репозитории, ViewModel=
  Riverpod-нотифайеры, View=виджеты). См. §2 «Архитектурный паттерн: MVVM».
- ~~Дизайн~~ — **100% pixel-parity**, см. §6.

**Остаются:**
1. **Сервер мигрируем или нет?** Рекомендация: на Этапе 1 — нет; Фаза 9 опциональна, но даёт shared core (большой плюс).
2. **Desktop в первом релизе?** Рекомендация: нет, только Web + iOS + Android. Desktop позже.
3. **Web renderer:** CanvasKit (по умолчанию, +2МБ) или HTML (меньше, хуже Flame и шрифты могут «поплыть» — риск для дизайна §6). Рекомендация: **CanvasKit** — это критично для соблюдения §6 (одинаковый рендер шрифтов и SVG на всех платформах).
4. **Звук:** запекать .wav (теряем процедурный синтез) или искать Dart-обёртку Web Audio. Рекомендация: запечь.
5. **Версия после миграции:** `2.0.0` (major bump). OK?
6. **Сохранёнки/профили существующих игроков:** Firestore-схема та же, Hive начнётся с нуля для локальных профилей — нужен миграционный шаг? Большинство активных игроков уже синкаются через Firebase, локальные потеряются. Рекомендация: добавить one-shot import из `localStorage` на Web при первом запуске Flutter-версии (читать window.localStorage из dart:html, маппить в Hive).
7. **Эталонные screenshot-ы дизайна (§6.8):** делать руками из браузера в фиксированных состояниях или скриптом на Playwright? Рекомендация: Playwright (детерминированно, воспроизводимо).
