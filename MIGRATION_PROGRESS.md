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
- [ ] Golden-дамп TS-ядра → `test/golden/determinism_match.json`
      (скрипт `tools/dump-golden.ts`).

## Фаза 1 — ядро (Dart-порт `src/core/`)

- [ ] `lib/core/types.dart`, `rng.dart`, `pieces.dart`, `board.dart`,
      `scoring.dart`, `bag.dart`, `moves.dart`, `bot.dart`, `timer.dart`.
- [ ] Зеркало 46 Vitest-тестов → `flutter/test/`.
- [ ] **Gate:** golden-тест детерминизма проходит бит-в-бит.

## Фазы 2–9

См. план `MIGRATION_FLUTTER.md` §8. Будут раскрыты по мере подхода.

---

## Открытые вопросы пользователя (блокируют дальнейшие фазы)

Из `MIGRATION_FLUTTER.md` §17 остаются: сервер мигрируем или нет; desktop в
первом релизе; web renderer (CanvasKit vs HTML); звук (запекать .wav); версия
2.0.0; миграция профилей; метод снятия эталонных скриншотов. Решать по мере
подхода к соответствующим фазам.

---

_Last updated: 2026-06-05 — Фаза 0 скелет готов, ядро не начато._
