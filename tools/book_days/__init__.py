"""book_days — сюжет страниц-дней книги «Марьям в Мире Кода», недели 7–29.

Каждый модуль weekNN.py описывает одну неделю курса словарём WEEK:
    num        — номер недели
    folder     — папка заготовок course/weekNN_*
    companion  — зверёнок-спутник недели (для подписи под обложкой)
    badge      — id SVG-символа героя из спрайта книги (pony/llama/alpaca/catP/catR/maryam)
    title      — тема недели (как в карте курса)
    lead       — подводка недели (1–3 предложения)
    days       — список дней: dict(day, theme, h3, seen, story, steps)
        theme  — короткая тема дня (плашка/кикер)
        h3     — заголовок страницы-дня
        seen   — что на картинке (уходит в alt изображения, если картинка есть)
        story  — ТРИ абзаца прозы, каждый ≥3 предложений (правило книги):
                 сцена с героями → зверёнок объясняет идею → связь с настоящей игрой
        steps  — шаги задания дня (2–3 пункта)

Диапазоны дней совпадают с tools/gen_course.py и tools/gen_image_prompts.py —
это источники правды по темам недель; иллюстрации будут рисоваться по промптам
из book/image-promt/, поэтому темы дней здесь согласованы с ними.

Загрузчик — load_weeks() — собирает все модули по возрастанию номера.
"""

import importlib
import pkgutil


def load_weeks():
    """Возвращает список словарей WEEK всех модулей weekNN по возрастанию."""
    weeks = []
    for info in pkgutil.iter_modules(__path__):
        if info.name.startswith("week"):
            mod = importlib.import_module(f"{__name__}.{info.name}")
            weeks.append(mod.WEEK)
    return sorted(weeks, key=lambda w: w["num"])


# Помощники разметки для текстов сюжета.
def M(s):
    """Моноширинный фрагмент кода."""
    return f'<span class="mono">{s}</span>'


def W(s):
    """Выделенный термин."""
    return f'<span class="word">{s}</span>'
