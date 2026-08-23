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


def exactly_n(sections, n):
    """Round-robin по областям, обрезка до ровно n (сбалансированное покрытие).

    sections: список (area_name, [строки]). Возвращает список (area_name, строка)
    длиной n. Если суммарно < n — ошибка (нужно добавить сценариев).
    """
    total = sum(len(items) for _, items in sections)
    if total < n:
        raise SystemExit(f"Сгенерировано {total} < {n}: добавьте сценариев в области")
    queues = [(name, list(items)) for name, items in sections]
    picked = []
    idx = 0
    while len(picked) < n:
        name, q = queues[idx % len(queues)]
        if q:
            picked.append((name, q.pop(0)))
        idx += 1
        # Если все очереди опустели раньше n — невозможно (total >= n гарантирует).
    return picked


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


def render(picked):
    lines = []
    lines.append("# BlockDuel 9×9 — Сквозной каталог сценариев приложения")
    lines.append("")
    lines.append(f"**Ровно {TARGET} сценариев** («1000 и 1»). Сгенерировано детерминированно")
    lines.append("из `tools/gen_scenarios.py` — НЕ редактировать вручную, править генератор.")
    lines.append("")
    lines.append("- **ID** `APP-0001…APP-1001` стабильны между прогонами (round-robin по областям).")
    lines.append("- **[C]** — критический smoke-срез (каждый ~7-й) для быстрой регрессии.")
    lines.append("- Часть пунктов продублирована исполняемыми автотестами в")
    lines.append("  `test/scenarios/app_scenarios_test.dart` (ссылки на APP-ID в названиях).")
    lines.append("")
    tagged = crit([f"[{name}] {text}" for name, text in picked])
    # Оглавление по областям (счётчики).
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
        lines.append(f"{i}. **APP-{i:04d}** — {text}")
    lines.append("")
    return "\n".join(lines)


def main():
    picked = build_app_catalog()
    out = render(picked)
    dst = os.path.join(ROOT, "qa", "SCENARIOS_APP.md")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(out)
    n = out.count("**APP-")
    print(f"  qa/SCENARIOS_APP.md — {n} сценариев записано")
    assert n == TARGET, f"ожидалось {TARGET}, получено {n}"


if __name__ == "__main__":
    main()
