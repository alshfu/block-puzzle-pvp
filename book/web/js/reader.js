    (function () {
        var body = document.body, root = document.documentElement;
        var wrap = document.querySelector(".wrap");
        var clip = document.querySelector(".book-clip");
        var leaf = document.getElementById("leaf");
        var ind = document.getElementById("rdInd");
        var KEY = "maryam-reader-mode";
        var BAR = parseInt(getComputedStyle(root).getPropertyValue("--barH")) || 52;
        var pg = 0, count = 1, cols = 2, colW = 300, gutter = 56, pad = 34, spreadW = 720, spreadH = 480;
        var turning = false;

        // невидимый маркер конца — по нему считаем число страниц
        var probe = document.createElement("span");
        probe.className = "end-probe";
        probe.setAttribute("aria-hidden", "true");
        wrap.appendChild(probe);

        function inBook() { return body.classList.contains("mode-book"); }
        function reduce() { return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches; }
        function stride() { return colW + gutter; }
        function centerX(el) { var r = el.getBoundingClientRect(); return r.left + r.width / 2; }
        function maxPg() { return Math.max(0, (Math.ceil(count / cols) - 1) * cols); }

        // левый край первой колонки на экране (центр видимой колонки pg)
        function baseX() { return clip.getBoundingClientRect().left + pad + colW / 2; }
        // индекс страницы элемента (в «одиночных» страницах)
        function pageOf(el) { return pg + Math.round((centerX(el) - baseX()) / stride()); }

        function dims() {
            var w = window.innerWidth, h = window.innerHeight;
            cols = w >= 820 ? 2 : 1;
            var mX = Math.max(14, Math.round(w * 0.03));
            var mY = Math.max(10, Math.round(h * 0.02));
            var availW = w - 2 * mX;
            var availH = h - BAR - 2 * mY;
            if (cols === 2) {
                spreadH = Math.min(availH, Math.round(availW / 1.5));
                spreadW = Math.min(availW, Math.round(spreadH * 1.5));
                gutter = Math.max(30, Math.round(spreadW * 0.055));
                pad = Math.max(20, Math.round(spreadW * 0.04));
                colW = Math.floor((spreadW - gutter - 2 * pad) / 2);
                spreadW = 2 * colW + gutter + 2 * pad;
            } else {
                spreadH = availH;
                pad = Math.max(16, Math.round(w * 0.055));
                spreadW = Math.min(availW, Math.round(spreadH * 0.72));
                colW = spreadW - 2 * pad;
                gutter = 60;
                spreadW = colW + 2 * pad;
            }
            body.classList.toggle("single", cols === 1);
            root.style.setProperty("--cols", cols);
            root.style.setProperty("--colW", colW + "px");
            root.style.setProperty("--pad", pad + "px");
            root.style.setProperty("--gutter", gutter + "px");
            root.style.setProperty("--spreadW", spreadW + "px");
            root.style.setProperty("--spreadH", spreadH + "px");
        }

        function label() {
            var left = pg + 1, right = Math.min(pg + cols, count);
            ind.textContent = (cols === 2 && right > left)
                ? (left + "–" + right + " / " + count)
                : (left + " / " + count);
            // фолио по углам: слева — левая страница, справа — правая (или единственная)
            var fl = document.getElementById("folioL"), fr = document.getElementById("folioR");
            if (fl && fr) {
                if (cols === 2) { fl.textContent = left; fr.textContent = right > left ? right : ""; }
                else { fl.textContent = ""; fr.textContent = left; }
            }
        }

        function apply(anim) {
            if (anim === false) wrap.classList.add("no-anim");
            root.style.setProperty("--pg", pg);
            label();
            if (anim === false) { void wrap.offsetWidth; wrap.classList.remove("no-anim"); }
        }

        // перейти на страницу i (выравниваем к началу разворота)
        function setPage(i, anim) {
            i = Math.max(0, Math.min(maxPg(), i));
            pg = Math.floor(i / cols) * cols;
            apply(anim);
        }

        // листание с анимацией переворота листа
        function flip(dir) {
            if (!inBook() || turning) return;
            var target = pg + dir * cols;
            if (target < 0 || target > maxPg()) return;
            if (reduce()) { setPage(target); return; }
            turning = true;
            leaf.className = "leaf " + (dir > 0 ? "fwd" : "bwd");
            body.classList.add("turning");
            void leaf.offsetWidth;
            leaf.classList.add("go");
            // на середине переворота (лист ребром) — меняем разворот под ним
            setTimeout(function () { setPage(target, false); }, 280);
            setTimeout(function () {
                body.classList.remove("turning");
                leaf.className = "leaf";
                turning = false;
            }, 570);
        }

        // прыжок к якорю (оглавление, day-nav): на начало нужного разворота
        function jumpTo(el) {
            var i = pageOf(el);
            setPage(Math.floor(i / cols) * cols);
        }

        function layout() {
            if (!inBook()) return;
            dims();
            wrap.classList.add("no-anim");
            pg = Math.floor(pg / cols) * cols;
            root.style.setProperty("--pg", pg);
            void wrap.offsetWidth;                                  // форсим пересчёт колонок
            var last = pg + Math.round((centerX(probe) - baseX()) / stride());
            count = Math.max(1, last + 1);
            if (pg > maxPg()) pg = maxPg();
            apply(false);
        }

        function setMode(on, save) {
            body.classList.toggle("mode-book", on);
            document.getElementById("rdMode").textContent = on ? "📜 Обычный вид" : "📖 Режим книги";
            document.getElementById("rdMode").setAttribute("aria-pressed", on ? "true" : "false");
            if (save !== false) { try { localStorage.setItem(KEY, on ? "1" : "0"); } catch (e) {} }
            if (on) { layout(); }
            else { wrap.style.removeProperty("transform"); body.classList.remove("single"); }
        }

        document.getElementById("rdMode").addEventListener("click", function () { setMode(!inBook()); });
        document.getElementById("rdPrev").addEventListener("click", function () { flip(-1); });
        document.getElementById("rdNext").addEventListener("click", function () { flip(1); });
        document.getElementById("rdPrint").addEventListener("click", function () { window.print(); });

        window.addEventListener("keydown", function (e) {
            if (!inBook() || e.metaKey || e.ctrlKey || e.altKey) return;
            if (e.key === "ArrowRight" || e.key === "PageDown" || e.key === " ") { e.preventDefault(); flip(1); }
            else if (e.key === "ArrowLeft" || e.key === "PageUp") { e.preventDefault(); flip(-1); }
            else if (e.key === "Home") { e.preventDefault(); setPage(0); }
            else if (e.key === "End") { e.preventDefault(); setPage(maxPg()); }
        });

        // клики: якоря → нужный разворот; пустые зоны слева/справа → листание
        document.addEventListener("click", function (e) {
            var a = e.target.closest ? e.target.closest('a[href^="#"]') : null;
            if (a) {
                var id = a.getAttribute("href").slice(1);
                var t = id && document.getElementById(id);
                if (t && inBook()) { e.preventDefault(); jumpTo(t); }
                return;
            }
            if (inBook() && !(e.target.closest && e.target.closest("a,button,input,select,textarea,pre,code"))) {
                var x = e.clientX, w = window.innerWidth;
                if (x < w * 0.30) flip(-1);
                else if (x > w * 0.70) flip(1);
            }
        });

        // свайп на тач-экранах
        var sx = 0, sy = 0, sw = false;
        window.addEventListener("touchstart", function (e) {
            if (!inBook()) return;
            var t = e.touches[0]; sx = t.clientX; sy = t.clientY; sw = true;
        }, {passive: true});
        window.addEventListener("touchend", function (e) {
            if (!inBook() || !sw) return; sw = false;
            var t = e.changedTouches[0], dx = t.clientX - sx, dy = t.clientY - sy;
            if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) flip(dx < 0 ? 1 : -1);
        }, {passive: true});

        var rt;
        function relayout() { clearTimeout(rt); rt = setTimeout(layout, 150); }
        window.addEventListener("resize", relayout);
        window.addEventListener("load", function () { if (inBook()) layout(); });
        if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { if (inBook()) layout(); });
        Array.prototype.forEach.call(document.images, function (im) {
            if (!im.complete) im.addEventListener("load", relayout);
        });

        // старт: книга по умолчанию (пока пользователь явно не выбрал обычный вид)
        var saved = null;
        try { saved = localStorage.getItem(KEY); } catch (e) {}
        setMode(saved !== "0", false);

        // хук для заставки: пересчитать разбивку/перейти на страницу
        window.__reader = { layout: layout, go: function (i) { setPage(i); }, jump: jumpTo, setMode: setMode };
    })();
