#!/usr/bin/env python3
"""gen_book_online.py — самодостаточная онлайн-версия книги (картинки внутри).

Берёт book/maryam_v_mire_koda.html (ссылается на картинки как images/NAME) и
встраивает каждую использованную картинку прямо в HTML как data:-URI. На выходе —
ОДИН файл book/maryam_v_mire_koda_online.html, который открывается где угодно без
папки images/ и годится для публикации артефактом (там локальные файлы не грузятся).

Запуск: python3 tools/gen_book_online.py
"""

import base64
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOK = os.path.join(ROOT, "book", "maryam_v_mire_koda.html")
IMG_DIR = os.path.join(ROOT, "book", "images")
OUT = os.path.join(ROOT, "book", "maryam_v_mire_koda_online.html")

MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
        ".webp": "image/webp", ".gif": "image/gif"}


def main():
    with open(BOOK, encoding="utf-8") as f:
        html = f.read()

    used = sorted(set(re.findall(r'src="images/([^"]+)"', html)))
    cache = {}
    total = 0
    missing = []
    for name in used:
        path = os.path.join(IMG_DIR, name)
        if not os.path.isfile(path):
            missing.append(name)
            continue
        ext = os.path.splitext(name)[1].lower()
        mime = MIME.get(ext, "application/octet-stream")
        with open(path, "rb") as fp:
            raw = fp.read()
        total += len(raw)
        cache[name] = f"data:{mime};base64," + base64.b64encode(raw).decode("ascii")

    def repl(m):
        name = m.group(1)
        return f'src="{cache[name]}"' if name in cache else m.group(0)

    html = re.sub(r'src="images/([^"]+)"', repl, html)

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)

    out_mb = os.path.getsize(OUT) / (1024 * 1024)
    print(f"  {os.path.relpath(OUT, ROOT)} — встроено {len(cache)} картинок "
          f"({total/1024/1024:.1f}MB raw), итоговый файл {out_mb:.1f}MB")
    if missing:
        print(f"  ! не найдены: {missing}")
    if out_mb > 16:
        print(f"  ! ВНИМАНИЕ: файл {out_mb:.1f}MB > лимита артефакта 16MB — нужно сжать картинки")


if __name__ == "__main__":
    main()
