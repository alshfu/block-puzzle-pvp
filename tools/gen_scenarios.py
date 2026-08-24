#!/usr/bin/env python3
"""gen_scenarios.py — генератор сквозного каталога сценариев BlockDuel 9×9.

Назначение
    Детерминированно собирает каталог из РОВНО 1001 сквозного пользовательского
    сценария «всего приложения»: (область × функция × состояние/вариация) →
    конкретные шаги и ожидаемый результат. В отличие от платформенных
    чеклистов (tools/gen_test_plan.py → qa/TEST_PLAN_<p>.md), этот каталог —
    единый, платформо-независимый, с устойчивыми ID (APP-0001…APP-1001), пригоден
    как индекс для ручного прогона И как источник имён для автотестов.

    Правило «1000 и 1»: файл фиксирует ровно 1001 пункт. Сценарии генерируются
    по областям приложения с запасом (> 1001), затем детерминированно
    чередуются по кругу (round-robin по областям) и обрезаются до 1001 — так
    покрытие остаётся сбалансированным по всем областям, а не проседает в конце.

    Каждый ~7-й пункт помечен [C] — критический smoke-срез для быстрой регрессии.

Гибрид «генератор + образец»
    Часть этих сценариев дублируется исполняемыми автотестами в
    test/scenarios/app_scenarios_test.dart (ссылаются на APP-ID в названиях).
    Каталог — полное пространство; автотесты — проверяемый образец поверх него.

Запуск
    python3 tools/gen_scenarios.py
    (без аргументов; перезаписывает qa/SCENARIOS_APP.md; печатает итоговый счётчик)

Расширение (следующие оси по ROADMAP пользователя)
    Функция build_app_catalog() параметризована областями; для «1001 на режим»
    и «1001 на код/платформу» добавляются аналогичные build_mode_catalog(mode) /
    build_platform_catalog(p) с тем же round-robin-механизмом exactly_n().
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = 1001

# ── Справочники предметной области (из CLAUDE.md / ТЗ / кода) ─────────────────

THEMES = ["neutral", "candy", "night"]
PIECES = ["I", "O", "T", "S", "Z", "J", "L"]
ORIENTS = ["0°", "90°", "180°", "270°"]
PLACEMENTS = [
    "в центр", "к верхней границе", "к нижней границе", "к левому краю",
    "к правому краю", "в угол", "на занятые клетки (отказ)",
    "частично за доску (отказ)",
]
BOT_LEVELS = ["easy", "medium", "hard"]
BLITZ_PRESETS = ["normal", "fast", "hardcore", "выключен"]
CLEAR_TYPES = ["строка", "столбец", "бокс 3×3", "мульти-2", "мульти-3", "мульти-4"]
POWERUPS = [
    "hint (подсказка)", "swap_hand (смена руки)", "auto_play (авто-ход)",
    "stick_row (очистка строки)", "stick_col (очистка столбца)",
    "bomb_3x3 (бомба 3×3)",
]
SKINS = ["plain", "gem", "candy", "bullet", "neon", "pixel"]
CRYSTAL_PACKS = ["малый", "средний (+10%)", "крупный (+20%)", "мега (+35%)"]

# Маршруты роутера (lib/ui/router.dart) с человекочитаемым именем экрана.
ROUTES = [
    ("/", "Меню"), ("/setup/:mode", "Setup (выбор матча)"),
    ("/game/:mode", "Игра 9×9"), ("/profile", "Профиль"),
    ("/stats", "Статистика"), ("/settings", "Настройки"),
    ("/theme-builder", "Конструктор тем"), ("/achievements", "Достижения"),
    ("/memory", "Память: соло"), ("/coop", "Co-op Tetris"),
    ("/memory-duel", "Память: дуэль"), ("/match3", "Match-3 PvP"),
    ("/tetris", "Co-op Tetris (alias)"), ("/puzzle", "Силуэты"),
    ("/daily", "Daily"), ("/quests", "Квесты"), ("/season", "Сезонный пропуск"),
    ("/showcase", "Авто-шоу (ИИ vs ИИ)"), ("/shop", "Магазин"),
    ("/tutorial", "Туториал"), ("/online", "Онлайн-меню"),
    ("/leaderboard", "Лидерборд"), ("/online/game/:roomId", "Онлайн-матч"),
]

MODES = [
    "vs Bot (easy)", "vs Bot (medium)", "vs Bot (hard)", "Hot-seat",
    "Bot vs Bot (зритель)", "Аркада (соло)", "Память: соло", "Память: дуэль",
    "Co-op Tetris", "Match-3 PvP", "Силуэты", "Онлайн PvP",
]

SETTINGS_TOGGLES = [
    "Звук (soundOn)", "Музыка (musicOn)", "Громкость SFX", "Громкость музыки",
    "Вибрация", "Уменьшить движение (reduceMotion)", "Конфетти", "Маскоты",
    "Призрак фигуры (ghost)", "Задержка бота", "Тема по умолчанию",
    "Правила по умолчанию (handSize/rotation/flip)", "Пресет блица",
    "Нейтральные клетки (accessibility)", "Язык интерфейса",
]

WIRE_MESSAGES = [
    "hello", "joined", "state", "move", "move_rejected", "opponent_left",
    "opponent_reconnected", "rematch_request", "rematch_cancel",
    "rematch_status", "resign", "error",
]
ONLINE_FLOWS = [
    "поиск соперника (matchmaking)", "bot-fallback при пустой очереди",
    "получение joined и старт матча", "свой ход (move) и валидация сервером",
    "чужой ход и обновление доски", "anti-cheat ориентаций (отклонение move)",
    "разрыв связи и reconnect с backoff", "повторный hello после reconnect",
    "накопители матча сохраняются при reconnect (тот же matchId)",
    "ремач приходит как state с новым matchId и обнуляет накопители",
    "соперник вышел (opponent_left + таймаут)", "соперник вернулся",
    "сдаться (resign) — мгновенное поражение", "запрос и отмена реванша",
    "завершение по deadlock", "завершение по timeout (force-place)",
    "ELO-обновление K=24", "запись W/L/D в профиль",
    "запись накопительной онлайн-статистики", "разблокировка PvP-ачивок",
    "подписка на лидерборд и свой ранг",
]
NET_CONDITIONS = [
    "стабильная сеть", "потери пакетов/флапы", "высокая задержка (>500мс)",
    "обрыв в момент своего хода",
]

ACH_CHECKS = [
    "разблокируется ровно при достижении порога условия",
    "НЕ разблокируется на значении чуть ниже порога",
    "показывает тост при первой разблокировке",
    "XP начисляется ровно один раз",
    "остаётся разблокированным после перезапуска",
    "разблокировка синхронизируется в облако (union при merge)",
]


def load_achievements():
    """Парсит (id, title) достижений из lib/achievements/definitions.dart.

    Возвращает список пар; при недоступности файла — пустой список (генератор
    деградирует, но не падает: осмысленной массы хватает и без ачивок).
    """
    path = os.path.join(ROOT, "lib", "achievements", "definitions.dart")
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        print("  ! definitions.dart не найден — раздел ачивок будет пуст")
        return []
    ids = re.findall(r"id:\s*'([^']+)'", text)
    titles = re.findall(r"title:\s*'([^']+)'", text)
    pairs = list(zip(ids, titles))
    if not (110 <= len(pairs) <= 130):
        print(f"  ! предупреждение: найдено {len(pairs)} достижений (ожидалось ~120)")
    return pairs


# ── Области приложения: каждая возвращает список строк-сценариев ──────────────

def area_lifecycle():
    out = [f"Холодный старт с темой «{t}» — без белой вспышки, фон применён" for t in THEMES]
    out += [
        "Тёплый старт из фона — экран и состояние восстановлены",
        "Сворачивание/разворачивание во время матча — таймер и бот не рассинхронятся",
        "Перезапуск во время матча — карточка «Продолжить» предлагает resume",
        "Resume даёт бит-в-бит ту же раздачу 7-bag (детерминизм drawCounts)",
        "Первый запуск без сохранений — дефолтные профиль/настройки/тема",
        "Запуск при повреждённом сохранении — graceful fallback к дефолтам",
        "Усечённая сохранёнка (доска < 81 клетки) — resume отвергает, не поднимает полупустую доску",
        "Версия приложения (2.0.0+1) и слоган видны в меню",
        "Двойной быстрый тап по «Играть» не создаёт две партии",
    ]
    return out


def area_navigation():
    out = []
    for path, name in ROUTES:
        out.append(f"Открытие «{name}» ({path}) из точки входа — рисуется без ошибок")
        out.append(f"Возврат с «{name}» — предыдущий экран без потери состояния")
        out.append(f"«{name}» на узком окне — нет horizontal overflow, скролл где нужно")
        out.append(f"«{name}» на широком окне — адаптивная боковая раскладка/центрирование")
        out.append(f"«{name}» при reduceMotion=on — декор статичен, переходы без анимации")
        for t in THEMES:
            out.append(f"«{name}» в теме «{t}» — цвета/контраст по design-токенам")
    out.append("Deep-link на несуществующий /game/:mode — редирект/ошибка без краша")
    out.append("Возврат системной кнопкой Back с онлайн-матча — предупреждение о выходе")
    return out


def area_core():
    out = []
    for p in PIECES:
        for o in ORIENTS:
            for pl in PLACEMENTS:
                out.append(f"Фигура {p} ({o}): постановка {pl} — призрак и валидация корректны")
    for ct in CLEAR_TYPES:
        for lvl in range(1, 11):
            out.append(f"Очистка «{ct}» при комбо={lvl}: множитель 1+0.1·min({lvl},10) и очки по формуле")
    out += [
        "Очистка начисляет очки игроку, чей ход её вызвал",
        "Бокс 3×3 даёт бонус выше строки/столбца (box=15 по умолчанию)",
        "Мульти-очистка: множитель +15% за каждую доп. очистку",
        "Perfect clear даёт +15 и запускает конфетти/звук",
        "Комбо растёт по подряд идущим очисткам; cap=10",
        "Speed-бонус до +40% при ходе с >50% оставшегося времени",
        "Placement-бонус: I=+5, L/J=+3, T/S/Z=+1, O=0",
        "base=N·(N+1)/2 совпадает с ТЗ",
        "7-bag: каждая фигура по разу за цикл (свой мешок у игрока)",
        "Тупик (deadlock): партия завершается, победитель по очкам, ничья при равенстве",
    ]
    return out


def area_clears_geometry():
    out = []
    for r in range(9):
        out.append(f"Полная строка {r}: заполнение → очистка всей строки, счёт игроку")
    for c in range(9):
        out.append(f"Полный столбец {c}: заполнение → очистка всего столбца, счёт игроку")
    for br in range(3):
        for bc in range(3):
            out.append(f"Полный бокс 3×3 [{br},{bc}]: заполнение → очистка бокса, счёт игроку")
    return out


def area_blitz():
    out = []
    for preset in BLITZ_PRESETS:
        out.append(f"Блиц-пресет «{preset}»: старт-время и decay применяются к раунду")
        out.append(f"Блиц «{preset}»: истечение времени → force-place выбранной/первой фигуры")
        out.append(f"Блиц «{preset}»: пауза останавливает тик, снятие — возобновляет")
    out += [
        "turnTimeForRound убывает: 12 → 12·0.4^k, но не ниже turnTimeMin=3",
        "force-place предпочитает selectedPieceId, иначе первый валидный ход",
        "force-place при отсутствии ходов завершает партию",
        "Таймер не рассинхронится после resume в pvbot",
    ]
    return out


def area_modes():
    out = []
    for m in MODES:
        out.append(f"Режим «{m}»: запуск из меню/Setup — корректная стартовая доска и рука")
        out.append(f"Режим «{m}»: адаптивная боковая раскладка на широком окне")
        out.append(f"Режим «{m}»: завершение партии — экран результата с корректным исходом")
    out += [
        "Память: соло — фигуры показываются N секунд, затем прячутся; рекорд сохраняется",
        "Память: дуэль — оба игрока по очереди, показ ограничен time-budget",
        "Co-op Tetris 10×20 — линии очищаются, generic-доска, счёт общий",
        "Match-3 8×8 — своп рядом даёт серию ≥3, каскады с множителем, лимит ходов",
        "Match-3 — своп без серии откатывается",
        "Match-3 — resolveBoard завершается даже при цепочке каскадов (потолок 128)",
        "Силуэты — рука ограничена решением; постановка только внутри маски",
        "Силуэты — контур собран → «решено», начисление очков по сложности",
        "Силуэты — hint подсвечивает валидный ход внутри маски",
        "Силуэты — битый внешний пак (клетка вне сетки) отвергается с ошибкой, без краша",
        "Composite-score — сводный рейтинг floor(0.4·general+0.6·avg по режимам)",
        "Авто-шоу — ИИ vs ИИ в 9:16, кнопка записи клипа",
    ]
    return out


def area_online(flows):
    out = []
    for f in flows:
        out.append(f"Онлайн: {f}")
    for cond in NET_CONDITIONS:
        out.append(f"Онлайн при условии сети «{cond}»: матч остаётся консистентным")
    for msg in WIRE_MESSAGES:
        out.append(f"Wire-сообщение «{msg}»: разбор и редьюс в OnlineMatchState без рассинхрона")
    out += [
        "reconnect: старые подписки incoming/status не дублируют колбэки",
        "server-authoritative: клиентский счёт не расходится с серверным",
        "ELO: победа/поражение/ничья двигают рейтинг по K=24",
    ]
    return out


def area_progression():
    out = [
        "XP по структурной формуле (ROADMAP § 8.1) начисляется за матч",
        "Ничья даёт множитель XP 0.5",
        "Уровень растёт по накоплению XP; награды за уровень выдаются один раз",
        "Уровни > 100 не крешат (награды по линейной формуле)",
        "Daily-квесты обновляются раз в сутки; прогресс копится",
        "Сезонный пропуск: XP → тиры; премиум-трек за 990 💎",
        "Сезонный премиум: атомарное списание, двойной тап не спишет дважды",
        "Стрик побед увеличивает множитель",
    ]
    for m in ["9×9", "Память", "Co-op", "Match-3", "Силуэты"]:
        out.append(f"Прогресс режима «{m}» отражается в статистике и composite-score")
    return out


def area_shop():
    out = []
    for pu in POWERUPS:
        out.append(f"Power-up «{pu}»: покупка за монеты, списание из инвентаря при применении")
        out.append(f"Power-up «{pu}»: недоступен в онлайне/если не ход человека")
    for s in SKINS:
        out.append(f"Скин клеток «{s}»: покупка/экипировка, отражается на доске")
    for cp in CRYSTAL_PACKS:
        out.append(f"Пакет кристаллов «{cp}»: бонус-процент начислен, purchase_service (стаб)")
    out += [
        "Конструктор тем: разблокировка за 5000 💎, live-preview, activeThemeProvider",
        "Кастомная тема: сохранение/загрузка; одна битая тема не сбрасывает весь список",
        "Недостаточно валюты — покупка отклонена с понятным сообщением",
        "Магазин: категории power-ups/скины/кристаллы/темы разделены",
    ]
    return out


def area_achievements(achs):
    out = []
    for (aid, title) in achs:
        for chk in ACH_CHECKS:
            out.append(f"Ачивка «{title}» ({aid}): {chk}")
    if not achs:
        out.append("Каталог достижений: ~120 ачивок, категории и иконки корректны")
    return out


def area_settings():
    out = []
    for t in SETTINGS_TOGGLES:
        out.append(f"Настройка «{t}»: изменение применяется немедленно и переживает перезапуск")
    out += [
        "Сброс настроек к дефолтам — все тумблеры в исходное",
        "reduceMotion=on гасит конфетти/маскотов/фоновую анимацию везде",
        "Нейтральные клетки (accessibility) отключают цветовую зависимость владельца",
    ]
    return out


def area_audio():
    out = []
    for ev in ["place", "clear×N", "perfect", "win", "lose", "draw", "click", "combo-flash"]:
        out.append(f"SFX «{ev}»: воспроизводится в нужный момент, уважает soundOn/громкость")
    out += [
        "Фоновая музыка стартует/останавливается по musicOn",
        "Синтез звука не блокирует UI-поток",
        "При reduceMotion звук не отключается (отдельная настройка)",
    ]
    return out


def area_storage_auth():
    out = [
        "Save/resume: доска, счёт, мешки (queue+counter+rngState) восстановлены точно",
        "resume 7-bag детерминистичен: следующие фигуры совпадают",
        "Профиль/статистика/настройки персистятся в SharedPreferences",
        "Google sign-in через Firebase: вход/выход, аватар/ник",
        "Firestore cross-device sync: слияние профилей (max-wins, union ачивок, +кристаллы)",
        "Оффлайн-правки мёрджатся при следующем входе без потери прогресса",
        "Выход из аккаунта не стирает локальный прогресс",
        "Повреждённая запись профиля в облаке — graceful fallback к локальной",
    ]
    return out


def area_notifications_feedback():
    return [
        "Opt-in уведомлений: запрос разрешения, префы сохраняются",
        "Отключение уведомлений в настройках прекращает подписки",
        "In-app rating prompt показывается после 5+ матчей, не раньше",
        "Rating prompt: snooze откладывает повторный показ",
        "Rating prompt не показывается повторно после оценки",
    ]


def area_i18n_a11y_perf():
    out = [
        "Интерфейс полностью на русском; технические термины допустимы",
        "Длинные строки не обрезаются и не ломают лэйаут",
        "Контраст текста/фона удовлетворяет базовой доступности во всех темах",
        "60 fps на матче со средней доской (нет заметных фризов)",
        "Нет утечек таймеров/подписок при многократном входе/выходе из экранов",
        "Крупные списки (ачивки, лидерборд) прокручиваются плавно",
    ]
    return out


def crit(numbered, every=7):
    """Помечает каждый every-й пункт как критический [C]."""
    res = []
    for i, s in enumerate(numbered):
        res.append(("[C] " + s) if (i % every == 0) else s)
    return res


def exactly_n(sections, n, filler=None):
    """Round-robin по областям до ровно n (сбалансированное покрытие).

    sections: список (area_name, [строки]). Осмысленные («первичные») области
    раскладываются по кругу; если их суммарно >= n — обрезка до n. Если меньше —
    остаток добирается из filler=(name, fn(k)->[k строк]): режимы малой игровой
    поверхности (tutorial/showcase) добирают хвост осмысленным seed-sweep'ом
    (детерминированные property-прогоны), а не пустым филлером. Без filler и при
    нехватке — ошибка (нужно обогатить области).
    """
    queues = [(name, list(items)) for name, items in sections]
    picked = []
    idx = 0
    remaining = sum(len(q) for _, q in queues)
    while remaining > 0 and len(picked) < n:
        name, q = queues[idx % len(queues)]
        if q:
            picked.append((name, q.pop(0)))
            remaining -= 1
        idx += 1
    if len(picked) < n:
        if filler is None:
            raise SystemExit(
                f"Сгенерировано {len(picked)} < {n}: обогатите области или задайте filler")
        fname, ffn = filler
        for text in ffn(n - len(picked)):
            picked.append((fname, text))
    return picked[:n]


def build_app_catalog():
    achs = load_achievements()
    sections = [
        ("Запуск и жизненный цикл", area_lifecycle()),
        ("Навигация и экраны", area_navigation()),
        ("Ядро игры", area_core()),
        ("Геометрия очисток", area_clears_geometry()),
        ("Блиц-таймер", area_blitz()),
        ("Режимы", area_modes()),
        ("Онлайн PvP", area_online(ONLINE_FLOWS)),
        ("Прогрессия", area_progression()),
        ("Магазин и монетизация", area_shop()),
        ("Достижения", area_achievements(achs)),
        ("Настройки", area_settings()),
        ("Звук", area_audio()),
        ("Хранение и синхронизация", area_storage_auth()),
        ("Уведомления и оценка", area_notifications_feedback()),
        ("Локализация, доступность, производительность", area_i18n_a11y_perf()),
    ]
    return exactly_n(sections, TARGET)


def render_catalog(title, intro_lines, prefix, picked):
    """Единый рендер каталога: заголовок, оглавление по областям, нумерация с ID.

    prefix — префикс ID («APP», «MODE-BOT»…); картинка нумерации `{prefix}-NNNN`.
    """
    lines = [f"# {title}", ""]
    lines += intro_lines
    lines.append("")
    tagged = crit([f"[{name}] {text}" for name, text in picked])
    counts = {}
    for name, _ in picked:
        counts[name] = counts.get(name, 0) + 1
    lines.append("## Покрытие по областям")
    lines.append("")
    for name in dict.fromkeys(n for n, _ in picked):
        lines.append(f"- {name}: {counts[name]}")
    lines.append("")
    lines.append("## Сценарии")
    lines.append("")
    for i, text in enumerate(tagged, start=1):
        lines.append(f"{i}. **{prefix}-{i:04d}** — {text}")
    lines.append("")
    return "\n".join(lines)


# ── Ось «режим»: 1001 сценарий на каждый режим ───────────────────────────────
#
# Профиль режима задаёт игровую поверхность (доска, ввод, механика) и флаги-
# трейты, по которым собираются ОБЩИЕ разделы; уникальная механика — в
# специфичных билдерах по family. Хвост добирается осмысленным seed-sweep'ом.

MODE_PROFILES = [
    # 9×9-дуэль (одно ядро, разные оппоненты/цели).
    dict(id="bot", title="С ботом (9×9)", route="/setup/bot", family="duel9",
         board="9×9", bot=True, timer=True, save=True),
    dict(id="hotseat", title="Вдвоём — hot-seat (9×9)", route="/setup/hotseat",
         family="duel9", board="9×9", two_human=True, timer=True, save=True),
    dict(id="arcade", title="Аркада — соло на рекорд (9×9)", route="/game/arcade",
         family="duel9", board="9×9", solo=True, timer=True, save=True),
    dict(id="botvbot", title="Бот × бот — зритель (9×9)", route="/setup/botvbot",
         family="duel9", board="9×9", bot=True, spectator=True, timer=True),
    dict(id="online", title="Онлайн PvP (9×9)", route="/online", family="duel9",
         board="9×9", online=True, timer=True),
    # Память.
    dict(id="memorySolo", title="Память: соло", route="/memory", family="memory",
         board="9×9", solo=True, save=True),
    dict(id="memoryDuel", title="Память: дуэль", route="/memory-duel",
         family="memory", board="9×9", two_human=True),
    # Прочие жанры.
    dict(id="coop", title="Co-op Tetris (10×20)", route="/coop", family="coop",
         board="10×20", save=True),
    dict(id="match3", title="Match-3 PvP (8×8)", route="/match3", family="match3",
         board="8×8", two_human=True),
    dict(id="tetris", title="Классический Tetris (10×20)", route="/tetris",
         family="tetris", board="10×20", solo=True, save=True),
    dict(id="puzzle", title="Силуэты", route="/puzzle", family="puzzle",
         board="переменная", solo=True, save=True),
    dict(id="showcase", title="Авто-шоу — ИИ vs ИИ (9:16)", route="/showcase",
         family="showcase", board="9×9", spectator=True),
    dict(id="tutorial", title="Обучение (5 шагов)", route="/tutorial",
         family="tutorial", board="9×9"),
]

INPUT_VERBS = ["тап", "drag-and-drop", "клавиатура"]


def gen_lifecycle(p):
    out = [
        f"Запуск «{p['title']}» из меню по маршруту {p['route']} — экран рисуется без ошибок",
        f"Возврат из «{p['title']}» в меню — стек навигации корректен, без утечек",
    ]
    if p.get("route", "").startswith("/setup"):
        out += [
            f"Setup режима: выбор правил (handSize/rotation/flip) и старт партии",
            f"Setup режима: пресет блица применяется к первой партии",
            f"Setup режима: отмена возвращает в меню без создания партии",
        ]
    for t in THEMES:
        out.append(f"Холодный старт «{p['title']}» в теме «{t}» — без белой вспышки")
    if p.get("save"):
        out += [
            f"Сворачивание во время «{p['title']}» → resume восстанавливает состояние точно",
            f"Перезапуск во время «{p['title']}» → карточка «Продолжить» предлагает resume",
            f"resume «{p['title']}» детерминистичен (та же раздача/seed)",
        ]
    if p.get("online"):
        out += [
            "Выход из онлайн-матча системной Back — предупреждение о поражении",
            "Reconnect после обрыва — матч продолжается с сохранением накопителей",
        ]
    out.append(f"Двойной быстрый тап по старту «{p['title']}» не создаёт две партии")
    return out


def gen_render(p):
    surfaces = ["доска", "HUD (счёт/таймер)", "панель руки", "экран результата",
                "пауза/меню выхода"]
    if p["family"] == "puzzle":
        surfaces = ["сетка-маска", "рука фигур", "HUD (ходы/цель)", "экран результата"]
    if p["family"] == "memory":
        surfaces = ["фаза показа", "фаза скрытия", "фаза воспроизведения",
                    "HUD (таймер показа)", "экран результата"]
    out = []
    for s in surfaces:
        for t in THEMES:
            out.append(f"«{p['title']}»: поверхность «{s}» в теме «{t}» — цвета/контраст по токенам")
        out.append(f"«{p['title']}»: «{s}» при reduceMotion=on — статичный декор")
        out.append(f"«{p['title']}»: «{s}» на узком окне — нет overflow")
        out.append(f"«{p['title']}»: «{s}» на широком окне — адаптивная боковая раскладка")
        out.append(f"«{p['title']}»: «{s}» с нейтральными клетками (a11y) — не зависит от цвета владельца")
    return out


def gen_input(p):
    out = []
    if p["family"] in ("duel9", "coop", "puzzle"):
        for v in INPUT_VERBS:
            for pc in PIECES:
                out.append(f"«{p['title']}»: выбор и постановка фигуры {pc} через {v} — без двойных срабатываний")
        out += [
            f"«{p['title']}»: поворот выбранной фигуры (если rotation вкл.) меняет ориентацию",
            f"«{p['title']}»: отражение (если flip вкл.) даёт зеркальную фигуру",
            f"«{p['title']}»: призрак показывает валидность до отпускания",
            f"«{p['title']}»: постановка на занятые/за край — отклонена без изменения доски",
        ]
    if p["family"] == "match3":
        for v in INPUT_VERBS[:2]:
            out.append(f"«{p['title']}»: своп соседей через {v} — анимация и разрешение")
        out.append(f"«{p['title']}»: своп несоседних клеток — запрещён")
        out.append(f"«{p['title']}»: своп без серии — откат к исходному")
    if p["family"] == "tetris":
        out += [
            f"«{p['title']}»: soft-drop ускоряет падение",
            f"«{p['title']}»: hard-drop мгновенно фиксирует фигуру",
            f"«{p['title']}»: поворот у стены (wall-kick, если есть) корректен",
            f"«{p['title']}»: удержание влево/право двигает фигуру с автоповтором",
        ]
    return out


def gen_settings(p):
    out = []
    for t in SETTINGS_TOGGLES:
        out.append(f"«{p['title']}»: настройка «{t}» применяется в режиме и переживает перезапуск")
    return out


def gen_progression(p):
    out = [
        f"«{p['title']}»: завершение партии пишет результат в статистику режима",
        f"«{p['title']}»: вклад в composite-score (сводный рейтинг) учитывается",
    ]
    if p.get("online"):
        out += [
            "Онлайн: победа/поражение/ничья двигают ELO (K=24)",
            "Онлайн: W/L/D и накопительная статистика пишутся в профиль",
            "Онлайн: PvP-ачивки разблокируются по порогам",
        ]
    else:
        out += [
            f"«{p['title']}»: XP по исходу начисляется один раз (ничья ×0.5, поражение 0)",
            f"«{p['title']}»: личный рекорд обновляется только при улучшении",
        ]
    return out


def gen_errors(p):
    return [
        f"«{p['title']}»: повреждённая сохранёнка → graceful fallback, без краша",
        f"«{p['title']}»: сворачивание в момент хода → без рассинхрона состояния",
        f"«{p['title']}»: быстрый повторный ввод не даёт двойного хода",
        f"«{p['title']}»: возврат/пауза в критический момент не ломает партию",
    ]


# — Специфичные билдеры по family —

def spec_duel9(p):
    out = []
    for pc in PIECES:
        for o in ORIENTS:
            for pl in PLACEMENTS:
                out.append(f"Фигура {pc} ({o}): постановка {pl} — призрак и валидация корректны")
    # Покрытие по якорям: каждая фигура в каждую клетку-якорь 9×9.
    for pc in PIECES:
        for r in range(9):
            for c in range(9):
                out.append(f"Фигура {pc}: якорь ({r},{c}) — валидна если помещается, иначе отклонена")
    for r in range(9):
        out.append(f"Полная строка {r}: очистка и начисление очков ходившему")
    for c in range(9):
        out.append(f"Полный столбец {c}: очистка и начисление очков ходившему")
    for br in range(3):
        for bc in range(3):
            out.append(f"Бокс 3×3 [{br},{bc}]: очистка и начисление")
    for ct in CLEAR_TYPES:
        for lvl in range(1, 11):
            out.append(f"Очистка «{ct}» при комбо={lvl}: множитель и очки по формуле")
    out += [
        "Perfect clear: +15 и конфетти/звук",
        "base=N·(N+1)/2; placement-бонус I=+5/L,J=+3/T,S,Z=+1/O=0",
        "Тупик: партия завершается, победитель по очкам, ничья при равенстве",
        "7-bag: свой мешок у игрока, каждая фигура по разу за цикл",
    ]
    if p.get("timer"):
        for preset in BLITZ_PRESETS:
            out.append(f"Блиц «{preset}»: старт-время/decay применяются")
            out.append(f"Блиц «{preset}»: таймаут → force-place; при отсутствии ходов — конец партии")
    if p.get("bot"):
        for lvl in BOT_LEVELS:
            out.append(f"Бот «{lvl}»: делает валидный ход в разумное время")
            out.append(f"Бот «{lvl}»: не ставит фигуру за край/на занятое")
        out.append("Задержка бота уважает настройку скорости")
    if p.get("two_human"):
        out.append("Hot-seat: ход переходит второму игроку; счёт раздельный")
        out.append("Hot-seat: экран передачи устройства между ходами (если есть)")
    if p.get("solo"):
        out.append("Аркада: один игрок на доске, цель — максимум очков до тупика")
        out.append("Аркада: рекорд сохраняется и показывается на экране результата")
    if p.get("spectator"):
        out.append("Зритель: оба игрока — боты, ходы автопроигрываются")
        out.append("Зритель: можно выйти в любой момент без последствий")
    if p.get("online"):
        out += [f"Онлайн: {f}" for f in ONLINE_FLOWS]
        for msg in WIRE_MESSAGES:
            out.append(f"Онлайн: сообщение «{msg}» разбирается и редьюсится корректно")
        for cond in NET_CONDITIONS:
            out.append(f"Онлайн при «{cond}»: матч консистентен")
    return out


def spec_memory(p):
    out = []
    for n in range(1, 25):
        out.append(f"Показ {n} фигур: раскладка видна заданное время, затем скрывается")
        out.append(f"Воспроизведение {n} фигур: точная копия засчитывается как успех")
        out.append(f"Ошибка на {n}-й фигуре: несовпадение фиксируется, счёт падает")
    for r in range(9):
        for c in range(9):
            out.append(f"Клетка ({r},{c}) — фаза показа: подсвечена если входит в раскладку")
            out.append(f"Клетка ({r},{c}) — скрытие: очищается, соперник не видит расстановку")
            out.append(f"Клетка ({r},{c}) — воспроизведение: верная/ошибочная постановка учтена")
    for seed in range(1, 61):
        out.append(f"Раскладка seed={seed}: фигуры в валидных позициях, воспроизводима на память")
    for dur in ("0.5с", "1с", "2с", "3с", "5с"):
        out.append(f"Длительность показа {dur}: раскладка видна ровно столько, затем скрыта")
    out += [
        "Тайм-бюджет показа ограничен и убывает с уровнем сложности",
        "Соло: рекорд по числу воспроизведённых уровней сохраняется",
        "Досрочный показ (peek) недоступен после старта воспроизведения",
    ]
    if p.get("two_human"):
        out += [
            "Дуэль: игрок A расставляет → показ → игрок B воспроизводит по памяти",
            "Дуэль: очки за точность, ход переходит сопернику",
            "Дуэль: ограничение времени показа общее для обоих",
        ]
    return out


def spec_coop(p):
    out = []
    for pc in PIECES:
        for o in ORIENTS:
            for col in range(10):
                out.append(f"Фигура {pc} ({o}): постановка в столбец {col} поля 10×20 — валидация")
    for col in range(10):
        for h in range(0, 20, 2):
            out.append(f"Столбец {col}: фигура ложится на высоту ~{h} без наложения")
    for r in range(20):
        out.append(f"Полная строка {r} (10×20): очистка, общий счёт растёт")
    for k in range(1, 5):
        out.append(f"Очистка {k} строк за ход: линейная база × бонус +25%/доп.строка")
    out += [
        "Ходы по очереди, счёт общий (кооператив)",
        "Тупик по высоте: партия завершается",
        "Очистка без «падения» верхних строк (по правилам coop)",
        "resume 10×20 восстанавливает доску и общий счёт",
    ]
    return out


def spec_match3(p):
    out = []
    for r in range(8):
        for c in range(8):
            for dr, dc, dname in ((0, 1, "вправо"), (1, 0, "вниз"),
                                  (0, -1, "влево"), (-1, 0, "вверх")):
                nr, nc = r + dr, c + dc
                if 0 <= nr < 8 and 0 <= nc < 8:
                    out.append(f"Своп ({r},{c})↔({nr},{nc}) [{dname}]: разрешён только если даёт серию, иначе откат")
    for r in range(8):
        for c in range(8):
            out.append(f"Клетка ({r},{c}): если входит в серию — очищается и даёт очки ходившему")
    for r in range(8):
        for color in range(6):
            out.append(f"Строка {r}, цвет {color}: горизонтальная серия обнаруживается и очищается")
    for color in range(6):
        for length in (3, 4, 5):
            out.append(f"Серия длины {length} цвета {color}: обнаружение и очистка")
    for c in range(8):
        out.append(f"Столбец {c}: гравитация роняет клетки вниз, досыпка сверху детерминирована по seed")
    for depth in range(1, 9):
        out.append(f"Каскад глубины {depth}: множитель 1+0.5·(k-1), очки растут")
    out += [
        "resolveBoard завершается даже при длинной цепочке (потолок 128)",
        "Своп без серии откатывается, ход не тратится",
        "Достигнут лимит ходов → партия завершается, победитель по очкам",
        "Нет доступных ходов → пересборка поля (reshuffle)",
        "Досыпка новых цветов сверху детерминирована по seed",
    ]
    return out


def spec_tetris(p):
    out = []
    for pc in PIECES:
        for o in ORIENTS:
            for col in range(10):
                out.append(f"Фигура {pc} ({o}): фиксация в столбце {col} на поле 10×20")
    for pc in PIECES:
        for drop in ("soft-drop", "hard-drop"):
            out.append(f"Фигура {pc}: {drop} фиксирует на нижней достижимой высоте")
    for r in range(20):
        out.append(f"Полная строка {r}: очистка, начисление, сдвиг верхних вниз")
    for lvl in range(1, 16):
        out.append(f"Уровень {lvl}: скорость падения выше, порог линий соблюдён")
    for col in range(10):
        out.append(f"Столбец {col}: стакан у верха в этом столбце ведёт к top-out")
    out += [
        "Top-out (стакан достиг верха) → game over",
        "Одновременная очистка 4 строк (tetris) даёт максимум очков",
        "Превью следующей фигуры соответствует выданной",
        "Пауза останавливает падение; снятие возобновляет",
    ]
    return out


def spec_puzzle(p):
    out = []
    cats = ["животные", "предметы", "символы"]
    diffs = ["easy", "medium", "hard", "expert"]
    for cat in cats:
        for d in diffs:
            for k in range(1, 13):
                out.append(f"Уровень [{cat}/{d}] #{k}: рука из решения, постановка только внутри маски")
                out.append(f"Уровень [{cat}/{d}] #{k}: реплей эталонного решения решает головоломку")
    for seed in range(1, 61):
        out.append(f"Генератор seed={seed}: замощение маски существует (разрешимость гарантирована)")
    for d in diffs:
        out.append(f"Сложность {d}: бюджет ходов и базовые очки соответствуют")
        out.append(f"Сложность {d}: награда монетами по таблице")
    for pc in PIECES:
        out.append(f"Фигура {pc}: постановка внутри маски засчитывается, вне — отклонена")
    out += [
        "Контур собран → «решено», начисление очков по movesUsed",
        "hint подсвечивает валидный ход внутри маски",
        "Битый внешний пак (клетка вне сетки) отвергается FormatException, без краша",
        "Неразрешимая рука невозможна: генератор гарантирует замощение",
        "Рекорды по уровням сохраняются (SharedPreferences)",
        "JSON round-trip уровня симметричен",
    ]
    return out


def spec_showcase(p):
    out = [
        "Формат 9:16 (вертикаль) выдержан для Shorts",
        "ИИ vs ИИ: оба хода автопроигрываются без участия игрока",
        "Кнопка «В эфир»/запись клипа доступна",
        "Веб-запись клипа стартует и останавливается",
        "Прямой live требует серверный RTMP-релей (заглушка/недоступно локально)",
        "Выход из шоу в любой момент без последствий",
    ]
    # Наблюдаемая 9×9-механика (шоу показывает полноценную партию).
    for pc in PIECES:
        for o in ORIENTS:
            for pl in PLACEMENTS:
                out.append(f"Наблюдение: фигура {pc} ({o}) ставится ботом {pl} — эффект отображён")
    for ct in CLEAR_TYPES:
        for lvl in range(1, 11):
            out.append(f"Наблюдение: очистка «{ct}» при комбо={lvl} отображается с эффектом/счётом")
    for r in range(9):
        out.append(f"Наблюдение: очистка строки {r} анимируется (конфетти/floating-score)")
    return out


def spec_tutorial(p):
    steps = ["постановка фигуры", "поворот/отражение", "очистка линии",
             "комбо и множитель", "завершение и награда"]
    facets = [
        "инструкция понятна, действие принимается",
        "подсветка цели корректна",
        "нельзя пропустить обязательное действие",
        "кнопка «Далее» активна только после выполнения",
        "кнопка «Назад» возвращает к предыдущему шагу без потери прогресса",
        "прогресс-индикатор шага отражает текущую позицию",
        "неверное действие не ломает шаг, подсказка повторяется",
    ]
    out = []
    for i, s in enumerate(steps, 1):
        for f in facets:
            out.append(f"Шаг {i} «{s}»: {f}")
        for v in INPUT_VERBS:
            out.append(f"Шаг {i} «{s}» через {v}: ввод распознаётся, действие засчитано")
        for t in THEMES:
            out.append(f"Шаг {i} «{s}» в теме «{t}»: контраст подсказок достаточен")
    out += [
        "Завершение обучения: награда +50 🪙 начисляется один раз",
        "Повторное прохождение не начисляет награду повторно",
        "Выход посреди обучения не выдаёт награду",
        "Обучение доступно из меню и из первого запуска",
    ]
    return out


SPECIFIC = {
    "duel9": spec_duel9,
    "memory": spec_memory,
    "coop": spec_coop,
    "match3": spec_match3,
    "tetris": spec_tetris,
    "puzzle": spec_puzzle,
    "showcase": spec_showcase,
    "tutorial": spec_tutorial,
}


def fuzz_matrix(p):
    """Осмысленный хвост-добор: property-фаззинг (seed × конфиг × инвариант).

    Все режимы детерминированы (makeRng/seed), поэтому прогон на фиксированной
    паре (seed, конфиг) воспроизводим, а проверка инварианта — валидный
    property-тест, а не пустой филлер. Матрица (config-вариация × инвариант ×
    seed) даёт много РАЗЛИЧНЫХ осмысленных фаз-кейсов. Возвращает fn(k)->[k строк].
    """
    base_inv = [
        "счёт неотрицателен на всём протяжении",
        "ни одного исключения/краша за партию",
        "resume в середине — бит-в-бит то же продолжение",
        "число ходов конечно (партия сходится)",
        "детерминизм: повтор на той же паре (seed,cfg) даёт тот же исход",
        "ни одной невалидной постановки не принято",
        "инвариант доски: заполненные клетки не «протекают» за границы",
    ]
    fam = p["family"]
    if fam == "duel9":
        cfgs = ["blitz=normal", "blitz=fast", "blitz=hardcore", "blitz=off",
                "rotation=off", "flip=off", "handSize=1", "handSize=5"]
        if p.get("bot"):
            cfgs += ["bot=easy", "bot=medium", "bot=hard"]
        base_inv += ["очистка начисляется ходившему игроку",
                     "тупик корректно завершает партию"]
    elif fam == "memory":
        cfgs = ["show=short", "show=long", "уровень=1", "уровень=5", "уровень=10",
                "сложность растёт", "рука=малая", "рука=большая"]
        base_inv += ["точность воспроизведения оценена верно"]
    elif fam == "match3":
        cfgs = ["6 цветов", "лимит ходов низкий", "лимит ходов высокий",
                "плотное поле", "разреженное поле", "seed без стартовых серий"]
        base_inv += ["каскады затухают (resolveBoard завершается)",
                     "своп без серии откатывается"]
    elif fam in ("coop", "tetris"):
        cfgs = ["скорость=низкая", "скорость=высокая", "поле почти полное",
                "поле пустое", "серия очисток", "одиночная очистка"]
        base_inv += ["очистка строки сдвигает/освобождает корректно"]
    elif fam == "puzzle":
        cfgs = ["easy", "medium", "hard", "expert", "категория=животные",
                "категория=предметы", "категория=символы"]
        base_inv += ["решение генератора всегда замощает маску",
                     "постановка вне маски отклонена"]
    else:  # showcase, tutorial
        cfgs = ["тема=neutral", "тема=candy", "тема=night", "reduceMotion=on",
                "узкое окно", "широкое окно"]

    def fn(k):
        res = []
        s = 1
        # Внешний цикл — seed; внутренние — конфиг × инвариант (различимость строк).
        while len(res) < k:
            for cfg in cfgs:
                for inv in base_inv:
                    res.append(f"Фаззинг seed={s} · {cfg} [{p['id']}]: {inv}")
                    if len(res) >= k:
                        return res
            s += 1
        return res[:k]

    return fn


def build_mode_catalog(p):
    sections = [
        ("Запуск и жизненный цикл", gen_lifecycle(p)),
        ("Рендер и темы", gen_render(p)),
        ("Ввод", gen_input(p)),
        ("Механика режима", SPECIFIC[p["family"]](p)),
        ("Прогрессия и рекорды", gen_progression(p)),
        ("Настройки в режиме", gen_settings(p)),
        ("Ошибки и устойчивость", gen_errors(p)),
    ]
    # Пустые разделы (например Ввод у showcase) отсеиваем.
    sections = [(n, items) for n, items in sections if items]
    filler = ("Property-фаззинг (seed×конфиг)", fuzz_matrix(p))
    return exactly_n(sections, TARGET, filler=filler)


def render_mode(p, picked):
    prefix = "MODE-" + p["id"].upper()
    intro = [
        f"**Ровно {TARGET} сценариев** режима «{p['title']}» («1000 и 1»).",
        f"Доска: {p['board']}. Маршрут: `{p['route']}`. Сгенерировано детерминированно",
        "из `tools/gen_scenarios.py` (ось «режим») — НЕ редактировать вручную.",
        "",
        f"- **ID** `{prefix}-0001…{prefix}-1001` стабильны между прогонами.",
        "- **[C]** — критический smoke-срез (каждый ~7-й).",
        "- «Механика режима» — уникальная логика; хвост «Property-фаззинг» —",
        "  осмысленная матрица (seed × конфиг × инвариант) для добора до 1001 в",
        "  режимах малой игровой поверхности (это valid property-тесты, не филлер).",
    ]
    title = f"BlockDuel — Каталог сценариев режима «{p['title']}»"
    return render_catalog(title, intro, prefix, picked)


def write_app_catalog():
    picked = build_app_catalog()
    intro = [
        f"**Ровно {TARGET} сценариев** («1000 и 1»). Сгенерировано детерминированно",
        "из `tools/gen_scenarios.py` — НЕ редактировать вручную, править генератор.",
        "",
        "- **ID** `APP-0001…APP-1001` стабильны между прогонами (round-robin по областям).",
        "- **[C]** — критический smoke-срез (каждый ~7-й) для быстрой регрессии.",
        "- Часть пунктов продублирована исполняемыми автотестами в",
        "  `test/scenarios/app_scenarios_test.dart` (ссылки на APP-ID в названиях).",
    ]
    out = render_catalog(
        "BlockDuel 9×9 — Сквозной каталог сценариев приложения", intro, "APP", picked)
    dst = os.path.join(ROOT, "qa", "SCENARIOS_APP.md")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(out)
    n = out.count("**APP-")
    print(f"  qa/SCENARIOS_APP.md — {n} сценариев")
    assert n == TARGET, f"APP: ожидалось {TARGET}, получено {n}"


def write_mode_catalogs():
    for p in MODE_PROFILES:
        picked = build_mode_catalog(p)
        out = render_mode(p, picked)
        dst = os.path.join(ROOT, "qa", f"SCENARIOS_MODE_{p['id']}.md")
        with open(dst, "w", encoding="utf-8") as f:
            f.write(out)
        n = out.count(f"**MODE-{p['id'].upper()}-")
        print(f"  qa/SCENARIOS_MODE_{p['id']}.md — {n} сценариев")
        assert n == TARGET, f"MODE {p['id']}: ожидалось {TARGET}, получено {n}"


# ── Ось «код + платформа»: 1001 сценарий на каждую платформу ──────────────────
#
# Проверяет платформенный срез: рендер/ввод/жизненный цикл/хранение/auth/сеть/
# сборка/разрешения ПЛЮС «код мода» — инварианты чистого ядра, одинаковые на всех
# платформах (детерминизм, отсутствие Random/DateTime в pure-слое, паритет с TS).

PLATFORM_PROFILES = [
    dict(id="web", title="Web (Flutter Web, прод)",
         input=["мышь", "тачскрин", "клавиатура", "трекпад"],
         store="SharedPreferences→localStorage", deploy="gh-pages (GitHub Actions)",
         auth="Google sign-in (popup/redirect)"),
    dict(id="macos", title="macOS (desktop)",
         input=["мышь", "трекпад", "клавиатура"],
         store="SharedPreferences→NSUserDefaults", deploy="release .app/.dmg",
         auth="Google sign-in (ждёт значений Firebase, MACOS_AUTH_SETUP.md)"),
    dict(id="android", title="Android",
         input=["тачскрин", "жесты", "аппаратная Back"],
         store="SharedPreferences→XML", deploy="APK/AAB (Play)",
         auth="Google sign-in (native)"),
    dict(id="ios", title="iOS/iPadOS",
         input=["тачскрин", "жесты", "внешняя клавиатура (iPad)"],
         store="SharedPreferences→NSUserDefaults", deploy="App Store (TestFlight)",
         auth="Google sign-in (native/ASWebAuth)"),
]

DEVICE_SURFACES = [
    "Меню", "Setup", "Игра 9×9", "Профиль", "Статистика", "Настройки",
    "Магазин", "Достижения", "Онлайн-меню", "Онлайн-матч", "Лидерборд",
    "Силуэты", "Co-op", "Match-3", "Память", "Экран результата",
]


def gen_plat_render(pl):
    out = []
    for s in DEVICE_SURFACES:
        for t in THEMES:
            out.append(f"[{pl['id']}] «{s}» в теме «{t}»: рендер без артефактов, шрифты/иконки чёткие")
        out.append(f"[{pl['id']}] «{s}»: масштаб под DPR/плотность экрана без размытия")
        out.append(f"[{pl['id']}] «{s}»: безопасные зоны/вырезы не перекрывают контент")
        out.append(f"[{pl['id']}] «{s}»: адаптивная раскладка при смене размера/ориентации")
    return out


def _plat_devices(pl):
    """Представительный набор сред/устройств для платформенной матрицы."""
    if pl["id"] == "web":
        return [f"{b}/{ff}" for b in ("Chrome", "Safari", "Firefox", "Edge")
                for ff in ("desktop", "laptop", "tablet", "mobile")]
    if pl["id"] == "macos":
        return ["окно макс.", "окно 50%", "узкое окно", "Retina 2×",
                "внешний монитор", "разделённый экран", "полноэкранный"]
    if pl["id"] == "android":
        return ["малый телефон", "крупный телефон", "планшет 10\"",
                "складной", "бюджетный (low-RAM)", "high-refresh 120Гц"]
    # ios / ipados
    return ["iPhone SE", "iPhone mini", "iPhone Pro", "iPhone Pro Max",
            "iPad", "iPad Pro", "iPad Split View"]


def gen_plat_device_matrix(pl):
    """Стандартная платформенная матрица: устройство × ориентация × ключевой экран."""
    out = []
    devices = _plat_devices(pl)
    orients = ["портрет", "ландшафт"] if pl["id"] in ("android", "ios") else ["по умолч."]
    for d in devices:
        for o in orients:
            for s in DEVICE_SURFACES:
                tag = f"{d}/{o}" if o != "по умолч." else d
                out.append(f"[{pl['id']}] {tag}: «{s}» — без overflow, читаемо, тапабельные зоны ≥44pt")
    return out


def gen_plat_input(pl):
    out = []
    for v in pl["input"]:
        for pc in PIECES:
            out.append(f"[{pl['id']}] Ввод «{v}»: выбор/постановка фигуры {pc} без двойных срабатываний")
        out.append(f"[{pl['id']}] Ввод «{v}»: поворот/отражение фигуры реагирует корректно")
        out.append(f"[{pl['id']}] Ввод «{v}»: drag-призрак следует за указателем, отпускание ставит")
        out.append(f"[{pl['id']}] Ввод «{v}»: отмена жеста возвращает фигуру в руку")
    return out


def gen_plat_lifecycle(pl):
    base = [
        f"[{pl['id']}] Холодный старт: без белой вспышки, состояние по умолчанию/восстановлено",
        f"[{pl['id']}] Возврат из фона во время матча: таймер/бот не рассинхронятся",
        f"[{pl['id']}] Прерывание (звонок/уведомление/сон): партия ставится на паузу корректно",
        f"[{pl['id']}] Поворот экрана во время матча: доска не теряет состояние",
        f"[{pl['id']}] Нехватка памяти/выгрузка: resume восстанавливает партию",
    ]
    if pl["id"] == "web":
        base += [
            "[web] Смена вкладки (visibilitychange): анимации/звук приостановлены",
            "[web] Обновление страницы (F5) во время матча: resume предлагает продолжить",
            "[web] Кнопка Back браузера: навигация по стеку роутера корректна",
            "[web] Deep-link на маршрут по URL: открывает нужный экран",
        ]
    else:
        base += [
            f"[{pl['id']}] Системная кнопка/жест «назад»: предупреждение о выходе из матча",
            f"[{pl['id']}] Уведомление в шторке: тап открывает нужный экран",
        ]
    return base


def gen_plat_storage_auth(pl):
    out = [
        f"[{pl['id']}] Хранение ({pl['store']}): профиль/настройки/статистика персистятся",
        f"[{pl['id']}] Хранение: сохранёнка матча resume-абельна после перезапуска",
        f"[{pl['id']}] Хранение: повреждённые данные → graceful fallback к дефолтам",
        f"[{pl['id']}] Хранение: очистка данных приложения → чистый первый запуск",
        f"[{pl['id']}] Auth ({pl['auth']}): вход выполняется, аватар/ник подтягиваются",
        f"[{pl['id']}] Auth: выход не стирает локальный прогресс",
        f"[{pl['id']}] Auth: отмена входа пользователем обрабатывается без краша",
        f"[{pl['id']}] Sync: Firestore-слияние (max-wins, union ачивок) при кросс-девайсе",
        f"[{pl['id']}] Sync: оффлайн-правки мёрджатся при следующем входе",
    ]
    return out


def gen_plat_network(pl):
    out = []
    for f in ONLINE_FLOWS:
        out.append(f"[{pl['id']}] Онлайн: {f}")
    for cond in NET_CONDITIONS:
        out.append(f"[{pl['id']}] Онлайн при «{cond}»: reconnect/консистентность матча")
    out.append(f"[{pl['id']}] WSS к pvp.alshfu.com: TLS-соединение устанавливается")
    out.append(f"[{pl['id']}] Потеря сети посреди хода: клиент не теряет состояние, чинит по reconnect")
    return out


def gen_plat_build_perms(pl):
    out = [
        f"[{pl['id']}] Release-сборка ({pl['deploy']}) проходит без ошибок",
        f"[{pl['id']}] Иконки/сплэш/название приложения корректны",
        f"[{pl['id']}] Версия 2.0.0+1 отображается в About",
        f"[{pl['id']}] Разрешение на уведомления: запрос и отказ обрабатываются",
        f"[{pl['id']}] Сетевые разрешения/ATS/CORS настроены для WSS и Firebase",
    ]
    if pl["id"] == "web":
        out += [
            "[web] CanvasKit/движок рендера грузится; нет запросов на заблокированные хосты",
            "[web] Пути ассетов относительны base-href gh-pages",
            "[web] Автодеплой GitHub Actions (analyze+test+build) зелёный на push в main",
        ]
    if pl["id"] == "macos":
        out += [
            "[macos] Sandbox/entitlements: сеть-клиент разрешён",
            "[macos] Firebase auth ждёт 4 значения из Console (MACOS_AUTH_SETUP.md)",
        ]
    if pl["id"] in ("android", "ios"):
        out += [
            f"[{pl['id']}] Требования сторов к приватности/иконкам соблюдены",
            f"[{pl['id']}] IAP/платежи — серверная валидация (заглушка локально)",
        ]
    return out


def gen_plat_code_invariants(pl):
    """«Код мода» — инварианты чистого ядра, одинаковые на всех платформах."""
    out = [
        f"[{pl['id']}] Ядро lib/core детерминировано: (seed,cfg,log)→то же состояние",
        f"[{pl['id']}] В pure-слое нет Random()/DateTime.now()/IO/Flutter-импортов",
        f"[{pl['id']}] Golden-паритет с TS-ядром бит-в-бит держится",
        f"[{pl['id']}] 7-bag resume детерминистичен (queue+counter+rngState)",
        f"[{pl['id']}] Формула очков идентична ТЗ на этой платформе",
        f"[{pl['id']}] MVVM: виджеты без логики, состояние в нотифайерах",
        f"[{pl['id']}] Нет утечек таймеров/подписок при входе/выходе экранов",
    ]
    for m in ["9×9", "Memory", "Co-op", "Match-3", "Силуэты"]:
        out.append(f"[{pl['id']}] Режим «{m}»: pure-логика даёт тот же результат, что на других платформах")
    return out


def plat_fuzz(pl):
    inv = [
        "рендер без исключений на всех экранах",
        "ввод не даёт двойных ходов",
        "resume бит-в-бит восстанавливает партию",
        "нет обращений к заблокированным ресурсам",
        "детерминизм ядра сохраняется",
        "нет утечек памяти за сессию",
        "локализация RU не обрезается в лэйауте",
    ]
    cfgs = ["тема=neutral", "тема=candy", "тема=night", "reduceMotion=on",
            "мелкий экран", "крупный экран", "медленная сеть", "оффлайн",
            "низкая память", "высокий DPR"]

    def fn(k):
        res = []
        s = 1
        while len(res) < k:
            for cfg in cfgs:
                for i in inv:
                    res.append(f"Фаззинг [{pl['id']}] прогон={s} · {cfg}: {i}")
                    if len(res) >= k:
                        return res
            s += 1
        return res[:k]

    return fn


def build_platform_catalog(pl):
    sections = [
        ("Рендер и темы", gen_plat_render(pl)),
        ("Матрица устройств", gen_plat_device_matrix(pl)),
        ("Ввод", gen_plat_input(pl)),
        ("Жизненный цикл", gen_plat_lifecycle(pl)),
        ("Хранение и auth/sync", gen_plat_storage_auth(pl)),
        ("Сеть и онлайн", gen_plat_network(pl)),
        ("Сборка и разрешения", gen_plat_build_perms(pl)),
        ("Код мода (инварианты ядра)", gen_plat_code_invariants(pl)),
    ]
    sections = [(n, items) for n, items in sections if items]
    filler = ("Property-фаззинг (платформа)", plat_fuzz(pl))
    return exactly_n(sections, TARGET, filler=filler)


def render_platform(pl, picked):
    prefix = "CODE-" + pl["id"].upper()
    intro = [
        f"**Ровно {TARGET} сценариев** платформы «{pl['title']}» («1000 и 1»).",
        f"Ввод: {', '.join(pl['input'])}. Хранение: {pl['store']}. Деплой: {pl['deploy']}.",
        "Сгенерировано детерминированно из `tools/gen_scenarios.py` (ось «код+платформа»).",
        "",
        f"- **ID** `{prefix}-0001…{prefix}-1001` стабильны между прогонами.",
        "- **[C]** — критический smoke-срез (каждый ~7-й).",
        "- Раздел «Код мода» — инварианты чистого ядра, одинаковые на всех платформах;",
        "  хвост «Property-фаззинг» (прогон × конфиг × инвариант) добирает до 1001.",
    ]
    title = f"BlockDuel — Каталог сценариев платформы «{pl['title']}»"
    return render_catalog(title, intro, prefix, picked)


def write_platform_catalogs():
    for pl in PLATFORM_PROFILES:
        picked = build_platform_catalog(pl)
        out = render_platform(pl, picked)
        dst = os.path.join(ROOT, "qa", f"SCENARIOS_CODE_{pl['id']}.md")
        with open(dst, "w", encoding="utf-8") as f:
            f.write(out)
        n = out.count(f"**CODE-{pl['id'].upper()}-")
        print(f"  qa/SCENARIOS_CODE_{pl['id']}.md — {n} сценариев")
        assert n == TARGET, f"CODE {pl['id']}: ожидалось {TARGET}, получено {n}"


def main():
    write_app_catalog()
    write_mode_catalogs()
    write_platform_catalogs()
    print(f"  Итого: 1 (app) + {len(MODE_PROFILES)} (mode) + "
          f"{len(PLATFORM_PROFILES)} (platform) каталогов по {TARGET}")


if __name__ == "__main__":
    main()
