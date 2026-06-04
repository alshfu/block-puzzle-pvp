# HANDOFF — заметка для следующего AI-ассистента

**Кому:** Claude (или любой AI-ассистент), которого пользователь подключит к этому проекту в следующих сессиях.
**От кого:** Claude Opus 4.7, сессия 2026-06-05.
**Зачем:** чтобы ты с порога понимал **что** было сделано, **где** искать актуальное, **когда** какое решение было принято и **почему**. Не надо переоткрывать то, что уже зафиксировано.

> Этот документ — не план и не ТЗ. План миграции в `MIGRATION_FLUTTER.md`, правила игры в `TZ_BlockDuel_9x9.md`. Это страница «как тут жить и не наломать дров».

---

## 1. TL;DR за 30 секунд

- Проект **BlockDuel 9×9** — соревновательный блок-пазл; Фазы 1–4 ТЗ уже реализованы на **TypeScript + React + Vite + Node**.
- **Принято решение (2026-06-05):** полная миграция на **Dart + Flutter (+ Flame)** под все платформы. См. `MIGRATION_FLUTTER.md`.
- **Реализация миграции ЕЩЁ НЕ НАЧАТА.** На момент написания этого хэндоффа существует только план (документ) и обновлённые memory-записи. Кодовая база TS пока живая и единственная.
- **IDE пользователя:** **IntelliJ IDEA Ultimate 2026.1.3** + плагины Flutter / Dart / Android. Бесплатные альтернативы (VS Code, Android Studio как «бесплатная», Cursor) **не предлагать** — у пользователя оплачена полная JetBrains All Products подписка.
- **Сервер онлайна** живёт на VPS `pvp.alshfu.com` и работает; на Этапе 1 миграции не трогаем.
- **Источник правды по правилам** — `TZ_BlockDuel_9x9.md` (786 строк, RU, v1.0).

---

## 2. Что (что сделано, что в процессе, что не сделано)

### 2.1 Что уже реализовано (в TS-коде, прод)

- Ядро игры (`src/core/index.ts`, 611 строк): доска, 7-bag, очистка, scoring, бот 3 уровней, blitz-таймер, forcePlace, детерминизм.
- UI (`src/ui/` — экраны, компоненты, темы, drag-and-drop, анимации, звук).
- Vs Bot, Hot-seat, Online PvP, прогрессия, магазин, ~120 ачивок, daily quests.
- Firebase Google sign-in + Firestore cross-device sync.
- Сервер `server/` (Node + ws + tsx) — server-authoritative, ELO K=24, лидерборд.
- 46 Vitest-тестов.
- Деплой: GitHub Pages (gh-pages branch) + VPS (systemd + nginx + Let's Encrypt).

Детальный снимок репо — в memory `[[project_state]]` (на 2026-06-02), также см. `CLAUDE.md`.

### 2.2 Что зафиксировано в этой сессии (2026-06-05)

| Артефакт | Где | Коммит |
|----------|-----|--------|
| План миграции на Flutter (17 разделов, ~870 строк) | `MIGRATION_FLUTTER.md` | `479b694` |
| Memory: project Flutter migration | `~/.claude/projects/.../memory/project_flutter_migration.md` | не в git |
| Memory: IDE = IDEA Ultimate 2026.1.3 | `~/.claude/projects/.../memory/user_ide.md` | не в git |
| Memory: стиль коммитов (что/где/когда/почему) | `~/.claude/projects/.../memory/feedback_commit_style.md` | не в git |
| Этот хэндофф | `HANDOFF.md` | (текущий коммит) |

### 2.3 Что ещё НЕ сделано

- **Никакого Dart-кода ещё нет.** Папка `flutter/` не создана. `pubspec.yaml` не существует.
- Эталонные screenshot-ы текущего дизайна не сняты.
- TTF-шрифты для дизайна (6 семейств) не скачаны.
- SVG-маскоты не экспортированы.
- Golden-дамп TS-ядра для проверки детерминизма Dart-порта не сгенерирован.
- Run Configurations для IDEA не созданы.

Всё это — задачи Фазы 0 миграции, см. `MIGRATION_FLUTTER.md` §8.

### 2.4 Открытые вопросы (требуют решения пользователя ДО старта Фазы 0)

См. `MIGRATION_FLUTTER.md` §17. На момент хэндоффа закрыты:
- ✅ IDE = IntelliJ IDEA Ultimate 2026.1.3
- ✅ State management = Riverpod 2.5
- ✅ Дизайн = 100% pixel-parity

Остаются открытыми 7 вопросов: сервер мигрируем или нет; desktop в первом релизе; web renderer (CanvasKit vs HTML); звук (запекать или искать обёртку); версия (`2.0.0`); миграция профилей; метод снятия эталонных скриншотов.

**Не начинай Фазу 0, пока пользователь не ответит на эти вопросы** — иначе можно поехать не туда.

---

## 3. Где (карта проекта)

### 3.1 Корень репо

```
block_puzzle_pvp/
├── CLAUDE.md                # ← project instructions (ВСЕГДА читай первым)
├── HANDOFF.md               # ← этот файл, для тебя
├── TZ_BlockDuel_9x9.md      # ← источник правды по правилам игры (786 строк, RU)
├── MIGRATION_FLUTTER.md     # ← план миграции на Dart/Flutter (17 разделов, ~870 строк)
├── ROADMAP.md               # ← фазы развития 0-11 (TS-эра, частично применимо к Flutter-эре)
├── CHANGELOG.md             # ← релизы по версиям
├── DEPLOY.md                # ← инструкции деплоя Pages + VPS
├── package.json             # ← TS зависимости (пока единственная сборка)
├── server/                  # ← Node WS сервер (живой, прод)
├── src/                     # ← TS frontend (живой, прод)
├── tests/                   # ← 46 Vitest тестов
├── tools/                   # ← bot-sim.ts (калибровка бота)
├── public/                  # ← favicon.svg, манифест
├── party/                   # ← опц. PartyKit-вариант сервера (не используется)
├── legacy/                  # ← инертный референс (НЕ ТРОГАТЬ)
└── .github/workflows/deploy.yml.disabled  # ← Actions выключен (биллинг)
```

### 3.2 Где будет жить Flutter-код (после Фазы 0)

```
flutter/                     # ← создаётся в Фазе 0
├── pubspec.yaml             # см. MIGRATION_FLUTTER.md §5
├── lib/{core,game,ui,online,auth,shop,achievements,storage}/
├── test/{core,bot,golden}/
├── assets/{audio,images,fonts,pieces}/
├── ios/ android/ web/ macos/ windows/ linux/  # генерится flutter create
└── tools/bot_sim.dart
```

После Фазы 8 (cut-over) содержимое `flutter/` переезжает в корень репо, `src/` → `legacy-ts/`.

### 3.3 Где жить твоей памяти

```
~/.claude/projects/-Users-al-sh-WebstormProjects-block-puzzle-pvp/memory/
├── MEMORY.md                # индекс — всегда подгружается в твой контекст
├── project_*.md             # снимки и решения по проекту
├── user_*.md                # профиль пользователя (язык, IDE)
├── reference_*.md           # указатели на внешние ресурсы (TZ, GitHub, VPS)
├── feedback_*.md            # правила работы (стиль ответов, коммиты, push)
└── behavior_*.md            # инварианты (core determinism)
```

**Важно:** memory обновляется как только узнаёшь что-то новое о пользователе/проекте. Не дублируй то, что можно прочитать из git/файлов.

### 3.4 Где запущенный сервер

- **VPS:** `pvp.alshfu.com`, Ubuntu 24.04
- **systemd unit:** `blockduel-pvp.service`
- **nginx + Let's Encrypt** (HTTPS / WSS)
- **Перезапуск:** `git pull && systemctl restart blockduel-pvp` — **делает пользователь сам**, ты не имеешь SSH-доступа.
- ⚠️ **Не трогать** `/etc/nginx/sites-enabled/alshfu-arena.conf` на VPS — это сторонний сайт пользователя.

---

## 4. Когда (хронология решений и точки во времени)

| Дата | Событие | Где зафиксировано |
|------|---------|--------------------|
| ранее | Реализованы Фазы 1–4 ТЗ (ядро, UI, vs Bot, Hot-seat, Online PvP, прогрессия, магазин, ачивки) | git log + `CLAUDE.md` |
| 2026-06-02 | Снимок текущего состояния репо (последний на момент хэндоффа) | memory `[[project_state]]` |
| ~2026-06-04 | Коммит `4c8a38d` — `ROADMAP.md` actionable checklist (Фазы 0–11) | git log |
| ~2026-06-04 | Коммит `eb31fa8` — TZ v2 vision + roadmap фазы 5-11 | git log |
| **2026-06-05** | Пользователь явно запросил миграцию на Dart/Flutter под все платформы | этот разговор |
| 2026-06-05 | Создан `MIGRATION_FLUTTER.md` v1 (план миграции) — коммит `479b694` | git + memory `[[project_flutter_migration]]` |
| 2026-06-05 | Пользователь зафиксировал IDE = IntelliJ IDEA Ultimate 2026.1.3 | memory `[[user_ide]]` |
| 2026-06-05 | `MIGRATION_FLUTTER.md` усилен разделом §6 «Сохранение дизайна 1:1» (требование pixel-parity) | коммит `479b694` |
| 2026-06-05 | Пользователь зафиксировал правило: каждый этап = детальный коммит (что/где/когда/почему) | memory `[[feedback_commit_style]]` |
| 2026-06-05 | Написан этот HANDOFF.md | (текущий коммит) |
| **TBD** | Старт Фазы 0 миграции (после ответов на 7 открытых вопросов) | будущее |

Текущая стабильная версия TS-приложения: **v1.6.1** (см. `package.json`).
Целевая версия после миграции: **v2.0.0** (требует подтверждения пользователя).

---

## 5. Правила работы (read this before doing anything)

### 5.1 Из CLAUDE.md (project instructions, обязательно)

- **Идентификаторы и комментарии в коде — английский** (`BoardCell`, `enumerateMoves`, `RuleConfig`).
- **Документация и общение — русский**; технические термины можно оставлять английскими.
- **Не дублировать игровую логику** в `src/ui/` или `server/` — всё через импорт из `src/core/` (в Flutter будет аналогично: всё из `lib/core/`).
- **Не править файлы в `legacy/`** — они инертные.
- **Не отходить от ТЗ** по правилам/балансу без явного запроса.
- **Не возвращать `deploy.yml.disabled`** в `deploy.yml` без подтверждения (биллинг).
- **Не пушить с красными тестами** — Pages закэширует сломанный сайт.
- **Не трогать nginx-конфиг чужого сайта** на VPS.
- **Не предлагать миграцию на Flutter без явного запроса** — *запрос уже получен 2026-06-05, миграция в плане*.

### 5.2 Из memory (правила пользователя, важно)

- **`[[user_language]]`** — пользователь пишет по-русски, отвечай по-русски.
- **`[[user_ide]]`** — IDE = JetBrains, **никаких** VS Code / Android Studio / Cursor / Zed как «лучшей альтернативы». Если пользователь явно не попросит — рекомендуй JetBrains-варианты (IDEA Ultimate, WebStorm, DataGrip, RustRover).
- **`[[feedback_response_style]]`** — пользователь просит сразу создавать файлы без лишних вопросов. Но **не путать** с destructive actions (см. ниже).
- **`[[feedback_git_push_workflow]]`** — пушить в `origin main` после значимых изменений.
- **`[[feedback_commit_style]]`** (новое, 2026-06-05) — **каждый этап = подробный коммит**: заголовок + тело со структурой Что/Где/Когда/Почему. Не «docs: update plan» однострочно.
- **`[[behavior_core_determinism]]`** — ядро (TS сейчас, Dart после миграции) обязано оставаться чистым и детерминированным.

### 5.3 Destructive actions — стоп-сигналы

Несмотря на правило «без лишних вопросов», **всегда подтверждай** перед:
- `git reset --hard`, `git push --force` (особенно в `main`)
- удалением файлов/веток
- `rm -rf`
- коммитом, который **удаляет** содержимое source-of-truth файлов (TZ, CLAUDE.md, MIGRATION_FLUTTER.md) — это уже случилось 2026-06-05 (TZ оказался пустым в working tree, я остановился и спросил, пользователь выбрал restore)
- модификацией CI/деплой (особенно `deploy.yml.disabled`)
- любыми действиями на VPS (у тебя нет доступа, но даже инструкции пользователю — с предупреждением)

### 5.4 Стиль коммитов (правило 2026-06-05)

Формат:
```
<type>(<scope>): <subject под 70 символов>

Что: 1-3 предложения сути.
Где: список файлов / разделов (§N названия).
Когда: дата сессии, контекст.
Почему: мотивация / триггер / ссылка на ТЗ / запрос пользователя.

Co-Authored-By: Claude <model-name> <noreply@anthropic.com>
```

Не применять для опечаток/lint/bump зависимостей — там короткий заголовок OK.

---

## 6. IDE: IntelliJ IDEA Ultimate 2026.1.3 — что знать

### 6.1 Версия и лицензия

- **IntelliJ IDEA Ultimate 2026.1.3** (зафиксировано пользователем 2026-06-05).
- Лицензия: **JetBrains All Products Pack** (платная подписка, действующая).
- Все JetBrains IDE доступны; пользователь сейчас работает в WebStorm для TS-проекта; для Flutter-миграции переходит на IDEA Ultimate.

### 6.2 Что должно быть установлено и настроено (Фаза 0 миграции)

- **Плагины (Settings → Plugins → Marketplace):**
  - `Flutter` (от Google) — основной плагин
  - `Dart` (от JetBrains) — подтягивается автоматически с Flutter, но проверь что включён
  - `Android` (от Google) — для AVD Manager и Android-сборки без отдельной Android Studio
- **Flutter SDK путь:** Settings → Languages & Frameworks → Flutter → Flutter SDK path (`flutter doctor` сначала должен показать зелёное)
- **Dart SDK путь:** обычно подхватывается из Flutter SDK
- **Run Configurations** (положить в `.idea/runConfigurations/` и закоммитить):
  - `Flutter (Web)` — target Chrome, `--web-port 5173`
  - `Flutter (iOS)` — target iPhone 15 simulator (Xcode обязателен на macOS)
  - `Flutter (Android)` — target Pixel 5 emulator
  - `Flutter Test (all)` — `flutter test`
  - `Flutter Test (core)` — `dart test test/core`
  - `Generate (build_runner)` — `flutter pub run build_runner build --delete-conflicting-outputs`
  - `Update Goldens` — `flutter test --update-goldens`
- **Hot Reload:** Cmd+\\ (macOS) / Ctrl+\\
- **Hot Restart:** Shift+Cmd+\\ / Shift+Ctrl+\\
- **Flutter Inspector:** View → Tool Windows → Flutter Inspector

### 6.3 Что НЕ предлагать пользователю

- ❌ Не предлагай Android Studio как «бесплатную альтернативу» — у пользователя оплачена IDEA Ultimate, она делает всё то же самое.
- ❌ Не предлагай VS Code / Cursor / Zed «потому что легче».
- ❌ Не предлагай ставить `code` / `cursor` CLI команды.

### 6.4 Полезные инструменты внутри IDEA для этого проекта

- **Database tool** (DataGrip-функционал) — пригодится если решим логировать матчи в PostgreSQL.
- **HTTP Client** (`.http` файлы) — для тестов WS/REST если добавим REST API.
- **Markdown preview** — для просмотра TZ, MIGRATION_FLUTTER, ROADMAP без выхода из IDE.
- **Git integration** — встроенный diff/merge tool (предпочитай его над командной строкой при многофайловых merge-конфликтах).

---

## 7. Если ты пришёл начать работу — пошагово

### Шаг 1: прочти контекст (5 минут)
1. `CLAUDE.md` — project instructions, что можно/нельзя.
2. Этот файл — `HANDOFF.md`.
3. Memory index (`MEMORY.md`) — все ссылки уже в твоём контексте при старте.

### Шаг 2: проверь актуальность памяти
- Memory может быть старой; перед утверждениями про код — сделай `git status` / `git log -5` / `Read` нужный файл.

### Шаг 3: пойми текущее намерение пользователя
- Если просит конкретное действие — выполняй (с учётом правил §5).
- Если просит «продолжить миграцию» — открой `MIGRATION_FLUTTER.md`, посмотри чеклист фаз §8, проверь по `git log` где остановились, пройди gate-условия предыдущей фазы.
- Если просит «доработать TS-фичу» — окей, TS-кодовая база ещё живая до Фазы 8.

### Шаг 4: работай согласно правилам
- Маленькие правки → сразу делай (правило `[[feedback_response_style]]`).
- Деструктивные → подтверди (§5.3).
- Коммитишь → детальный коммит (§5.4), пушишь в `origin main` (`[[feedback_git_push_workflow]]`).

### Шаг 5: обновляй артефакты
- Новые решения пользователя → memory.
- Новые архитектурные сдвиги → обнови `CLAUDE.md`.
- Закончил фазу миграции → обнови чеклист в `MIGRATION_FLUTTER.md` §15 и историю в этом `HANDOFF.md` §4.

---

## 8. Контакты и внешние ресурсы

- **GitHub:** `alshfu/block-puzzle-pvp` (см. memory `[[reference_github]]`)
- **VPS:** `pvp.alshfu.com` (см. memory `[[reference_vps_server]]`)
- **Email пользователя:** `alshfu@gmail.com`
- **Имя в git:** `Alexander Shchetinin`
- **Pages URL:** через `gh-pages` ветку, base href `/block_puzzle_pvp/`

---

## 9. Конец заметки

Если что-то в этом документе устарело или противоречит реальности — **обнови сам** и пересохрани. Не оставляй следующему ассистенту устаревший хэндофф; это будет хуже, чем его отсутствие. Дату последнего обновления и подпись модели — в конце:

> Last updated: 2026-06-05 by Claude Opus 4.7. План миграции — `479b694`. Реализация Flutter ещё не начата.
