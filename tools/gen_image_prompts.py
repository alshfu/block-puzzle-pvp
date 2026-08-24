#!/usr/bin/env python3
"""gen_image_prompts.py — генератор описаний иллюстраций (image-promt/).

Назначение
    Для книги «Марьям в Мире Кода» раскладывает по файлам ГОТОВЫЕ промпты
    иллюстраций — на каждый из 200 дней курса плюс мастер-промпты обложки и
    героев. По этим описаниям владелец генерирует картинки в любой нейросети.

    Каждый день привязан к своей неделе (тема + герой-спутник + сцена дня), стиль
    у всех единый — чтобы картинки были «одной семьёй». Промпты — на английском
    (нейросети его понимают лучше), с русской подписью, что иллюстрируем.

Запуск
    python3 tools/gen_image_prompts.py
    (перезаписывает image-promt/; печатает число файлов)
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

STYLE = ("flat vector children's book illustration, soft rounded shapes, thick "
         "soft outlines, cozy friendly mood, dark navy background #0E1116, "
         "glowing tetromino blocks in orange #E0913E, cyan #2FB6D2, purple "
         "#9B5DE0 and green #43AE68, warm magical Code World, cute, simple, "
         "centered square composition")

CHARS = {
    "maryam": "Maryam, a cute 8-year-old girl with two dark braided buns, big warm curious eyes, soft purple dress",
    "pony": "By the pony, a small friendly pony with warm orange body and red-pink mane, big gentle eyes",
    "llama": "Lu the llama, a tall calm cyan llama with a long graceful neck and wise kind eyes",
    "alpaca": "Alya the alpaca, a fluffy round mint-green alpaca with big fluffy cheeks, cheerful",
    "cats": "two tiny cats, one soft purple and one warm red, with big round eyes, playful",
}

# (нед, дни_от, дни_до, тема_ru, [ключи героев], [визуальные сцены дня, англ.])
WEEKS = [
    (1, 1, 7, "Подготовка / Портал", ["maryam"],
     ["standing before a glowing violet portal made of code blocks, curious",
      "reaching a hand toward the shining portal block",
      "stepping one foot into the portal, sparkles around",
      "surrounded by floating letters and code symbols, amazed",
      "landing softly on a floor of glowing grid cells",
      "looking around the magical Code World with wide eyes",
      "meeting all the animal friends for the first time, group scene"]),
    (2, 8, 14, "Переменные (Пони По)", ["pony", "maryam"],
     ["showing labeled boxes named 'score' and 'nick'",
      "putting the number 0 into a box labeled score",
      "putting the word 'Maryam' into a box labeled nick",
      "adding 15 more blocks into the score box, it glows",
      "two neat boxes side by side, one with a number one with letters",
      "happy with a glowing 'player card' showing name and score"]),
    (3, 15, 21, "Функции (Лама Лу)", ["llama", "maryam"],
     ["weaving a glowing machine that takes input and returns output",
      "a friendly function-machine with an in-arrow and out-arrow",
      "feeding numbers into the machine, a result pops out",
      "reading a glowing scroll of the scoring formula",
      "calling the same machine many times, results flowing",
      "a magical scoring machine turning lines into points"]),
    (4, 22, 28, "Условие if (Альпака Аля)", ["alpaca", "maryam"],
     ["at a glowing fork in the road, choosing a path",
      "a signpost with two arrows: yes and no",
      "deciding which way glowing blocks should go",
      "comparing two numbers with a big > sign glowing",
      "playing a cheerful 'guess the number' game with hint arrows"]),
    (5, 29, 35, "Цикл for (Альпака Аля)", ["alpaca", "maryam"],
     ["riding a glowing carousel that repeats, counter ticking",
      "a loop of arrows going round and round over the grid",
      "walking across all 81 cells of a 9x9 grid one by one",
      "building a glowing multiplication table",
      "a bright pyramid of stars built row by row"]),
    (6, 36, 42, "Списки", ["cats"],
     ["arranging glowing items in a neat numbered row starting at 0",
      "adding a new item to the end of a glowing list",
      "removing one item from the list, others slide together",
      "finding the longest word among glowing cards",
      "a tidy list of tetromino pieces held in a paw"]),
    (7, 43, 49, "Классы", ["cats"],
     ["building a small labeled box-creature with two fields",
      "three cute cat 'objects' each with a name tag and color",
      "a blueprint card turning into real glowing objects",
      "a class blueprint with fields and one little method",
      "a Player object glowing with nick, score and combo fields"]),
    (8, 50, 56, "Доска 9×9", ["cats", "maryam"],
     ["arranging glowing blocks into a neat 9x9 grid board",
      "an empty 9x9 grid softly glowing in the dark",
      "walking through the grid cell by cell with a lantern",
      "one cell lit up as 'filled' among empty ones",
      "printing the board as dots and hashes on a glowing screen",
      "a finished tidy 9x9 board, cats proud beside it"]),
    (9, 57, 63, "Честная случайность", ["llama"],
     ["a glowing seed sprouting into a chain of numbers",
      "a magic dice that always gives the same roll for one seed",
      "two identical number-chains growing from the same seed",
      "a different seed making a different glowing chain",
      "a friendly random-machine labeled mulberry32, predictable magic"]),
    (10, 64, 70, "Мешок фигур", ["llama"],
     ["a magic bag drawing out seven different tetromino pieces",
      "two identical bags with the same seed showing same pieces",
      "seven distinct glowing pieces laid out in a fair row",
      "the llama checking two bags match, nodding wisely",
      "a fair 7-bag glowing, all seven shapes once each"]),
    (11, 71, 77, "Фигуры-тетромино", ["alpaca"],
     ["laying out all seven tetromino shapes I O T S Z J L, colorful",
      "describing a T-shape with tiny coordinate markers",
      "a square O piece drawn with coordinate dots",
      "a long I piece glowing with coordinate dots",
      "the full alphabet of seven tetromino shapes, fan layout"]),
    (12, 78, 85, "Повороты фигур", ["alpaca"],
     ["a tetromino piece rotating 90 degrees with motion arrows",
      "the four rotations of a T piece shown around a circle",
      "an arrow curving to show a 90-degree turn of a block shape",
      "spinning a glowing piece, trails of light",
      "all four orientations of one piece glowing together"]),
    (13, 86, 92, "Закон «сюда можно?»", ["pony", "maryam"],
     ["the pony as a gentle guard checking if a piece fits",
      "a piece hovering over the board with a green check",
      "a piece over the edge with a red no sign",
      "a piece over a filled cell blocked with a red x",
      "a big glowing checkmark: the piece fits, place allowed"]),
    (14, 93, 99, "Постановка и очистка", ["cats"],
     ["a piece landing softly onto the board, snug fit",
      "one full glowing row about to vanish",
      "a completed row flashing bright before clearing",
      "a cleared row leaving empty space, sparkles",
      "a satisfying line clear, blocks bursting into light"]),
    (15, 100, 105, "Счёт и комбо", ["cats", "maryam"],
     ["glowing points flying up after a line clear",
      "a combo counter growing, numbers multiplying",
      "points streaming up with a x2 multiplier glow",
      "a perfect-clear bonus burst, board totally empty",
      "a big joyful score number lighting up the scene"]),
    (16, 106, 112, "Перебор ходов", ["cats", "maryam"],
     ["many faint ghost-pieces showing all possible moves",
      "a fan of possible placements glowing over the board",
      "three candidate moves highlighted with soft outlines",
      "an empty move list meaning pass, a small shrug",
      "all possible moves for one piece shown at once"]),
    (17, 113, 119, "Оценка хода", ["cats"],
     ["weighing two moves on a glowing balance scale",
      "each move getting a glowing score badge",
      "sorting moves in a row, best one glowing at front",
      "a thoughtful cat scoring moves with tiny stars",
      "picking the best move, it shines brighter than others"]),
    (18, 120, 125, "Бот целиком", ["cats"],
     ["a wise little robot-kitten thinking about the board",
      "the bot scanning all moves then choosing one",
      "two bots playing each other turn by turn",
      "a bot vs bot match, score tally glowing above",
      "the bot kitten making its best move confidently"]),
    (19, 126, 132, "Первый экран (Flutter)", ["maryam"],
     ["Maryam painting a game screen with a brush of light",
      "a simple app screen with a big title text",
      "adding a glowing 'Play' button to the screen",
      "tapping the Play button, a happy spark",
      "a finished cozy menu screen with title and Play button"]),
    (20, 133, 139, "Доска виджетами", ["maryam"],
     ["building a 9x9 grid of widgets like stacking bricks",
      "a GridView of nine cells per row glowing",
      "coloring empty cells light and filled cells bright",
      "changing player colors on the board, palette nearby",
      "a colorful 9x9 board rendered on the app screen"]),
    (21, 140, 145, "Ввод (тап)", ["maryam"],
     ["a finger tapping a cell that lights up",
      "selecting a piece from the hand by tapping",
      "dragging a glowing piece toward the board",
      "placing a piece by tapping, board updates",
      "happy interaction: tap places a piece, board reacts"]),
    (22, 146, 152, "Сервер и WebSocket", ["llama"],
     ["a friendly server-house in the clouds of the internet",
      "a glowing wire carrying a 'hello' message both ways",
      "the llama reading a message envelope labeled JSON",
      "a move message travelling along a light-wire",
      "a tiny echo-server bouncing hello back, cozy"]),
    (23, 153, 159, "Два игрока", ["llama", "maryam"],
     ["two players across an ocean linked by a glowing thread",
      "a move passing from one player to the other via server",
      "the server as a fair judge checking a move",
      "turn passing between two players, arrow flips",
      "two friends playing together across the world, happy"]),
    (24, 160, 165, "Рейтинг ELO", ["llama"],
     ["a glowing rating meter going up after a win",
      "beating a strong opponent, rating jumps higher",
      "a scale comparing two players' ratings",
      "a draw nudging ratings only a little",
      "a shiny ELO leaderboard with the player climbing"]),
    (25, 166, 172, "Тесты", ["alpaca"],
     ["the alpaca in an inspector vest checking the game",
      "a green checkmark test passing brightly",
      "a row of green passing tests guarding the game",
      "tiny inspector animals watching over the code day and night",
      "a wall of green tests, all passing, reassuring"]),
    (26, 173, 178, "Красный → зелёный", ["cats"],
     ["a red failing test caught by a detective cat",
      "a magnifying glass over a broken line of code",
      "understanding the bug from the red test message",
      "fixing the code, the red test turning green",
      "the red-to-green moment, relief and sparkles"]),
    (27, 179, 185, "Git — машина времени", ["pony"],
     ["the pony opening a magic chest of project snapshots",
      "a commit shown as a labeled photo of the whole project",
      "a timeline of glowing commit-snapshots",
      "travelling back to an earlier snapshot, gentle glow",
      "pushing snapshots up to a GitHub cloud, safe"]),
    (28, 186, 195, "Баги и сборка", ["alpaca", "maryam"],
     ["hunting a little bug-creature hiding in the code",
      "catching the bug in a soft net, smiling",
      "adding a guard-test so the bug never returns",
      "the game building for the web browser, gears turning",
      "the game packaging into an Android phone",
      "reading a checklist to publish the game to stores"]),
    (29, 196, 200, "Финал 🎉", ["maryam", "pony", "llama", "alpaca", "cats"],
     ["Maryam customizing her own version of the game, proud",
      "running analyze and tests, all green celebration",
      "building the final version for all four devices",
      "showing the finished game to friends and family",
      "big joyful finale: Maryam and all animal friends around the glowing finished BlockDuel game on four screens web phone tablet computer"]),
]


def prompt_for(chars_keys, scene):
    who = "; ".join(CHARS[k] for k in chars_keys)
    return f"{STYLE}. Characters: {who}. Scene: {scene}."


def render_day(day, wnum, topic, chars_keys, scene, is_project):
    star = "🎯 МИНИ-ПРОЕКТ (праздничная сцена)" if is_project else "иллюстрация дня"
    who_ru = ", ".join(k for k in chars_keys)
    lines = [
        f"День {day:03d} · Неделя {wnum}: {topic}",
        f"Тип: {star}   ·   Герои: {who_ru}",
        "",
        "Что иллюстрируем (кратко): " + scene,
        "",
        "─── ГОТОВЫЙ ПРОМПТ (англ. — вставь в генератор изображений) ───",
        "",
        prompt_for(chars_keys, scene),
        "",
        "─── ПОДСКАЗКА ───",
        "Правь по чуть-чуть, как код: не нравится поза/цвет — добавь деталь и",
        "сгенерируй снова. Держи единый стиль, чтобы все картинки были «одной семьёй».",
    ]
    return "\n".join(lines) + "\n"


def masters():
    """Мастер-промпты обложки и портретов героев (сверх 200 дней)."""
    out = {}
    out["00_cover.txt"] = (
        "ОБЛОЖКА книги «Марьям в Мире Кода».\n\n"
        "─── ГОТОВЫЙ ПРОМПТ ───\n\n"
        + STYLE + ". " +
        "Maryam stepping through a glowing violet portal made of floating code "
        "blocks; her friends gathered around her: " + CHARS["pony"] + ", " +
        CHARS["llama"] + ", " + CHARS["alpaca"] + ", " + CHARS["cats"] + "; "
        "colorful tetromino blocks floating in the air; wide heroic cover "
        "composition, title space at top.\n")
    portraits = {
        "01_maryam.txt": ("maryam", "friendly portrait, curious brave smile"),
        "02_pony_po.txt": ("pony", "friendly portrait, round and cheerful"),
        "03_llama_lu.txt": ("llama", "calm wise portrait, gentle smile"),
        "04_alpaca_alya.txt": ("alpaca", "cheerful fluffy portrait, bouncy"),
        "05_cats.txt": ("cats", "playful portrait sitting together, tiny hats"),
    }
    for fname, (key, extra) in portraits.items():
        out[fname] = ("Портрет героя (мастер-промпт).\n\n─── ГОТОВЫЙ ПРОМПТ ───\n\n"
                      + STYLE + ". Character: " + CHARS[key] + ", " + extra + ".\n")
    return out


def readme():
    return (
        "# 🎨 image-promt — описания иллюстраций (на каждый день)\n\n"
        "Здесь на **каждый из 200 дней** курса лежит файл с готовым описанием\n"
        "иллюстрации (промптом) для книги «Марьям в Мире Кода». По ним ты\n"
        "создаёшь картинки в любой нейросети для рисования.\n\n"
        "## Как пользоваться\n\n"
        "1. Открой файл нужного дня (например `day015.txt`).\n"
        "2. Скопируй блок **«ГОТОВЫЙ ПРОМПТ»** и вставь в генератор изображений.\n"
        "3. Не нравится результат — добавь деталь и сгенерируй снова (как отладка).\n\n"
        "Стиль у всех промптов **единый** — чтобы картинки были «одной семьёй».\n"
        "Промпты на английском (нейросети его понимают лучше), с русской подписью.\n\n"
        "## Что внутри\n\n"
        "- `00_cover.txt` — обложка книги.\n"
        "- `01_maryam.txt` … `05_cats.txt` — портреты героев (мастер-промпты).\n"
        "- `day001.txt` … `day200.txt` — иллюстрация на каждый день (по неделям/темам).\n\n"
        "Файлы сгенерированы `tools/gen_image_prompts.py` (регенерация — тем же\n"
        "скриптом). Связано с книгой `book/` и курсом `course/`.\n")


def main():
    base = os.path.join(ROOT, "image-promt")
    os.makedirs(base, exist_ok=True)
    count = 0
    # мастер-промпты
    for fname, content in masters().items():
        with open(os.path.join(base, fname), "w", encoding="utf-8") as f:
            f.write(content)
        count += 1
    # по дням
    for (wnum, d0, d1, topic, chars_keys, scenes) in WEEKS:
        days = list(range(d0, d1 + 1))
        for i, day in enumerate(days):
            is_project = (i == len(days) - 1)
            if is_project:
                scene = scenes[-1]
            else:
                scene = scenes[i % (len(scenes) - 1)] if len(scenes) > 1 else scenes[0]
            content = render_day(day, wnum, topic, chars_keys, scene, is_project)
            with open(os.path.join(base, f"day{day:03d}.txt"), "w", encoding="utf-8") as f:
                f.write(content)
            count += 1
    with open(os.path.join(base, "README.md"), "w", encoding="utf-8") as f:
        f.write(readme())
    days_count = sum(w[2] - w[1] + 1 for w in WEEKS)
    print(f"  image-promt/ — {count} файлов промптов (дней: {days_count}) + README")
    assert days_count == 200, f"ожидалось 200 дней, вышло {days_count}"


if __name__ == "__main__":
    main()
