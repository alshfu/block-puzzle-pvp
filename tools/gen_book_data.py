#!/usr/bin/env python3
# gen_book_data.py — превращает монолит book/web/index.html в data-driven контент.
#
# Зачем: раньше книга существовала как один тяжёлый HTML (а «онлайн»-вариант —
# и вовсе 10 МБ с картинками в base64). Это неправильно: в 2026-м страница не
# должна весить десятки мегабайт. Здесь мы вынимаем 200 дней-страниц в структурный
# JSON («инструкция отображения контента»), по ФАЙЛУ НА РАЗВОРОТ (2 дня), а весь
# оформительский «хром» (герои, обложки недель, главы-нарратив, план, промпты,
# футер) сохраняем дословно как поток. Рендер собирает страницу из данных на лету;
# картинки — всегда по URL, никогда в base64.
#
# Вход:  book/web/index.html (единственный источник, где все 200 дней уже сведены).
# Выход: book/web/content/book.json                — манифест: мета + flow + список разворотов
#        book/web/content/spreads/spreadNNN.json    — по 2 дня в файле (100 файлов)
#
# Схема дня (structured):
#   { day, of, theme, title,
#     image? {src, alt}, topic?,          # недели 1–6 (фото-сцена)
#     badge? , seen?,                      # недели 7–29 (спрайт-бейдж + подпись)
#     prose: [ {cls?, html} ],             # абзацы, инлайновый HTML сохраняется
#     task?: { title, steps:[html], together? },
#     next?: <номер следующего дня> }
#
# flow (в book.json) — упорядоченный список узлов страницы:
#   { "chrome": "<...дословный html...>" }  |  { "day": N }
# Рендер склеивает всё в одну строку и ставит как innerHTML .wrap (чтобы CSS-
# колонки книги-разворота флоучили контент как прямых детей .wrap).
#
# Запуск: python3 tools/gen_book_data.py
# Идемпотентно: полностью перезаписывает content/ из index.html.

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "book", "web", "index.html")
OUT_DIR = os.path.join(ROOT, "book", "web", "content")
SPREADS_DIR = os.path.join(OUT_DIR, "spreads")

DAYS_PER_SPREAD = 2  # «каждые две страницы — файл»

DAY_RE = re.compile(
    r'<article class="day-page" id="d(?P<num>\d+)">(?P<body>.*?)</article>', re.S)


def inner(html, cls_or_tag, is_class=True):
    """Вернуть внутренний HTML первого <div class="X">…</div> (сбалансированно по div)."""
    if is_class:
        m = re.search(r'<div class="%s"[^>]*>' % re.escape(cls_or_tag), html)
    else:
        m = re.search(r'<%s[^>]*>' % re.escape(cls_or_tag), html)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    tag = "div" if is_class else cls_or_tag
    open_re = re.compile(r'<%s\b' % tag)
    close_re = re.compile(r'</%s>' % tag)
    while i < len(html) and depth > 0:
        o = open_re.search(html, i)
        c = close_re.search(html, i)
        if c is None:
            break
        if o is not None and o.start() < c.start():
            depth += 1
            i = o.end()
        else:
            depth -= 1
            if depth == 0:
                return html[start:c.start()]
            i = c.end()
    return None


def parse_day(num, body):
    day = {"day": num, "of": 200}

    # kicker → тема
    kick = re.search(r'<div class="day-kicker">(.*?)</div>', body, re.S)
    if kick:
        t = re.search(r'тема:\s*(.+?)\s*</', kick.group(0), re.S)
        if not t:
            t = re.search(r'тема:\s*(.+)$', kick.group(1).strip())
        if t:
            day["theme"] = t.group(1).strip()

    # заголовок h3
    h3 = re.search(r'<h3>(.*?)</h3>', body, re.S)
    if h3:
        day["title"] = h3.group(1).strip()

    # вариант B: бейдж-спрайт + подпись (недели 7–29)
    badge = re.search(
        r'<div class="day-badge"[^>]*title="(?P<seen>[^"]*)"[^>]*>.*?<use href="#(?P<badge>[^"]+)"', body, re.S)
    if badge:
        day["badge"] = badge.group("badge")
        day["seen"] = badge.group("seen")

    # вариант A: фото-сцена (недели 1–6)
    img = re.search(r'<img src="(?P<src>[^"]+)"\s+alt="(?P<alt>[^"]*)"', body)
    if img:
        day["image"] = {"src": img.group("src"), "alt": img.group("alt")}
        topic = re.search(
            r'<div class="scene-topic"><small>[^<]*</small>(.*?)</div>', body, re.S)
        if topic:
            day["topic"] = topic.group(1).strip()

    # проза — абзацы с сохранением инлайнового HTML
    prose_html = inner(body, "prose")
    prose = []
    if prose_html:
        for pm in re.finditer(r'<p(?P<attrs>[^>]*)>(?P<html>.*?)</p>', prose_html, re.S):
            node = {"html": pm.group("html").strip()}
            cls = re.search(r'class="([^"]+)"', pm.group("attrs"))
            if cls:
                node["cls"] = cls.group(1)
            prose.append(node)
    day["prose"] = prose

    # задание дня
    task_html = inner(body, "task")
    if task_html:
        task = {}
        h = re.search(r'<div class="h">(.*?)</div>', task_html, re.S)
        if h:
            task["title"] = h.group(1).strip()
        steps = [li.strip() for li in re.findall(
            r'<li>(.*?)</li>', task_html, re.S)]
        task["steps"] = steps
        tog = re.search(
            r'<p class="together">(.*?)</p>', task_html, re.S)
        if tog:
            task["together"] = " ".join(tog.group(1).split())
        day["task"] = task

    # следующий день (не выходя за пределы книги — в оригинале у дня 200
    # осталась ошибочная ссылка на несуществующий «День 201», её отбрасываем)
    nxt = re.search(r'<div class="day-next">.*?href="#d(\d+)"', body, re.S)
    if nxt and int(nxt.group(1)) <= 200:
        day["next"] = int(nxt.group(1))

    return day


def build_flow(wrap_inner):
    """Разбить содержимое .wrap на поток: дословный «хром» + ссылки на дни."""
    flow = []
    days = {}
    pos = 0
    for m in DAY_RE.finditer(wrap_inner):
        chrome = wrap_inner[pos:m.start()]
        if chrome.strip():
            flow.append({"chrome": chrome})
        num = int(m.group("num"))
        days[num] = parse_day(num, m.group("body"))
        flow.append({"day": num})
        pos = m.end()
    tail = wrap_inner[pos:]
    if tail.strip():
        flow.append({"chrome": tail})
    return flow, days


def main():
    if not os.path.exists(SRC):
        sys.exit("Не найден источник: %s" % SRC)
    html = open(SRC, encoding="utf-8").read()

    wm = re.search(r'<div class="wrap">(.*)</div><!-- /\.wrap -->', html, re.S)
    if not wm:
        sys.exit("Не найден контейнер <div class=\"wrap\"> … </div><!-- /.wrap -->")
    wrap_inner = wm.group(1)

    flow, days = build_flow(wrap_inner)
    if len(days) != 200:
        print("⚠ ожидалось 200 дней, найдено %d" % len(days), file=sys.stderr)

    os.makedirs(SPREADS_DIR, exist_ok=True)
    # очистить старые развороты
    for f in os.listdir(SPREADS_DIR):
        if f.startswith("spread") and f.endswith(".json"):
            os.remove(os.path.join(SPREADS_DIR, f))

    # разложить дни по разворотам (по 2 дня)
    nums = sorted(days)
    spreads = []
    for i in range(0, len(nums), DAYS_PER_SPREAD):
        chunk = nums[i:i + DAYS_PER_SPREAD]
        sid = i // DAYS_PER_SPREAD + 1
        fname = "spread%03d.json" % sid
        payload = {"id": "spread%03d" % sid,
                   "days": [days[n] for n in chunk]}
        with open(os.path.join(SPREADS_DIR, fname), "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=1)
        spreads.append({"id": "spread%03d" % sid, "file": "spreads/" + fname,
                        "days": chunk})

    # индекс: какой день в каком развороте
    day_index = {}
    for sp in spreads:
        for n in sp["days"]:
            day_index[str(n)] = sp["file"]

    title = (re.search(r'<title>(.*?)</title>', html, re.S) or [None, "Марьям в Мире Кода"])[1]
    manifest = {
        "title": title.strip(),
        "totalDays": len(days),
        "daysPerSpread": DAYS_PER_SPREAD,
        "generatedFrom": "book/web/index.html",
        "spreads": spreads,
        "dayIndex": day_index,
        "flow": flow,
    }
    with open(os.path.join(OUT_DIR, "book.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)

    # отчёт
    book_sz = os.path.getsize(os.path.join(OUT_DIR, "book.json"))
    spread_files = [f for f in os.listdir(SPREADS_DIR) if f.endswith(".json")]
    total_spread = sum(os.path.getsize(os.path.join(SPREADS_DIR, f))
                       for f in spread_files)
    print("✓ %d дней → %d разворотов" % (len(days), len(spreads)))
    print("  book.json           %6.1f КБ" % (book_sz / 1024))
    print("  spreads/ (%3d файла) %6.1f КБ  (в среднем %.1f КБ/файл)"
          % (len(spread_files), total_spread / 1024,
             total_spread / 1024 / max(1, len(spread_files))))
    print("  → book/web/content/")


if __name__ == "__main__":
    main()
