#!/usr/bin/env python3
"""gen_book_online.py — тонкий редирект на data-driven ридер книги.

ИСТОРИЯ. Раньше здесь собирался «самодостаточный» онлайн-HTML: каждая из 75+
картинок впечатывалась в файл как base64 data:-URI. Результат — монолит на ~10 МБ.
Это плохо: страница в 2026-м не должна весить десятки мегабайт, а один файл нельзя
ни закэшировать по кусочкам, ни отдать по одной странице.

СЕЙЧАС. Книга — data-driven: оболочка book/web/app.html + контент в
book/web/content/ (book.json + spreads/*.json, по 2 дня на файл), картинки — по URL
(assets/img/…). Генерирует контент tools/gen_book_data.py.

Этот скрипт лишь превращает старый путь book/maryam_v_mire_koda_online.html в
КРОШЕЧНУЮ страницу-редирект на web/app.html — чтобы старые ссылки/закладки не
ломались. Никакого base64. Запуск: python3 tools/gen_book_online.py
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "book", "maryam_v_mire_koda_online.html")
TARGET = "web/app.html"  # относительный путь от book/

REDIRECT_HTML = """<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Марьям в Мире Кода — читалка переехала</title>
<meta http-equiv="refresh" content="0; url=%(target)s">
<link rel="canonical" href="%(target)s">
<style>
  html,body{margin:0;height:100%%;display:grid;place-items:center;
    font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:#F6F1E7;color:#2E2620}
  .card{max-width:520px;padding:32px;text-align:center;background:#fff;border-radius:18px;
    box-shadow:0 12px 40px rgba(0,0,0,.12)}
  h1{font-size:22px;margin:0 0 10px}
  p{font-size:15px;line-height:1.5;color:#5b5346;margin:0 0 18px}
  a.btn{display:inline-block;padding:12px 22px;border-radius:12px;background:#5238C6;color:#fff;
    text-decoration:none;font-weight:700}
  small{display:block;margin-top:16px;color:#9a8f7d;font-size:12px}
</style>
</head>
<body>
  <div class="card">
    <h1>📖 Читалка переехала</h1>
    <p>Книга теперь <b>лёгкая и data-driven</b>: страницы собираются из JSON
       (по файлу на разворот), а не из одного тяжёлого HTML. Секунду — перенаправляем…</p>
    <a class="btn" href="%(target)s">Открыть книгу →</a>
    <small>Если не открылось автоматически — нажми на кнопку.
       Прежний 10 МБ-файл с картинками в base64 упразднён.</small>
  </div>
  <script>location.replace("%(target)s");</script>
</body>
</html>
"""


def main():
    html = REDIRECT_HTML % {"target": TARGET}
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    kb = os.path.getsize(OUT) / 1024
    print("✓ %s — тонкий редирект на %s (%.1f КБ, было ~10 МБ base64)"
          % (os.path.relpath(OUT, ROOT), TARGET, kb))


if __name__ == "__main__":
    main()
