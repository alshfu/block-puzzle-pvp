#!/usr/bin/env python3
"""gen_book_app.py — собирает из книги отдельное структурированное web-приложение.

Берёт монолитный book/maryam_v_mire_koda.html (весь CSS/JS/разметка внутри) и
раскладывает его в аккуратную папку book/web/ как настоящее web-приложение:

    book/web/
      index.html                 — чистая разметка + <head> с viewport/manifest
      css/book.css               — весь CSS вынесен наружу
      js/reader.js               — движок читалки (режим книги, разворот, печать)
      js/intro.js                — заставка (комната, камин, книга с полки)
      assets/img/*.jpg           — иллюстрации, ужатые под web (см. MAX_PX/JPEG_Q)
      assets/icons/*.png         — иконки приложения (из обложки)
      manifest.webmanifest       — PWA-манифест (устанавливается на телефон)
      sw.js                      — сервис-воркер: офлайн-кеш локальных файлов
      README.md                  — как запускать и деплоить

Смысл: ничего не весит больше, чем надо (картинки ужаты, CSS/JS отдельными
кешируемыми файлами), структура прозрачная, приложение ставится и работает офлайн.

Запуск:  python3 tools/gen_book_app.py
"""

import os
import re
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "book", "maryam_v_mire_koda.html")
SRC_IMG = os.path.join(ROOT, "book", "images")
OUT = os.path.join(ROOT, "book", "web")

# Иллюстрации показываются максимум в пол-страницы разворота, поэтому ужимаем:
# большая сторона <= MAX_PX, JPEG-качество JPEG_Q. Это режет вес в ~2 раза без
# видимой потери. Требуется sips (есть в macOS); иначе копируем оригинал.
MAX_PX = 900
JPEG_Q = 74


def sh(*args):
    subprocess.run(args, check=True, capture_output=True)


def fresh_dir(path):
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(path)


def optimize_image(src, dst):
    """Ужимает jpg через sips; при неудаче — просто копирует оригинал."""
    if shutil.which("sips"):
        try:
            sh("sips", "-Z", str(MAX_PX), "-s", "formatOptions", str(JPEG_Q),
               src, "--out", dst)
            if os.path.getsize(dst) > 0:
                return
        except Exception:
            pass
    shutil.copyfile(src, dst)


def make_icons(cover, icons_dir):
    """Готовит квадратные иконки приложения из обложки (центр-кроп → размеры)."""
    os.makedirs(icons_dir, exist_ok=True)
    if not (shutil.which("sips") and os.path.isfile(cover)):
        return []
    sq = os.path.join(icons_dir, "_square.jpg")
    try:
        # центр-кроп до квадрата по меньшей стороне (864×1152 → 864×864)
        sh("sips", "-c", "864", "864", cover, "--out", sq)
    except Exception:
        sq = cover
    made = []
    for size in (512, 192, 48):
        name = "favicon.png" if size == 48 else f"icon-{size}.png"
        dst = os.path.join(icons_dir, name)
        try:
            sh("sips", "-s", "format", "png", "-Z", str(size), sq, "--out", dst)
            made.append((size, name))
        except Exception:
            pass
    if sq.endswith("_square.jpg") and os.path.isfile(sq):
        os.remove(sq)
    return made


MANIFEST = """{
  "name": "Марьям в Мире Кода",
  "short_name": "Марьям",
  "description": "Детская книга-учебник: собери настоящую игру за 200 дней.",
  "start_url": "./app.html",
  "scope": "./",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#1b1522",
  "theme_color": "#5238C6",
  "icons": [
    { "src": "assets/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "assets/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ]
}
"""

SW = """/* sw.js — офлайн-кеш книги. Локальные файлы: cache-first + дозапись;
   шрифты Google (другой origin) идут в сеть как обычно. */
const CACHE = "maryam-book-v1";
self.addEventListener("install", (e) => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim())
));
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return;            // шрифты и прочее — в сеть
  e.respondWith(
    caches.open(CACHE).then((c) =>
      c.match(e.request).then((hit) =>
        hit || fetch(e.request).then((resp) => {
          if (resp && resp.status === 200) c.put(e.request, resp.clone());
          return resp;
        })
      )
    )
  );
});
"""

README = """# Марьям в Мире Кода — web-приложение

Отдельное статическое web-приложение книги. **Data-driven**: контент — это данные
(JSON, по файлу на разворот), страницы собираются рендером на лету. Никаких
тяжёлых монолитов и картинок в base64. Структура:

```
web/
  app.html                ⭐ ЛЁГКАЯ читалка (~12 КБ): оболочка, контент из JSON
  js/render.js            сборка страниц из content/*.json (по 2 дня на файл)
  content/
    book.json             манифест: порядок страниц (flow) + список разворотов
    spreads/spreadNNN.json 100 файлов, по 2 дня в каждом («две страницы — файл»)
  index.html              тяжёлый вид: все 200 дней инлайном (fallback для file://
                          и ИСТОЧНИК данных для генератора content/)
  css/book.css            все стили
  js/reader.js            читалка: режим книги (разворот из 2 страниц), печать A4
  js/intro.js             заставка: комната зимним вечером, камин, книга с полки
  assets/img/             иллюстрации (ужаты под web, всегда по URL)
  assets/icons/           иконки приложения (для установки на телефон)
  manifest.webmanifest    PWA-манифест (start_url → app.html)
  sw.js                   офлайн-кеш (cache-first: JSON и картинки кешируются сами)
```

**Что открывать:** `app.html` — лёгкая читалка (нужен http-сервер: fetch по
file:// браузер блокирует). `index.html` — тот же вид, но всё инлайном; работает
даже двойным кликом (file://), просто весит больше.

## Запуск локально
Нужен любой статический сервер (из-за манифеста и service worker):

```bash
cd book/web
python3 -m http.server 8000
# открой http://localhost:8000/app.html   (лёгкая data-driven читалка)
```

`app.html` тянет контент через fetch — нужен http-сервер (file:// браузер
блокирует). Если сервера нет — открой `index.html` двойным кликом: тот же вид,
всё инлайном, но тяжелее; офлайн-кеш и установка приложения тоже требуют http.

## Деплой
Залей содержимое папки `web/` на любой статический хостинг (GitHub Pages,
Netlify, nginx). Всё относительное — работает из любой подпапки.

## Пересборка
Одна команда собирает всё: `web/` из монолита `book/maryam_v_mire_koda.html`
(вырезает CSS/JS, ужимает картинки, пишет `index.html`), затем лёгкий слой —
`js/render.js`, `app.html` и `content/` (JSON) из свежего `index.html`:

```bash
python3 tools/gen_book_app.py
```

Отдельно контент-JSON можно пересобрать так: `python3 tools/gen_book_data.py`.
Канонический `render.js` живёт в `tools/book_assets/render.js` (в `web/js/` он
копируется). Правь исходник/генератор → пересобирай; руками файлы в `web/` не меняем.
"""


def main():
    with open(SRC, encoding="utf-8") as f:
        html = f.read()

    # 1) вынуть CSS
    m_style = re.search(r"<style>(.*?)</style>", html, re.S)
    css = m_style.group(1).strip("\n")
    html = html[:m_style.start()] + "<!--CSS-->" + html[m_style.end():]

    # 2) вынуть шрифтовой <link> (переиспользуем точный URL)
    m_font = re.search(r'<link rel="stylesheet" href="https://fonts\.googleapis[^"]+">', html)
    font_link = m_font.group(0) if m_font else ""

    # 3) вынуть скрипты (reader + intro), определить кто есть кто
    scripts = re.findall(r"<script>(.*?)</script>", html, re.S)
    reader_js = next((s for s in scripts if "__reader" in s), "")
    intro_js = next((s for s in scripts if 'getElementById("intro")' in s), "")
    html = re.sub(r"<script>.*?</script>", "", html, flags=re.S)

    # 4) тело = всё после маркера CSS (svg-спрайт, тулбар, заставка, .book-clip)
    body = html.split("<!--CSS-->", 1)[1]
    body = body.replace('src="images/', 'src="assets/img/')
    # убираем осевшие пустые строки от вырезанных скриптов
    body = re.sub(r"\n{3,}", "\n\n", body).strip("\n")

    # ── структура папок ──
    fresh_dir(OUT)
    for sub in ("css", "js", "assets/img", "assets/icons"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)

    with open(os.path.join(OUT, "css", "book.css"), "w", encoding="utf-8") as f:
        f.write(css + "\n")
    with open(os.path.join(OUT, "js", "reader.js"), "w", encoding="utf-8") as f:
        f.write(reader_js.strip("\n") + "\n")
    with open(os.path.join(OUT, "js", "intro.js"), "w", encoding="utf-8") as f:
        f.write(intro_js.strip("\n") + "\n")

    # ── картинки (только реально используемые) ──
    used = sorted(set(re.findall(r'src="assets/img/([^"]+)"', body)))
    total_in = total_out = 0
    for name in used:
        s = os.path.join(SRC_IMG, name)
        if not os.path.isfile(s):
            print("  ! нет картинки:", name)
            continue
        d = os.path.join(OUT, "assets", "img", name)
        total_in += os.path.getsize(s)
        optimize_image(s, d)
        total_out += os.path.getsize(d)

    # ── иконки/манифест/sw ──
    icons = make_icons(os.path.join(SRC_IMG, "00_cover.jpg"),
                       os.path.join(OUT, "assets", "icons"))
    with open(os.path.join(OUT, "manifest.webmanifest"), "w", encoding="utf-8") as f:
        f.write(MANIFEST)
    with open(os.path.join(OUT, "sw.js"), "w", encoding="utf-8") as f:
        f.write(SW)
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as f:
        f.write(README)

    # ── index.html: нормальный документ с <head> (в т.ч. viewport!) ──
    index = f"""<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Марьям в Мире Кода</title>
<meta name="description" content="Детская книга-учебник: девочка Марьям с друзьями-зверятами собирает настоящую игру за 200 дней.">
<meta name="theme-color" content="#5238C6">
<link rel="icon" href="assets/icons/favicon.png" sizes="48x48">
<link rel="apple-touch-icon" href="assets/icons/icon-192.png">
<link rel="manifest" href="manifest.webmanifest">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
{font_link}
<link rel="stylesheet" href="css/book.css">
</head>
<body>
{body}

<script defer src="js/reader.js"></script>
<script defer src="js/intro.js"></script>
<script>
  if ("serviceWorker" in navigator) {{
    window.addEventListener("load", function () {{
      navigator.serviceWorker.register("sw.js").catch(function () {{}});
    }});
  }}
</script>
</body>
</html>
"""
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
        f.write(index)

    # ── data-driven слой: render.js + app.html + content/ ──
    # index.html выше — тяжёлый монолит (все 200 дней инлайном): он остаётся как
    # запасной вид для file:// и как ИСТОЧНИК данных для gen_book_data. Ниже строим
    # лёгкую data-driven читалку: контент — в JSON (content/spreads/*.json, по 2 дня
    # на файл), а app.html — почти пустая оболочка, наполняемая render.js на лету.
    render_src = os.path.join(ROOT, "tools", "book_assets", "render.js")
    with open(render_src, encoding="utf-8") as f:
        render_js = f.read()
    with open(os.path.join(OUT, "js", "render.js"), "w", encoding="utf-8") as f:
        f.write(render_js)

    # app.html = index.html, но .wrap пустой (контент придёт из JSON) + подключён render.js
    app = re.sub(r'(<div class="wrap">).*(</div><!-- /\.wrap -->)',
                 r'\1\n    <!-- Контент собирается из content/book.json + content/spreads/*.json скриптом render.js -->\n\2',
                 index, flags=re.S)
    app = app.replace('<script defer src="js/reader.js"></script>',
                      '<script defer src="js/reader.js"></script>\n<script defer src="js/render.js"></script>')
    with open(os.path.join(OUT, "app.html"), "w", encoding="utf-8") as f:
        f.write(app)

    # content/ из свежесобранного index.html (единый источник — 200 дней)
    import importlib.util
    data_gen = os.path.join(ROOT, "tools", "gen_book_data.py")
    spec = importlib.util.spec_from_file_location("gen_book_data", data_gen)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.main()

    # ── отчёт ──
    def kb(n):
        return f"{n/1024:.0f} KB"

    def mb(n):
        return f"{n/1024/1024:.1f} MB"

    idx_sz = os.path.getsize(os.path.join(OUT, "index.html"))
    css_sz = os.path.getsize(os.path.join(OUT, "css", "book.css"))
    js_sz = (os.path.getsize(os.path.join(OUT, "js", "reader.js"))
             + os.path.getsize(os.path.join(OUT, "js", "intro.js")))
    print("  book/web/ собрано:")
    print(f"    index.html {kb(idx_sz)} · css {kb(css_sz)} · js {kb(js_sz)}")
    print(f"    картинок: {len(used)} — {mb(total_in)} → {mb(total_out)} "
          f"(−{(1-total_out/max(total_in,1))*100:.0f}%)")
    print(f"    иконки: {', '.join(n for _, n in icons) or 'нет sips'}")
    total = sum(os.path.getsize(os.path.join(dp, fn))
                for dp, _, fns in os.walk(OUT) for fn in fns)
    print(f"    ИТОГО web/: {mb(total)}")


if __name__ == "__main__":
    main()
