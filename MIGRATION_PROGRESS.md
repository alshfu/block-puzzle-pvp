# MIGRATION_PROGRESS — журнал фактически сделанного

> **Назначение файла:** живой чеклист **реально выполненных** шагов миграции
> TS → Dart/Flutter, с датами и пояснениями. В отличие от `MIGRATION_FLUTTER.md`
> (это *план*), здесь фиксируется только то, что уже сделано и проверено.
>
> Правила ведения:
> - отмечаем `[x]` только когда шаг выполнен и проверен (`flutter analyze` чист,
>   тесты зелёные);
> - каждый значимый шаг → строка с датой и одной фразой «что/почему»;
> - источник истины по плану — `MIGRATION_FLUTTER.md`; по правилам игры —
>   `TZ_BlockDuel_9x9.md`; по стилю кода — memory `feedback_dart_style`.
> - **Архитектура — строго MVVM** (Model=ядро/репозитории, ViewModel=Riverpod-
>   нотифайеры без BuildContext, View=виджеты без логики). См. MIGRATION_FLUTTER
>   §2 «Архитектурный паттерн: MVVM». Слой Model (ядро) готов в Фазе 1.
>
> Условные обозначения: `[x]` сделано · `[~]` в работе · `[ ]` не начато.

---

## Toolchain (среда разработки)

- [x] **2026-06-05** — удалён конфликтующий Homebrew-dart (3.7.2); `dart` теперь
      бандленный из Flutter. *Почему:* два Dart в PATH давали рассинхрон версий.
- [x] **2026-06-05** — `flutter upgrade` → **Flutter 3.44.1** (stable),
      Dart 3.9. `flutter config --enable-web --enable-macos-desktop`.
- [x] **2026-06-05** — `flutter doctor`: ✓ Flutter, ✓ Chrome (web), ✓ macOS,
      ✓ устройства. **Открыто:** Android SDK не установлен; iOS Simulator
      runtime не скачан (Xcode 26.2 есть). Настройка — в IDEA позже (web-first).
- [ ] Android SDK (через Android-плагин IDEA) — для сборки под Android.
- [ ] iOS Simulator runtime (Xcode → Settings → Components) — для iOS.
- [ ] Run Configurations в `.idea/runConfigurations/` (см. MIGRATION_FLUTTER §6.2).

## Фаза 0 — подготовка

- [x] **2026-06-05** — `flutter create --org com.alshfu --project-name
      block_duel --platforms web,ios,android,macos flutter` → скелет `flutter/`
      (109 файлов).
- [x] **2026-06-05** — зависимости через `flutter pub add` (актуальные версии,
      не устаревшие пины плана): **flame 1.37.0**, flutter_riverpod 3.3.1,
      riverpod_annotation, freezed_annotation 3.1.0, json_annotation,
      collection, go_router 17.3.0; dev: build_runner, freezed,
      json_serializable, riverpod_generator. *Примечание:* `custom_lint` +
      `riverpod_lint` отложены — конфликт версий с Riverpod 3.x.
- [x] **2026-06-05** — `analysis_options.yaml` по правилам: flutter_lints,
      `page_width: 80`, `prefer_final_locals`, `directives_ordering`.
- [x] **2026-06-05** — `pubspec.yaml` переписан (версия 2.0.0, шапка-описание).
- [x] **2026-06-05** — `lib/main.dart` — документированная заглушка Фазы 0;
      `test/widget_test.dart` — smoke-тест. `flutter analyze` чист, тест зелёный.
- [ ] Скачать 6 TTF-шрифтов в `flutter/assets/fonts/` (Bricolage Grotesque,
      DM Mono, Fredoka, Baloo 2, Oswald, Share Tech Mono).
- [ ] Экспортировать SVG `CartoonPony`/`Mascot`/`favicon` → `assets/images/`.
- [ ] Эталонные скриншоты TS-версии (3 темы) → `test/golden/source/`.
- [x] **2026-06-05** — golden-дамп TS-ядра → `flutter/test/golden/
      determinism_match.json` (скрипт `tools/dump-golden.ts`). Послойно: rng
      (5 сидов×16), bag (4×21), orientations (7 фигур), scoring (5 кейсов),
      clears (5 сценариев), game (3 партии 25/57/80 ходов). Харнесс партии
      идентичен `tests/determinism.test.ts` (moves[0], без rng в решениях).
      Доска кодируется строкой 81 символ ('.'/'0'/'1').

## Фаза 1 — ядро (Dart-порт `src/core/`)

- [x] **2026-06-05** — портировано всё ядро в `flutter/lib/core/`:
      `types.dart` (типы + defaultConfig), `rng.dart` (mulberry32 с ручным
      `_imul` для 32-бит), `pieces.dart` (формы/ориентации), `board.dart`
      (доска/очистка), `bag.dart` (7-bag), `scoring.dart` (v1.5+),
      `moves.dart` (перебор/эвристики), `bot.dart` (3 уровня), `timer.dart`
      (blitz/forcePlace), барель `core.dart`. Константы в lowerCamelCase
      (`defaultConfig`, `botWeights`). `flutter analyze` чист.
- [x] **2026-06-05** — **GATE ПРОЙДЕН:** golden-тест детерминизма зелёный
      бит-в-бит. `test/golden/determinism_golden_test.dart` (bag/orientations/
      scoring/clears/game — 29 тестов на VM), `test/core/rng_golden_test.dart`
      (PRNG vs эталон). **PRNG проверен и на Web:** `test/core/rng_web_test.dart`
      проходит и через `dart test` (VM), и `dart test -p chrome` (JS) — риск
      32/64-bit закрыт.
- [x] **2026-06-05** — поведенческие unit-тесты `test/core/
      core_behavior_test.dart` (тупик/forcePlace, валидность бота на 3 уровнях,
      blitz-таймер, антидубль drawAvoiding, доска/очистки). Итого **48 тестов**
      зелёные, `flutter analyze` чист.

**Фаза 1 завершена.** Ядро портировано и детерминизм доказан бит-в-бит
(VM + Web). Следующая — Фаза 2 (UI shell + design tokens + Board на Flame).

## Фаза 2 — UI shell + design tokens + Board (в работе)

- [x] **2026-06-05** — design-tokens 1:1 из `themes.ts`:
      `lib/ui/design_tokens.dart` (`BlockDuelTheme` как `ThemeExtension`, 3 темы
      neutral/candy/night, цвета hex-в-hex, радиусы, шрифты), `responsive.dart`
      (breakpoints 480/900/1200 + `clampVw` = CSS `clamp`).
- [x] **2026-06-05** — каркас MVVM + меню:
      ViewModel `lib/ui/theme/theme_controller.dart` (Riverpod Notifier темы,
      без BuildContext); View `lib/app.dart` (MaterialApp.router),
      `lib/ui/router.dart` (go_router: `/`, `/game/:mode`), `screens/
      menu_screen.dart` (меню), `widgets/{logo,mini_piece,theme_switch}.dart`,
      `screens/game_placeholder_screen.dart`. `main.dart` → ProviderScope.
      Меню рендерится на Web (localhost:8080), переключение 3 тем работает.
      `flutter analyze` чист, 48 тестов зелёные.
- [x] **2026-06-05** — 6 TTF-шрифтов подключены (`assets/fonts/`, OFL),
      бандлятся локально; variable Bricolage/Fredoka/Baloo2/Oswald + статические
      DM Mono / Share Tech Mono. FontManifest на Web содержит все 6 семейств.
- [ ] Golden-скриншот MenuScreen в 3 темах (§6.8) — после доводки вёрстки.
- [x] **2026-06-05** — **Фаза 2.3: игра играбельна.** Model/ViewModel:
      `game/match_config.dart`, `game/game_state.dart` (+ query-методы
      activeCells/canPlaceAt/previewCells), `game/game_notifier.dart`
      (Riverpod Notifier-family: выбор/поворот/постановка, авто-ход бота через
      Timer, детекция тупика, без BuildContext). View: доска на Flame
      `ui/game/board_game.dart`, обёртка ввода `ui/widgets/board_view.dart`
      (tap/hover/drag → призрак + постановка), `hand_view.dart`,
      `scoreboard.dart`, экран `screens/game_screen.dart` (+ оверлей конца
      игры), роут `/game/:mode` → GameScreen. Режимы hotseat/bot/botvbot.
      Тесты ViewModel `test/game/game_notifier_test.dart`. Итого **52 теста**
      зелёные, analyze чист, игра идёт на Web (localhost:8080).
      *Замечания:* API Riverpod 3.x family = `Notifier` с конфигом в
      конструкторе. Blitz-таймер/force-place — Фаза 3; arcade/tutorial/online,
      сохранёнки, звук, декор — последующие фазы.

## Фаза 3 — бот, blitz, force-place

- [x] **2026-06-05** — бот ходит через `Timer` (3 уровня) — сделано в 2.3.
- [x] **2026-06-05** — blitz-таймер + force-place: `GameState` получил
      `turnLimit`/`turnRemaining`; `GameNotifier._armTimers/_tick/_onTimeout`
      ведут отсчёт 100мс на ходу человека и на таймауте ставят фигуру через
      `forcePlace` (предпочитая выбранную); виджет `ui/widgets/turn_timer.dart`
      (полоса + секунды, тревожный цвет ≤3с). Добавлен `RuleConfig.copyWith`
      (аддитивно). Тест `blitz-таймаут → force-place`. **53 теста** зелёные,
      analyze чист.

**Фаза 3 завершена.** Дальше — Фаза 4 (Storage/Hive + Profile + Achievements +
Daily + resume сохранёнки).

## Фаза 4 — Storage + Profile + Settings + (Achievements/Daily — далее)

- [x] **2026-06-05** — фундамент персистентности на `shared_preferences`:
      `storage/prefs.dart` (провайдер + ключи, override в main),
      `profile/{profile.dart,profile_controller.dart}` (модель + ViewModel,
      XP/уровень треугольный, награды за матч),
      `settings/{settings.dart,settings_controller.dart}` (звук/музыка/анимации).
      Тема теперь персистится (`ThemeController` читает/пишет prefs). `main.dart`
      — async-bootstrap с загрузкой prefs.
- [x] **2026-06-05** — экраны `ProfileScreen` (ник/аватар/уровень/XP/стата) и
      `SettingsScreen` (тема + тогглы + about) + общий `ScreenScaffold`; роуты
      `/profile`, `/settings`; верхняя панель меню привязана к реальному
      профилю и навигации; итог партии начисляет XP/монеты профилю (кроме
      bot×bot). Тесты `test/profile/profile_test.dart`. **57 тестов** зелёные,
      analyze чист, работает на Web.
- [x] **2026-06-05** — достижения: `achievements/{achievement.dart,
      definitions.dart,achievements_controller.dart}` (модель + 11 базовых
      ачивок + движок-ViewModel с персистом), экран `AchievementsScreen`,
      роут `/achievements`, чип 🏆 в меню; пересчёт по итогу партии. (Полные
      ~120, вкл. PvP, — позже/Фаза 6.)
- [x] **2026-06-05** — **PILOT/E2E:** `integration_test/app_test.dart`
      (реальное устройство/web) + headless-зеркало `test/pilot_test.dart`
      (в обычном `flutter test`): сквозной прогон меню→профиль→достижения и
      hot-seat (выбор фигуры → постановка → возврат). Device-прогон тут не идёт
      (среда не форграундит окно), headless — зелёный.
- [x] **2026-06-07** — **Daily quests:** `daily/{daily.dart,daily_controller.dart}`
      (модель: пул из 5 квестов, детерминированный выбор 3-х по date-seed,
      метрики gamesPlayed/wins/coinsEarned; ViewModel: персист в
      shared_preferences, сброс при смене дня, `recordGame`/`claim` с
      начислением монет в профиль), экран `DailyScreen` + роут `/daily` + чип 🎯
      в меню. Итог партии вызывает `recordGame`; `ProfileController.addCoins` +
      `recordResult` теперь возвращает начисленные монеты. Тест `daily_test.dart`.
- [x] **2026-06-07** — **resume сохранёнки:** вместо Hive — `shared_preferences`
      (JSON-слот `bd_savegame`). `game/{saved_game.dart,saved_game_store.dart}`:
      `BagSnapshot` сохраняет точное внутреннее состояние мешка (queue+counter+
      rngState) → детерминистичный resume 7-bag без replay по drawCounts; доска
      кодируется строкой 81 символ. `GameNotifier._autoSave` пишет снимок после
      каждого хода (bot×bot не сохраняется), `_restore` поднимает партию;
      `MatchConfig.resume` + карточка «Продолжить» в меню + route-параметр
      `?resume=1&seed=`. Тест `save_resume_test.dart` (round-trip). *Отступление
      от плана:* shared_preferences вместо Hive — слот один, JSON достаточно.
      **65 тестов** зелёные, analyze чист.

**Фаза 4 завершена.** Storage + Profile + Settings + Achievements + Daily +
resume — всё на месте. Дальше — Фаза 5 (декор, анимации, звук, pixel-parity).

## Фаза 5 — декор, анимации, звук, pixel-parity (в работе)

- [x] **2026-06-07** — **звук синтезируется в Dart** (решение пользователя: не
      запекать .wav из браузера, а портировать Web Audio синтез). Чистый движок
      `audio/synth.dart` (осциллятор sine/triangle/sawtooth/square + envelope:
      линейная атака 0→peak за 10мс, exp-спад peak→0.0001 за `duration`; смешение
      тонов с `start` → WAV-байты моно/16-bit). Каталог `audio/sfx.dart` (1:1 с
      `src/ui/audio.ts`: place/invalid/clear(n)/perfect/win/lose/draw/tick/click).
      Воспроизведение `audio/audio_service.dart` на `audioplayers` (пул из 4
      плееров round-robin, кэш WAV, уважает `soundOn`) — единственное место с
      плагином, синтез остаётся чистым. Проводка: `GameState` получил
      `moveSeq`/`lastClearCount`/`lastPerfect`; `GameScreen._playMoveSfx`
      (постановка/очистка/perfect + тик в danger-зоне ≤3с) и звук win/lose/draw
      по итогу. Тест `test/audio/synth_test.dart` (WAV-заголовок, длина буфера,
      пик огибающей, детерминизм, кламп). **74 теста** зелёные, analyze чист,
      `flutter build web` собирается (WASM dry-run ок).
- [x] **2026-06-07** — **декор: `ThemeBackdrop`** (`ui/decor/theme_backdrop.dart`)
      — порт `components/ThemeBackdrop.tsx` + CSS-анимаций. 3 темы: neutral
      (статичные радиальные градиенты), candy (розовый градиент + радуга +
      облака + 22 падающих сердечка/звезды/искры через `floatdown`), night
      (тёмный градиент + звёзды + качающийся луч `beamsweep` + эмблема-ромб со
      звездой `emblemglow` + неоновый скайлайн из 22 зданий + сетка). Частицы
      засеяны **тем же PRNG ядра**: `makeRng(7)` для candy-битов, `makeRng(100+i)`
      для зданий — раскладка совпадает с TS. Анимация от свободного `Ticker`
      (монотонные секунды), при `reduceMotion` тикер не стартует (статичный
      кадр). Встроен за контент в `MenuScreen` и `ScreenScaffold` (профиль/
      настройки/ачивки/daily). Тесты переведены на `reduceMotion:true` в
      mock-prefs (иначе `pumpAndSettle` висит на бесконечном тикере). **74 теста**
      зелёные, analyze чист, web собирается. *Отложено:* ponies/mascots в
      candy-фоне — отдельный SVG-слайс.
- [x] **2026-06-07** — **маскоты `Mascot`/`CartoonPony`** через **flutter_svg**
      (`SvgPicture.string` той же SVG-разметкой, что в TSX → точный силуэт без
      ручного переноса безье). `ui/decor/cartoon_pony.dart` (chibi-пони,
      viewBox 160, параметризован телом/3 прядями гривы/акцентом + хелпер
      `darken`), `ui/decor/mascot.dart` (по теме: candy=пони, night=тень в
      капюшоне, neutral=киберробот; viewBox 120). Интеграция: 4 парящих пони в
      углах candy-фона (`ThemeBackdrop`, порт `.candy-pony-deco`, покачивание
      `ponyBob`, только на широких экранах ≥700px) + маскот в оверлее конца игры
      (`_GameOverOverlay`). Тест `test/decor/mascot_test.dart` (рендер всех
      вариантов + `darken`). **80 тестов** зелёные, analyze чист, web собирается.
- [ ] Декор (продолжение): `FloatingTheme`-кнопка.
- [x] **2026-06-07** — **Confetti (Flame) + ComboFlash (оверлей).** Confetti
      `ui/game/confetti_overlay.dart` — порт `Confetti.tsx` на Flame
      `ParticleSystem`: 32 частицы-прямоугольника, ускоряющееся падение (ease-in
      через acceleration), дрейф ±40px, вращение 0..720°, затухание; цвета темы
      (p0/p1/good); прозрачный полноэкранный `GameWidget`, ввод не перехватывает.
      ComboFlash `ui/decor/combo_flash.dart` — порт `ComboFlash.tsx` (в оригинале
      DOM-оверлей с SVG-маскотом+текстом, поэтому Flutter-оверлей, а не Flame):
      `comboMessages`/`pickComboMessage`, маскот с bounce, заголовок цвета уровня
      (1=p0/2=good/3=p1), вход overshoot-scale + затухание за 1.7с. Триггеры в
      `GameScreen._playMoveEffects` по диффу: perfect→салют; ходивший человек
      пересёк комбо 3/5/10 → вспышка уровня 1/2/3 (логика порога 1:1 с
      `useGame.ts`). Гасятся при reduceMotion. Тест `test/decor/combo_flash_test`.
      **84 теста** зелёные, analyze чист, web собирается.
- [x] **2026-06-07** — **Toast/Pause-оверлеи + click-звук.** `ui/decor/
      toast_stack.dart` — порт `ToastStack.tsx`: тосты о вновь разблокированных
      ачивках сверху (въезд/уезд `toastIn/toastOut`, авто-уезд 4с, тап раньше);
      источник — `evaluate()` по итогу партии. `ui/decor/pause_overlay.dart` —
      порт `PauseOverlay.tsx` (блюр + карточка «Пауза» + продолжить/новая/меню).
      Реальная пауза: `GameState.paused` + `GameNotifier.setPaused` останавливает
      blitz/бот-таймеры (учёт в `_armTimers`/`_tick`); кнопка ⏸ в топбаре.
      Click-звук (`Sfx.click`, каталог был готов) на ключевых кнопках: меню
      (играть/режимы), пауза и её действия, game-over. Тесты: пауза в
      `game_notifier_test`. **91 тест** зелёный, analyze чист, web собирается.
- [ ] Анимации (опц.): Result-оверлей как отдельный экран (сейчас инлайн).
- [x] **2026-06-07** — **фоновая музыка** (порт `src/ui/music.ts`). `audio/
      music.dart` (чистый): парсер нот `noteFreq` (равномерная темперация),
      треки 3 тем (bpm + голоса), `renderTrack` рендерит ОДИН цикл в WAV
      переиспользуя `synth.dart`. Вместо real-time планировщика Web Audio —
      готовый зацикливаемый буфер (один проход голосов = блок `scheduleLoop`),
      длина = длине цикла → бесшовная петля. `synth.dart` обобщён аддитивно
      (параметры `attack`/`tail`/`totalDuration`; музыка: 0.03/0.08/loop). Плеер
      `audio/music_service.dart` на `audioplayers` (`ReleaseMode.loop`, кэш,
      идемпотентный `update(enabled, theme)`), драйвится из `app.dart` по
      настройке музыки и теме. Тест `test/audio/music_test.dart`. В тестах
      `musicOn:false` (петля-плеер не висит в headless). **90 тестов** зелёные,
      analyze чист, web собирается.
- [x] **2026-06-07** — click-звук подключён (см. Toast/Pause-слайс).
- [x] **2026-06-07** — **`FloatingTheme`** (`ui/widgets/floating_theme.dart`) —
      порт `FloatingTheme.tsx`: плавающая пилюля снизу-справа в меню, тап
      циклирует тему, внутри образец следующей темы (диагональный p0/p1) + ярлык
      текущей; click-звук. analyze чист, web собирается.
- [ ] **Gate:** полная визуальная сверка pixel-parity во всех 3 темах
      (визуальная приёмка пользователя — вне кода).

**Фаза 5 (декор/анимации/звук) закрыта по коду.** Реализовано: SFX + музыка
синтезируются в Dart; ThemeBackdrop (3 темы); маскоты/ponies (flutter_svg);
Confetti на Flame; ComboFlash; Toast/Pause-оверлеи; click-звук; FloatingTheme.
Остаётся только визуальный gate pixel-parity (приёмка пользователем) — он не
блокирует переход к Фазе 6.

## Фаза 6A — Онлайн PvP (без auth/sync; сервер Node/VPS не трогаем)

Решения: Dart-клиент говорит со старым Node-сервером по тому же WS-протоколу
(кросс-протокол); auth+Firestore-sync (6B) отложены; статистика минимальная
(онлайн W/L/D + ELO-лидерборд). План — `/Users/al_sh/.claude/plans/
precious-wandering-sifakis.md`.

- [x] **2026-06-07** — **6A.1 транспорт + DTO** (`lib/online/`): `party_host`
      (хост из `--dart-define=PARTY_HOST`), `transport` (ITransport/WsTransport на
      web_socket_channel), `online_wire` (wire⇄ядро бит-в-бит: PieceType
      заглавными, Coord `[r,c]`, RuleConfig int→double, onTimeout "forcePlace"),
      `online_models`, `online_to_game_state` (адаптер для переиспользования
      игровых виджетов), `uuid`. Profile += id(UUID)+онлайн W/L/D +
      `recordOnlineResult`. Тесты wire/adapter. **101 тест.**
- [x] **2026-06-07** — **6A.2 лобби + матчмейкинг**: `lobby_notifier` (queue/
      cancel, queued/matched/bot_fallback/error), `OnlineMenuScreen` (/online),
      чип 🌐 в меню, `transport_provider` (DI-шов для FakeTransport),
      bot_fallback→/game/bot. **107 тестов.**
- [x] **2026-06-07** — **6A.3 живой матч**: `online_match_state` +
      `online_game_notifier` (hello/move/resign/rematch, reconnect с backoff+
      повторным hello, placeAt через адаптер → anti-cheat проходит),
      `OnlineGameScreen` (переиспользует BoardView/HandView/Scoreboard/TurnTimer
      через адаптер; SFX+конфетти по диффу; recordOnlineResult),
      `online_overlays` (соперник-ушёл + финал с ремачом), роут
      /online/game/:roomId. **115 тестов.**
- [x] **2026-06-07** — **6A.4 лидерборд**: `leaderboard_notifier` (subscribe/
      snapshot, поле `totalPlayers`), `LeaderboardScreen` (/leaderboard, топ +
      мой ранг), роут. **117 тестов** зелёные, analyze чист, web собирается.

**Фаза 6A закрыта по коду.** Все нотифайеры покрыты тестами на FakeTransport
(реального сервера в CI нет). Остаётся ручной кросс-протокол smoke (локальный
Node-сервер + `flutter run -d chrome --dart-define=PARTY_HOST=localhost:1999`).

## Фаза 6B — Auth + Firestore sync

Firebase-проект `blockduel-web` (config заведён вручную из консоли, без
flutterfire CLI — у него был сломан токен). apiKey web публичен.

- [x] **2026-06-08** — **6B.1 Firebase + Google sign-in**: `firebase_options.dart`
      (web), мягкая инициализация в `main` (сбой не валит app), `auth/
      auth_controller.dart` (guarded: без Firebase available=false; web popup +
      authStateChanges + signOut), секция «Аккаунт» в настройках. analyze:
      `analysis_options.yaml` excludes `build/**`. **119 тестов.**
- [x] **2026-06-08** — **6B.2 Firestore sync**: `auth/cloud_snapshot.dart`
      (чистая модель + merge: max-счётчики, не-дефолтные ник/аватар, id из
      облака, union ачивок), `auth/sync_controller.dart` (users/{uid}: pull+seed
      на входе, debounced push на изменениях; guarded), `replace`/`mergeUnlocked`
      в контроллерах, активация в `app.dart`. **123 теста** зелёные, analyze чист,
      web собирается.

**Фаза 6B закрыта по коду.** Минимальная схема (легаси-данных TS нет). Осталось:
нативный Google-вход (Android/iOS — нужен flutterfire configure на платформы),
применить `firestore.rules` в проекте `blockduel-web`, богатая схема (кошелёк/
скины/детальная статистика) — позже. Ручная проверка входа+синка — за
пользователем (`flutter run -d chrome`).

## UI-паритет по ТЗ §8/§4 (juice, превью, статы)

- [x] **2026-06-08** — аудит интерфейса по ТЗ §8 (UI/UX) + §4: задокументированы
      пробелы juice/превью/статы (`INTERFACE_PARITY.md`).
- [x] **2026-06-08** — паритет ачивок: полный каталог **120** (15 базовых + 105
      PvP) + движок прогресса + статистика (`afd192e`).
- [x] **2026-06-08** — ТЗ §8 juice + §4.1 статы профиля (`7c3c55f`).

## Фаза 7 — магазин, power-ups, аркада, обучение, hardening

- [x] **2026-06-08** — **7.1 магазин**: две валюты, скины ячеек и инвентарь
      power-ups (`f83a812`).
- [x] **2026-06-08** — **7.2**: надетый скин применяется к рендеру доски
      (`11a7dc0`).
- [x] **2026-06-08** — **7.3**: power-ups в игре — панель, эффекты, расход из
      инвентаря (`da5fb17`).
- [x] **2026-06-08** — **Tutorial**: интерактивное обучение из 5 шагов (+50
      монет) (`9d9aec1`).
- [x] **2026-06-08** — соло-Аркада, 12 аватаров, баннер серии побед, скрытый
      pilot, горячие клавиши, macOS/web/iOS-хардненинг (сетевые entitlements,
      тёмный фон окна, иконки, брендинг). Фикс прокрутки онлайн-матча (`9d8c979`).

**Фаза 7 закрыта по коду.**

## Фаза 3b — богатая онлайн-статистика + PvP-ачивки + экран /stats

- [x] **2026-06-09** — **3b.1**: модель и накопление онлайн-статистики
      (`38c8352`).
- [x] **2026-06-09** — **3b.2**: проводка матч→stats→PvP-ачивки + тосты
      (`8ecd92d`).
- [x] **2026-06-09** — **3b.3**: экран подробной статистики `/stats` (`1614241`).
- [x] **2026-06-09** — хвосты 3b: `myElo` для ELO-ачивок + ники соперников
      (`92c38c2`).
- [x] **2026-06-09** — разбивка очков в ResultOverlay + фикс паритета
      офлайн-счёта (`1b25edf`).

**Фаза 3b закрыта по коду.**

## Security — аудит PvP-сервера

- [x] **2026-06-09** — аудит безопасности PvP-сервера + локальный
      пентест-харнесс (`SECURITY_AUDIT_SERVER.md`, `tools/pentest_local.mjs`,
      `9d6a624`). Прод-пентест без согласия не запускать.
- [x] **2026-06-09** — **SEC-1**: hardening без смены протокола (H3/H4/H5/M1/M2/M6,
      `b2c239b`).
- [x] **2026-06-09** — **SEC-2**: аутентификация `roomToken` end-to-end (H1, H2
      части., `b4a137a`).
- [x] **2026-06-09** — **SEC-3**: добивка хвостов (M2/M3/M4/M5/L1/L2/H2 части.,
      `82ae75a`).

## Фаза 8 — cut-over (обвязка) + реструктуризация репо

- [x] **2026-06-09** — **обвязка cut-over**: `npm run build:flutter`/
      `deploy:flutter` (PARTY_HOST=pvp.alshfu.com, TLS, base-href, `.nojekyll`),
      переход прода Pages TS→Flutter Web документирован в `DEPLOY.md` (`7713a13`).
- [x] **2026-06-09** — **R1 реструктуризация**: `src/` → **`legacy-ts/`** (TS/
      React-фронт ретайрнут; но `legacy-ts/core` остаётся живым как зависимость
      Node-сервера) (`e968b89`).
- [x] **2026-06-09** — **R2 реструктуризация**: `flutter/` → **корень репозитория**
      (`lib/`, `test/`, `web/`, `pubspec.yaml`, `android/ios/macos/`,
      `integration_test/`, `assets/`). Все прежние пути `flutter/lib/...` теперь
      `lib/...` (`49a813e`).
- [x] **2026-06-09** — **merge `flutter-migration` → `main`** (`8a63a82`): `main`
      содержит всю миграцию.
- [x] **2026-06-10** — **ПРОД CUT-OVER ВЫПОЛНЕН**: `npm run deploy:flutter`
      (тесты-гейт зелёные: Flutter 176 + TS Vitest 55) → GitHub Pages переключён
      с TS на Flutter Web (gh-pages `e6c30a1`). Live
      https://alshfu.github.io/block-puzzle-pvp/ отдаёт Flutter-сборку
      (`flutter_bootstrap.js`/`main.dart.js`/canvaskit, HTTP 200).

**VPS-сервер не трогался** (Flutter-клиент говорит по тому же WS-протоколу).
Post-cutover hardening сервера (`REQUIRE_ROOM_TOKEN=1` + `ALLOWED_ORIGINS`) —
включить, когда старых TS-вкладок не останется; делает пользователь (`git pull`
+ `systemctl restart blockduel-pvp`). См. `DEPLOY.md`.

## Открытые / оставшиеся пункты

- [x] **Прод cut-over** выполнен (2026-06-10).
- [ ] Post-cutover hardening сервера (`REQUIRE_ROOM_TOKEN=1` + `ALLOWED_ORIGINS`) — на VPS.
- [ ] Визуальный **gate pixel-parity** во всех 3 темах (приёмка пользователя).
- [ ] Ручная проверка онлайна / Google-входа / Firestore-синка (`flutter run`).
- [~] Нативный Google-вход: **код готов для macOS/iOS/Android** (2026-06-10,
      `auth_controller._signInWithGoogleNative` через google_sign_in 7.x +
      `firebase_options.macos` + Info.plist URL-схема) — остались **консольные
      шаги** (регистрация macOS-app в `blockduel-web`, заполнить REPLACE_ME);
      инструкция `MACOS_AUTH_SETUP.md`.
- [x] **2026-06-10** — PvP на macOS починен: `npm run build:macos`/`run:macos:prod`
      прокидывают PARTY_HOST/PARTY_TLS (раньше шёл на localhost:1999).
- [ ] **Применить `firestore.rules`** в `blockduel-web` (файл написан с
      валидацией схемы `users/{uid}` — `npm run deploy:rules` или консоль).
- [ ] **Релиз v2.0.0 macOS** (.app.zip, неподписанный, GitHub Release) — после
      проверки auth+PvP на Mac.
- [ ] Android SDK + iOS Simulator runtime (для нативных сборок).
- [x] **2026-06-10** — ветка `flutter-migration` заархивирована (тег
      `archive/flutter-migration` → `49a813e`) и удалена (local + origin).

**Решённые открытые вопросы (`MIGRATION_FLUTTER.md` §17):** версия = **2.0.0**;
web renderer — дефолтный; звук — **синтез в Dart** (не запекать .wav); сервер
**не мигрируем** (Dart-сервер отложен) — Flutter-клиент говорит с существующим
Node/VPS-сервером по кросс-протоколу; эталонные скриншоты — через golden-тесты.

---

_Last updated: 2026-06-10 — миграция влита в `main` (merge `8a63a82`) и **прод
переключён на Flutter Web** (cut-over `deploy:flutter`, gh-pages `e6c30a1`).
Закрыты фазы 0–8 + 3b + security (SEC-1..3) + реструктуризация репо (Flutter в
корне, TS → `legacy-ts/`). **176 тестов зелёные** (+ TS Vitest 55), `flutter
analyze` чист. Остаётся: post-cutover hardening сервера на VPS, визуальный gate
pixel-parity и ручная проверка онлайна/входа/синка._
