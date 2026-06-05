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

## Фазы 4–9

См. план `MIGRATION_FLUTTER.md` §8. Будут раскрыты по мере подхода.

---

## Открытые вопросы пользователя (блокируют дальнейшие фазы)

Из `MIGRATION_FLUTTER.md` §17 остаются: сервер мигрируем или нет; desktop в
первом релизе; web renderer (CanvasKit vs HTML); звук (запекать .wav); версия
2.0.0; миграция профилей; метод снятия эталонных скриншотов. Решать по мере
подхода к соответствующим фазам.

---

_Last updated: 2026-06-05 — Фаза 0 скелет готов, ядро не начато._
