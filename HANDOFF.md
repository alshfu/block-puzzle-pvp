# HANDOFF — заметка для следующего AI-ассистента

**Кому:** Claude (или любой AI-ассистент), которого пользователь подключит к этому проекту в следующих сессиях.
**От кого:** обновлено Claude Opus 4.8, сессия 2026-06-10 (исходная версия — Opus 4.7, 2026-06-05).
**Зачем:** чтобы ты с порога понимал **что** сделано, **где** искать актуальное, **когда** какое решение принято и **почему**. Не переоткрывай то, что уже зафиксировано.

> Это не план и не ТЗ. План миграции — `MIGRATION_FLUTTER.md`, журнал фактически сделанного — `MIGRATION_PROGRESS.md`, правила игры — `TZ_BlockDuel_9x9.md`. Здесь — «как тут жить и не наломать дров».

---

## 1. TL;DR за 30 секунд

- Проект **BlockDuel 9×9** — соревновательный блок-пазл (тетромино на доске 9×9, очистка строк/столбцов/боксов).
- **Миграция на Dart + Flutter (+ Flame + Riverpod) ЗАВЕРШЕНА и влита в `main`** (merge `8a63a82`, 2026-06-09). Flutter-проект — в **корне** репозитория.
- Старый TS/React-фронт перенесён в **`legacy-ts/`** и ретайрнут. **НО:** его pure-TS ядро `legacy-ts/core` ещё **живое** — это зависимость Node PvP-сервера (`server/`).
- **Прод на Flutter Web.** Cut-over выполнен 2026-06-10 (`npm run deploy:flutter`) — GitHub Pages отдаёт Flutter-сборку. VPS-сервер не трогался (Flutter-клиент говорит по тому же WS-протоколу).
- **Архитектура — строго MVVM** (Model=ядро/репозитории, ViewModel=Riverpod-нотифайеры без `BuildContext`, View=виджеты без логики).
- **Стек:** Dart 3.12 / Flutter 3.44.1 / Flame 1.37 / Riverpod 3.3.1. **176 тестов** зелёные, `flutter analyze` чист.
- **IDE пользователя:** **IntelliJ IDEA Ultimate 2026.1.3** + плагины Flutter/Dart/Android. Бесплатные альтернативы (VS Code, Android Studio как «бесплатная», Cursor) **не предлагать** — оплачена JetBrains All Products подписка.
- **Источник правды по правилам** — `TZ_BlockDuel_9x9.md` (RU, v1.0).

---

## 2. Что (сделано / осталось)

### 2.1 Что реализовано (Flutter, в `main`)

- **Ядро** (`lib/core/`) — pure-Dart порт TS-ядра, **bit-for-bit детерминизм** доказан golden-тестами (VM + Web): PRNG, 7-bag, доска/очистки, scoring v1.6, бот 3 уровней, blitz/force-place.
- **UI/Flame** (`lib/ui/`, `lib/game/`) — доска/рука/score, drag-and-place + tap-to-rotate, 3 темы (neutral/candy/night) с дизайн-токенами 1:1, маскоты/ponies (`flutter_svg`), Confetti (Flame), ComboFlash, Toast/Pause.
- **Звук/музыка** (`lib/audio/`) — синтезируются в Dart (порт Web Audio), без аудиофайлов.
- **Контент** — Storage/Profile/Settings, ~120 ачивок (15 базовых + 105 PvP), Daily quests, детерминистичный resume, Arcade, Tutorial (5 шагов), магазин (две валюты, скины доски, power-ups), 12 аватаров.
- **Онлайн PvP** (`lib/online/`) — Dart-клиент к существующему Node/VPS-серверу (кросс-протокол): лобби, матчмейкинг, живой матч (reconnect+ремач), ELO-лидерборд, богатая онлайн-статистика, экран `/stats`.
- **Auth+sync** (`lib/auth/`) — Google sign-in (Firebase `blockduel-web`, web popup) + Firestore cross-device sync.
- **Сервер** (`server/`, Node+ws+tsx) — server-authoritative, ELO K=24; импортирует ядро из `legacy-ts/core`. Проведён аудит безопасности + SEC-1..3.

Снимок репо — memory `[[project_state]]`; прогресс по фазам — `MIGRATION_PROGRESS.md`.

### 2.2 Что осталось

- **Прод cut-over** — ✅ выполнен 2026-06-10 (Pages на Flutter Web). Осталось: post-cutover hardening сервера на VPS (`REQUIRE_ROOM_TOKEN=1` + `ALLOWED_ORIGINS`, см. `DEPLOY.md`), когда старых TS-вкладок не останется.
- Визуальный **gate pixel-parity** во всех 3 темах (приёмка пользователя, вне кода).
- Ручная проверка онлайна / Google-входа / Firestore-синка (`flutter run -d chrome`).
- Нативный Google-вход (Android/iOS — `flutterfire configure`), `firestore.rules` в `blockduel-web`, богатая облачная схема.
- Android SDK + iOS Simulator runtime (для нативных сборок).
- Снять/архивировать устаревшую ветку `flutter-migration` (и `origin/`).
- **Фаза 9 (Dart-сервер) НЕ делается** — решено остаться на Node/VPS-сервере.

---

## 3. Где (карта проекта)

### 3.1 Корень репо (после реструктуризации 2026-06-09)

```
block_puzzle_pvp/   (= Flutter-проект block_duel в корне)
├── CLAUDE.md                # ← project instructions (ВСЕГДА читай первым)
├── HANDOFF.md               # ← этот файл
├── TZ_BlockDuel_9x9.md      # ← источник правды по правилам игры (RU)
├── MIGRATION_FLUTTER.md     # ← план миграции (выполнен)
├── MIGRATION_PROGRESS.md    # ← журнал фактически сделанного (с датами/коммитами)
├── ROADMAP.md               # ← фазы развития (Фаза M = миграция; дальше — фичи)
├── CHANGELOG.md             # ← релизы (верхний — 2.0.0, Flutter-порт)
├── DEPLOY.md                # ← деплой Pages + VPS + frontend cut-over
├── INTERFACE_PARITY.md      # ← чеклист UI-паритета с TS
├── SECURITY_AUDIT_SERVER.md # ← аудит PvP-сервера
├── pubspec.yaml             # ← Flutter/Flame/Riverpod (version 2.0.0)
├── lib/                     # ← Dart-код: core/game/ui/online/auth/storage/...
├── test/                    # ← flutter_test (176)
├── integration_test/        # ← E2E pilot (app_test.dart)
├── web/ android/ ios/ macos/ assets/   # ← Flutter-платформы/ассеты
├── server/                  # ← Node WS сервер (живой, прод; тянет legacy-ts/core)
├── legacy-ts/               # ← бывший src/: TS/React-фронт (ретайрнут; core живо)
├── party/                   # ← опц. PartyKit-вариант (не используется)
├── tools/                   # ← bot-sim.ts, gen_test_plan.py, pentest_local.mjs
├── qa/                      # ← QA-тест-планы по платформам
├── legacy/                  # ← инертный визуальный референс (НЕ ТРОГАТЬ)
├── package.json index.html vite.config.ts  # ← TS/Vite сборка (legacy/откат)
└── .github/workflows/deploy.yml.disabled    # ← Actions выключен (биллинг)
```

> ⚠️ Многие старые доки/комментарии всё ещё говорят `src/...` или `flutter/lib/...` — читать как `legacy-ts/...` и `lib/...` соответственно.

### 3.2 Где жить твоей памяти

```
~/.claude/projects/-Users-al-sh-WebstormProjects-block-puzzle-pvp/memory/
├── MEMORY.md                # индекс — всегда в твоём контексте
├── project_*.md             # снимки и решения по проекту
├── user_*.md                # профиль пользователя (язык, IDE)
├── reference_*.md           # внешние ресурсы (TZ, GitHub, VPS, Firebase, QA)
├── feedback_*.md            # правила работы (ответы, коммиты, push, docs-sync, стиль Dart, MVVM)
└── behavior_*.md            # инварианты (core determinism)
```

**Важно:** обновляй memory, как только узнаёшь новое о пользователе/проекте. Не дублируй то, что читается из git/файлов.

### 3.3 Где запущенный сервер

- **VPS:** `pvp.alshfu.com`, Ubuntu 24.04 · **systemd unit:** `blockduel-pvp.service` · **nginx + Let's Encrypt** (WSS).
- **Перезапуск:** `git pull && systemctl restart blockduel-pvp` — **делает пользователь сам**, у тебя нет SSH-доступа.
- ⚠️ **Не трогать** `/etc/nginx/sites-enabled/alshfu-arena.conf` на VPS — это сторонний сайт пользователя.

---

## 4. Когда (хронология решений)

| Дата | Событие | Где зафиксировано |
|------|---------|--------------------|
| ранее | Реализованы Фазы 1–4 ТЗ на TS (ядро, UI, vs Bot, Hot-seat, Online PvP, прогрессия, магазин, ачивки) | git log + `CLAUDE.md` |
| **2026-06-05** | Пользователь запросил миграцию на Dart/Flutter; создан `MIGRATION_FLUTTER.md` (`479b694`); зафиксированы IDE (IDEA Ultimate), Riverpod, MVVM, pixel-parity, стиль коммитов | memory + git |
| 2026-06-05…07 | Фазы 0–5 (ядро+golden, UI shell, бот/blitz, storage/ачивки/daily/resume, декор/звук/музыка) | `MIGRATION_PROGRESS.md` |
| 2026-06-07…08 | Фаза 6 (6A online + 6B auth/sync), UI-паритет §8/§4, Фаза 7 (shop/powerups/arcade/tutorial/hardening) | `MIGRATION_PROGRESS.md` |
| 2026-06-09 | Фаза 3b (онлайн-статистика+PvP-ачивки+/stats), security-аудит + SEC-1..3, обвязка Фазы 8 cut-over, реструктуризация (Flutter→корень, src/→legacy-ts/), **merge в `main`** (`8a63a82`) | git log |
| 2026-06-10 | Актуализация доков (README, ROADMAP, CHANGELOG 2.0.0, MIGRATION_PROGRESS, MIGRATION_FLUTTER, этот HANDOFF) | git log |
| 2026-06-10 | **Прод cut-over**: Pages переключён на Flutter Web (`npm run deploy:flutter`, gh-pages `e6c30a1`) | git log + DEPLOY.md |

Текущая версия: **v2.0.0** (`pubspec.yaml`). Legacy TS-версия — `v1.6.1` (`package.json`).

---

## 5. Правила работы (read this before doing anything)

### 5.1 Из CLAUDE.md (project instructions, обязательно)

- **Идентификаторы и комментарии в коде — английский** (`BoardCell`, `enumerateMoves`, `RuleConfig`).
- **Документация и общение — русский**; технические термины можно оставлять английскими.
- **Не дублировать игровую логику** — всё через ядро: в Flutter `lib/core/`, на сервере — импорт из `legacy-ts/core`. Держать оба ядра bit-for-bit идентичными (golden-gate).
- **Не править `legacy/`** — инертный референс.
- **Не отходить от ТЗ** по правилам/балансу без явного запроса.
- **Не возвращать `deploy.yml.disabled`** в `deploy.yml` без подтверждения (биллинг).
- **Не пушить с красными тестами** — Pages закэширует сломанный сайт.
- **Не трогать nginx-конфиг чужого сайта** на VPS.

### 5.2 Из memory (правила пользователя)

- **`[[user_language]]`** — пользователь пишет по-русски, отвечай по-русски.
- **`[[user_ide]]`** — IDE = JetBrains; **никаких** VS Code / Android Studio / Cursor / Zed как «лучшей альтернативы».
- **`[[feedback_response_style]]`** — сразу создавать файлы без лишних вопросов (но не путать с destructive actions, §5.3).
- **`[[feedback_git_push_workflow]]`** — пушить в `origin main` после значимых изменений.
- **`[[feedback_keep_docs_updated]]`** — при значимых изменениях держать актуальными ВСЕ важные файлы (README/ROADMAP/CHANGELOG/доки) и синхронизировать git — без отдельного напоминания.
- **`[[feedback_commit_style]]`** — каждый этап = подробный коммит (заголовок + тело Что/Где/Когда/Почему).
- **`[[feedback_dart_style]]`** — свод правил Dart + подробная шапка в каждом файле; константы lowerCamelCase.
- **`[[feedback_mvvm_architecture]]`** — строгий MVVM (см. §1).
- **`[[behavior_core_determinism]]`** — ядро обязано оставаться чистым и детерминированным.

### 5.3 Destructive actions — стоп-сигналы

Несмотря на «без лишних вопросов», **всегда подтверждай** перед:
- `git reset --hard`, `git push --force` (особенно в `main`)
- удалением файлов/веток, `rm -rf`
- коммитом, который **удаляет** содержимое source-of-truth файлов (TZ, CLAUDE.md и т.п.) — такое уже было 2026-06-05 (TZ оказался пуст в working tree, я остановился и спросил → restore)
- модификацией CI/деплоя (особенно `deploy.yml.disabled`)
- любыми действиями на VPS (доступа нет; даже инструкции — с предупреждением)

### 5.4 Стиль коммитов

```
<type>(<scope>): <subject под 70 символов>

Что: 1-3 предложения сути.
Где: список файлов / разделов (§N названия).
Когда: дата сессии, контекст.
Почему: мотивация / триггер / ссылка на ТЗ / запрос пользователя.

Co-Authored-By: Claude <model-name> <noreply@anthropic.com>
```

Для опечаток/lint/bump — короткий заголовок OK.

---

## 6. IDE: IntelliJ IDEA Ultimate 2026.1.3

### 6.1 Версия и лицензия

- **IntelliJ IDEA Ultimate 2026.1.3** (зафиксировано 2026-06-05). Лицензия **JetBrains All Products Pack** (платная). Для Flutter пользователь работает в IDEA Ultimate (не Android Studio).

### 6.2 Что установлено/настроено

- **Плагины:** `Flutter` (Google), `Dart` (JetBrains, подтягивается с Flutter), `Android` (Google) — для AVD/Android без отдельной Android Studio.
- **Flutter SDK path:** Settings → Languages & Frameworks → Flutter (`flutter doctor` сначала зелёный).
- **Run Configurations** (`.idea/runConfigurations/`): Flutter (Web, Chrome), Flutter Test (all/core), Generate (build_runner), Update Goldens.
- **Hot Reload:** Cmd+\\ / Ctrl+\\ · **Hot Restart:** Shift+Cmd+\\ · **Flutter Inspector:** View → Tool Windows.

### 6.3 Что НЕ предлагать

- ❌ Android Studio как «бесплатную альтернативу», ❌ VS Code / Cursor / Zed, ❌ установку `code`/`cursor` CLI.

---

## 7. Если ты пришёл начать работу — пошагово

1. **Прочти контекст:** `CLAUDE.md` → этот `HANDOFF.md` → memory index (`MEMORY.md`, уже в контексте).
2. **Проверь актуальность:** перед утверждениями про код — `git status` / `git log -5` / `Read` нужный файл. Память отражает прошлое, файлы — настоящее.
3. **Пойми намерение:**
   - конкретное действие — выполняй (правила §5);
   - «продолжить» — открой `MIGRATION_PROGRESS.md` (где остановились) + `ROADMAP.md` (что дальше);
   - «починить прод» — теперь это **Flutter-сборка** на Pages (`lib/`, деплой `npm run deploy:flutter`); TS-сборка (`legacy-ts/`) — путь отката (`npm run deploy`).
4. **Работай по правилам:** мелкие правки — сразу; деструктивные — подтверди (§5.3); коммит — детальный (§5.4); пуш — в `origin main`.
5. **Обновляй артефакты:** новые решения → memory; архитектурные сдвиги → `CLAUDE.md`; прогресс → `MIGRATION_PROGRESS.md`; релиз → `CHANGELOG.md`; держи доки в актуальном состоянии (`[[feedback_keep_docs_updated]]`).

---

## 8. Контакты и внешние ресурсы

- **GitHub:** `alshfu/block-puzzle-pvp` (memory `[[reference_github]]`)
- **VPS:** `pvp.alshfu.com` (memory `[[reference_vps_server]]`)
- **Firebase:** проект `blockduel-web` (memory `[[reference_firebase]]`)
- **Email:** `alshfu@gmail.com` · **git:** `Alexander Shchetinin`
- **Pages:** через `gh-pages` ветку, base href `/block-puzzle-pvp/`

---

## 9. Конец заметки

Если что-то здесь устарело или противоречит реальности — **обнови сам** и пересохрани. Устаревший хэндофф хуже его отсутствия.

> Last updated: 2026-06-10 by Claude Opus 4.8. Миграция на Flutter завершена и влита в `main` (`8a63a82`); **прод переключён на Flutter Web** (cut-over `deploy:flutter`, gh-pages `e6c30a1`). 176 тестов зелёные. Остаётся post-cutover hardening сервера на VPS.
