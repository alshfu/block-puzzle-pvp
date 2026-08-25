// interactive.js — интерактивный слой читалки «Марьям в Мире Кода».
//
// Работает поверх ЛЮБОЙ сборки (app.html — data-driven, и index.html — инлайновая):
// улучшает уже готовый DOM после события `book:rendered` (или сразу, если книга
// инлайновая). Ничего не знает про генерацию — только про разметку страниц.
//
// Даёт четыре вещи:
//   1) ПРОГРЕСС по 200 дням — кнопка «пройдено» на каждой странице-дне, чекбоксы
//      шагов задания, прогресс-бар X/200 и серия дней, «продолжить с последнего».
//      Хранение — localStorage (у каждого ребёнка своё, офлайн).
//   2) НАВИГАЦИЯ и ПОИСК — «перейти к дню N», поиск по тексту/теме с прыжком.
//   3) РАСКРЫВАЕМЫЕ блоки — врезка «Настоящее слово» сворачивается; термины
//      (.word) кликаются и показывают определение из мини-глоссария (тултип).
//   4) ЖИВЫЕ ДЕМО — <div class="demo-mount" data-demo="board|score|elo|prng">
//      превращается в маленький работающий виджет по теме дня.
//
// Всё детерминированно, без сети; прогресс приватный (localStorage).
(function () {
    "use strict";

    var STORE_KEY = "maryam-progress-v1";
    var TOTAL = 200;

    // ── хранилище прогресса ────────────────────────────────────────────────
    function load() {
        try { return JSON.parse(localStorage.getItem(STORE_KEY)) || {}; }
        catch (e) { return {}; }
    }
    function save(s) {
        try { localStorage.setItem(STORE_KEY, JSON.stringify(s)); } catch (e) {}
    }
    var state = load();
    state.done = state.done || {};   // {57:true}
    state.steps = state.steps || {}; // {"57-0":true}
    state.last = state.last || 0;    // номер последнего открытого дня

    function doneCount() { return Object.keys(state.done).filter(function (k) { return state.done[k]; }).length; }

    // самая длинная серия подряд пройденных дней (до сегодняшнего максимума)
    function streak() {
        var best = 0, cur = 0;
        for (var d = 1; d <= TOTAL; d++) {
            if (state.done[d]) { cur++; if (cur > best) best = cur; }
            else cur = 0;
        }
        return best;
    }

    // ── утилиты ────────────────────────────────────────────────────────────
    function el(tag, cls, html) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (html != null) e.innerHTML = html;
        return e;
    }
    function dayNumOf(article) {
        var m = /^d(\d+)$/.exec(article.id || "");
        return m ? parseInt(m[1], 10) : null;
    }
    function inBook() { return document.body.classList.contains("mode-book"); }
    function relayout() { try { if (window.__reader && window.__reader.layout) window.__reader.layout(); } catch (e) {} }

    function jumpToDay(n) {
        var t = document.getElementById("d" + ("00" + n).slice(-3));
        if (!t) return false;
        if (inBook() && window.__reader && window.__reader.jump) window.__reader.jump(t);
        else t.scrollIntoView({behavior: "smooth", block: "start"});
        return true;
    }

    // ── 1) ПРОГРЕСС: кнопка «пройдено» + чекбоксы шагов ────────────────────
    function enhanceDay(article) {
        var n = dayNumOf(article);
        if (!n || article.dataset.enhanced) return;
        article.dataset.enhanced = "1";

        // кнопка «пройдено» после kicker
        var kicker = article.querySelector(".day-kicker");
        var btn = el("button", "day-done", "");
        function paint() {
            var d = !!state.done[n];
            btn.className = "day-done" + (d ? " is-done" : "");
            btn.textContent = d ? "✓ День пройден" : "Отметить пройденным";
            btn.setAttribute("aria-pressed", d ? "true" : "false");
        }
        btn.type = "button";
        btn.addEventListener("click", function (e) {
            e.stopPropagation();
            state.done[n] = !state.done[n];
            if (!state.done[n]) delete state.done[n];
            save(state); paint(); updateHud();
        });
        paint();
        if (kicker && kicker.nextSibling) kicker.parentNode.insertBefore(btn, kicker.nextSibling);
        else article.insertBefore(btn, article.firstChild);

        // чекбоксы шагов задания
        var lis = article.querySelectorAll(".task ol > li");
        Array.prototype.forEach.call(lis, function (li, i) {
            if (li.querySelector(".step-check")) return;
            var key = n + "-" + i;
            var box = el("span", "step-check" + (state.steps[key] ? " on" : ""), "");
            box.setAttribute("role", "checkbox");
            box.setAttribute("tabindex", "0");
            box.setAttribute("aria-checked", state.steps[key] ? "true" : "false");
            function toggle(e) {
                e.stopPropagation();
                state.steps[key] = !state.steps[key];
                if (!state.steps[key]) delete state.steps[key];
                box.className = "step-check" + (state.steps[key] ? " on" : "");
                box.setAttribute("aria-checked", state.steps[key] ? "true" : "false");
                li.classList.toggle("step-done", !!state.steps[key]);
                save(state);
            }
            box.addEventListener("click", toggle);
            box.addEventListener("keydown", function (e) { if (e.key === " " || e.key === "Enter") { e.preventDefault(); toggle(e); } });
            li.classList.toggle("step-done", !!state.steps[key]);
            li.insertBefore(box, li.firstChild);
        });

        // запомнить последний открытый день (для «продолжить»)
        if (n > (state.last || 0)) { state.last = n; save(state); }
    }

    // ── 3) РАСКРЫВАЕМЫЕ: врезка «Настоящее слово» → сворачивание ───────────
    function enhanceReal(article) {
        var rw = article.querySelector(".real-word");
        if (!rw || rw.dataset.collapsible) return;
        rw.dataset.collapsible = "1";
        var h = rw.querySelector(".h");
        if (!h) return;
        // обернуть контент (всё после .h) в .rw-body — чтобы чисто сворачивать
        var bodyWrap = el("div", "rw-body");
        var node = h.nextSibling;
        while (node) { var nx = node.nextSibling; bodyWrap.appendChild(node); node = nx; }
        rw.appendChild(bodyWrap);
        rw.classList.add("open");                    // по умолчанию открыто
        h.style.cursor = "pointer";
        h.setAttribute("role", "button");
        h.setAttribute("tabindex", "0");
        h.insertAdjacentHTML("beforeend", '<span class="rw-caret" aria-hidden="true">▾</span>');
        function toggle(e) {
            e && e.stopPropagation();
            rw.classList.toggle("open");
            relayout();
        }
        h.addEventListener("click", toggle);
        h.addEventListener("keydown", function (e) { if (e.key === " " || e.key === "Enter") { e.preventDefault(); toggle(e); } });
    }

    // ── 3b) ТЕРМИНЫ-ТУЛТИПЫ: клик по .word → определение ───────────────────
    var GLOSS = {
        "тетромино": "Фигура из четырёх квадратиков. Их семь: I, O, T, S, Z, J, L.",
        "класс": "Чертёж вещи: описывает, какие у неё поля и что она умеет. По одному классу делают много объектов.",
        "поле": "Одна «ячейка данных» внутри объекта (например, имя или цвет).",
        "объект": "Конкретная вещь, сделанная по классу-чертежу.",
        "метод": "Функция внутри класса — умение объекта (например, мяукнуть).",
        "переменная": "Именованная коробочка, в которой лежит значение. Его можно менять.",
        "функция": "Кусочек кода с именем: даёшь вход — получаешь выход. Можно звать много раз.",
        "зерно": "Число seed, из которого генератор растит всю цепочку «случайных» чисел.",
        "детерминизм": "Одинаковый вход всегда даёт одинаковый результат. Нужен честному онлайну, реплеям и тестам.",
        "репозиторий": "Коробка со всем проектом (код, картинки, история). Приносит её команда git clone.",
        "ELO": "Рейтинг силы игрока. Победа над сильным поднимает больше, чем над слабым.",
        "WebSocket": "Постоянный двусторонний провод между твоей игрой и сервером — можно слать в обе стороны.",
        "JSON": "Текстовый «конверт» для данных, понятный и клиенту, и серверу."
    };
    var activeTip = null;
    function closeTip() { if (activeTip) { activeTip.remove(); activeTip = null; } }
    function enhanceTerms(article) {
        var words = article.querySelectorAll(".word");
        Array.prototype.forEach.call(words, function (w) {
            if (w.dataset.tip) return;
            var key = (w.textContent || "").trim().toLowerCase();
            var def = null;
            for (var g in GLOSS) { if (g.toLowerCase() === key) { def = GLOSS[g]; break; } }
            if (!def) return;
            w.dataset.tip = "1";
            w.classList.add("has-tip");
            w.setAttribute("tabindex", "0");
            function show(e) {
                e.stopPropagation();
                closeTip();
                var tip = el("span", "term-tip", def);
                document.body.appendChild(tip);
                var r = w.getBoundingClientRect();
                tip.style.left = Math.max(8, Math.min(window.innerWidth - tip.offsetWidth - 8, r.left)) + "px";
                tip.style.top = (r.bottom + 6) + "px";
                activeTip = tip;
            }
            w.addEventListener("click", show);
            w.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); show(e); } });
        });
    }
    document.addEventListener("click", closeTip, true);
    window.addEventListener("resize", closeTip);

    // поля ввода/слайдеры/кнопки демо не должны листать книгу стрелками/пробелом:
    // глушим keydown до того, как он всплывёт к обработчику читалки на window
    document.addEventListener("keydown", function (e) {
        var t = e.target;
        if (t && /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName)) e.stopPropagation();
    });

    // ── 4) ЖИВЫЕ ДЕМО ──────────────────────────────────────────────────────
    function buildDemo(mount) {
        if (mount.dataset.built) return;
        mount.dataset.built = "1";
        var type = mount.getAttribute("data-demo");
        (DEMOS[type] || DEMOS._unknown)(mount);
    }

    var DEMOS = {
        _unknown: function (m) { m.appendChild(el("div", "demo-note", "демо «" + m.getAttribute("data-demo") + "» пока нет")); },

        // мини-доска: клик заполняет клетку; полный ряд/столбец вспыхивает и гаснет
        board: function (m) {
            var N = 5;
            var wrap = el("div", "demo demo-board");
            wrap.appendChild(el("div", "demo-h", "🧩 Собери линию — и она погаснет"));
            var grid = el("div", "board-grid");
            grid.style.gridTemplateColumns = "repeat(" + N + ", 1fr)";
            var cells = [];
            for (var i = 0; i < N * N; i++) {
                var c = el("button", "bc"); c.type = "button";
                (function (idx, cel) {
                    cel.addEventListener("click", function () {
                        cel.classList.toggle("on");
                        cells[idx].on = cel.classList.contains("on");
                        checkClears();
                    });
                })(i, c);
                cells.push({el: c, on: false});
                grid.appendChild(c);
            }
            function checkClears() {
                var toClear = {};
                for (var r = 0; r < N; r++) {
                    var full = true; for (var k = 0; k < N; k++) if (!cells[r * N + k].on) { full = false; break; }
                    if (full) for (var k2 = 0; k2 < N; k2++) toClear[r * N + k2] = 1;
                }
                for (var col = 0; col < N; col++) {
                    var f2 = true; for (var k3 = 0; k3 < N; k3++) if (!cells[k3 * N + col].on) { f2 = false; break; }
                    if (f2) for (var k4 = 0; k4 < N; k4++) toClear[k4 * N + col] = 1;
                }
                var keys = Object.keys(toClear);
                if (!keys.length) return;
                keys.forEach(function (idx) { cells[idx].el.classList.add("flash"); });
                setTimeout(function () {
                    keys.forEach(function (idx) {
                        cells[idx].el.classList.remove("flash", "on"); cells[idx].on = false;
                    });
                }, 420);
            }
            wrap.appendChild(grid);
            wrap.appendChild(el("div", "demo-note", "Нажимай клетки. Заполни целый ряд или столбец — как в настоящей игре, он вспыхнет и очистится."));
            m.appendChild(wrap);
        },

        // формула очков: N (длина линии) → база N(N+1)/2, множитель комбо
        score: function (m) {
            var wrap = el("div", "demo demo-score");
            wrap.appendChild(el("div", "demo-h", "🎯 Из чего складываются очки"));
            var row = el("div", "demo-row");
            row.innerHTML = 'Линий сразу: <b><span id="_sN">1</span></b>' +
                ' <input type="range" id="_rN" min="1" max="6" value="1"> &nbsp; ' +
                'Комбо: <b><span id="_sC">0</span></b> <input type="range" id="_rC" min="0" max="5" value="0">';
            var out = el("div", "demo-out", "");
            wrap.appendChild(row); wrap.appendChild(out);
            function calc() {
                var n = +row.querySelector("#_rN").value, c = +row.querySelector("#_rC").value;
                row.querySelector("#_sN").textContent = n;
                row.querySelector("#_sC").textContent = c;
                var base = n * (n + 1) / 2 * 10;           // база = N(N+1)/2, ×10 за линию
                var mult = 1 + 0.1 * Math.min(c, 8);
                var total = Math.round(base * mult);
                out.innerHTML = "база = " + n + "·(" + n + "+1)/2 ×10 = <b>" + base + "</b>" +
                    " · множитель = 1+0.1·" + c + " = <b>" + mult.toFixed(1) + "</b>" +
                    " → <b class=\"big\">" + total + "</b> очков";
            }
            row.querySelector("#_rN").addEventListener("input", calc);
            row.querySelector("#_rC").addEventListener("input", calc);
            calc();
            m.appendChild(wrap);
        },

        // ELO: два рейтинга → ожидание E и изменение ΔR
        elo: function (m) {
            var wrap = el("div", "demo demo-elo");
            wrap.appendChild(el("div", "demo-h", "📈 Как считается рейтинг ELO"));
            var row = el("div", "demo-row");
            row.innerHTML = 'Твой: <b><span id="_eA">1000</span></b> <input type="range" id="_ra" min="600" max="2000" step="20" value="1000"><br>' +
                'Соперник: <b><span id="_eB">1000</span></b> <input type="range" id="_rb" min="600" max="2000" step="20" value="1000">';
            var out = el("div", "demo-out", "");
            wrap.appendChild(row); wrap.appendChild(out);
            function calc() {
                var Ra = +row.querySelector("#_ra").value, Rb = +row.querySelector("#_rb").value, K = 24;
                row.querySelector("#_eA").textContent = Ra;
                row.querySelector("#_eB").textContent = Rb;
                var E = 1 / (1 + Math.pow(10, (Rb - Ra) / 400));
                var win = Math.round(K * (1 - E)), lose = Math.round(K * (0 - E));
                out.innerHTML = "Ожидание победы E = <b>" + (E * 100).toFixed(0) + "%</b><br>" +
                    "Выиграешь → <b class=\"up\">+" + win + "</b> · проиграешь → <b class=\"down\">" + lose + "</b>" +
                    "<div class=\"demo-note\">Обыграть сильного — большая прибавка (сюрприз), сильному за победу над слабым дают чуть-чуть.</div>";
            }
            row.querySelector("#_ra").addEventListener("input", calc);
            row.querySelector("#_rb").addEventListener("input", calc);
            calc();
            m.appendChild(wrap);
        },

        // PRNG mulberry32: зерно → одинаковая цепочка «случайных» чисел
        prng: function (m) {
            var wrap = el("div", "demo demo-prng");
            wrap.appendChild(el("div", "demo-h", "🎲 Честная случайность: зерно → цепочка"));
            var row = el("div", "demo-row");
            row.innerHTML = 'Зерно (seed): <input type="number" id="_seed" value="42" style="width:6em"> ' +
                '<button type="button" id="_grow">Вырастить 6 чисел</button>';
            var out = el("div", "demo-out", "");
            wrap.appendChild(row); wrap.appendChild(out);
            function mulberry32(a) {
                return function () {
                    a |= 0; a = (a + 0x6D2B79F5) | 0;
                    var t = Math.imul(a ^ (a >>> 15), 1 | a);
                    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
                    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
                };
            }
            function grow() {
                var seed = parseInt(row.querySelector("#_seed").value, 10) || 0;
                var rng = mulberry32(seed), nums = [];
                for (var i = 0; i < 6; i++) nums.push(rng().toFixed(3));
                out.innerHTML = "seed <b>" + seed + "</b> → " + nums.map(function (x) { return "<span class=\"num\">" + x + "</span>"; }).join(" ") +
                    "<div class=\"demo-note\">Одно и то же зерно ВСЕГДА даёт ту же цепочку — попробуй нажать дважды. Смени зерно — цепочка другая.</div>";
            }
            row.querySelector("#_grow").addEventListener("click", grow);
            grow();
            m.appendChild(wrap);
        }
    };

    // ── прогресс-HUD в тулбаре ──────────────────────────────────────────────
    var hud;
    function buildHud() {
        var bar = document.querySelector(".reader-ui");
        if (!bar || document.getElementById("bkProgress")) return;

        var nav = el("div", "bk-nav");
        // «к дню N»
        nav.innerHTML =
            '<span class="bk-goto"><label for="bkGoto">День</label>' +
            '<input id="bkGoto" type="number" min="1" max="200" inputmode="numeric" placeholder="№"></span>' +
            '<button class="btn ico" id="bkSearch" type="button" title="Поиск по книге" aria-label="Поиск">🔎</button>' +
            '<button class="bk-prog" id="bkProgress" type="button" title="Твой прогресс">' +
            '<span class="bk-bar"><i id="bkFill"></i></span><span id="bkNum">0/200</span></button>';
        // вставить перед пейджером
        var pager = bar.querySelector(".pager");
        bar.insertBefore(nav, pager);

        var goto = nav.querySelector("#bkGoto");
        goto.addEventListener("keydown", function (e) {
            e.stopPropagation();   // не давать читалке листать во время набора
            if (e.key === "Enter") { var n = parseInt(goto.value, 10); if (n >= 1 && n <= 200) jumpToDay(n); }
        });
        nav.querySelector("#bkSearch").addEventListener("click", openSearch);
        nav.querySelector("#bkProgress").addEventListener("click", openProgress);
        hud = nav;
        updateHud();
    }
    function updateHud() {
        if (!hud) return;
        var n = doneCount();
        var fill = hud.querySelector("#bkFill"), num = hud.querySelector("#bkNum");
        if (fill) fill.style.width = (n / TOTAL * 100).toFixed(1) + "%";
        if (num) num.textContent = n + "/200";
    }

    // ── панель прогресса (продолжить, серия) ────────────────────────────────
    function overlay(title, bodyBuilder) {
        closeTip();
        var back = el("div", "bk-overlay");
        var panel = el("div", "bk-panel");
        panel.appendChild(el("div", "bk-panel-h", title + '<button class="bk-x" type="button" aria-label="Закрыть">✕</button>'));
        var body = el("div", "bk-panel-body");
        panel.appendChild(body);
        back.appendChild(panel);
        document.body.appendChild(back);
        function close() { back.remove(); }
        back.addEventListener("click", function (e) { if (e.target === back) close(); });
        panel.querySelector(".bk-x").addEventListener("click", close);
        bodyBuilder(body, close);
        return {close: close, body: body};
    }

    function openProgress() {
        overlay("📊 Твой путь", function (body, close) {
            var n = doneCount();
            body.appendChild(el("div", "bk-stat",
                '<b class="big">' + n + '</b> / 200 дней пройдено · серия подряд: <b>' + streak() + '</b>'));
            var barWrap = el("div", "bk-bigbar", '<i style="width:' + (n / TOTAL * 100).toFixed(1) + '%"></i>');
            body.appendChild(barWrap);
            var row = el("div", "bk-actions");
            var cont = el("button", "btn primary", state.last ? "▶ Продолжить с дня " + state.last : "Начать с дня 1");
            cont.type = "button";
            cont.addEventListener("click", function () { close(); jumpToDay(state.last || 1); });
            row.appendChild(cont);
            var reset = el("button", "btn", "Сбросить прогресс");
            reset.type = "button";
            reset.addEventListener("click", function () {
                if (!confirm("Сбросить все галочки прогресса?")) return;
                state = {done: {}, steps: {}, last: 0}; save(state);
                document.querySelectorAll(".day-page").forEach(function (a) {
                    a.dataset.enhanced = ""; a.querySelectorAll(".day-done,.step-check").forEach(function (x) { x.remove(); });
                    a.querySelectorAll(".task ol > li").forEach(function (li) { li.classList.remove("step-done"); });
                });
                document.querySelectorAll(".day-page").forEach(enhanceDay);
                updateHud(); close();
            });
            row.appendChild(reset);
            body.appendChild(row);
            // мини-карта недель (29 недель × прогресс)
            var mapWrap = el("div", "bk-weekmap", "");
            for (var w = 0; w < 29; w++) {
                var from = w * 7 + 1, to = Math.min(200, from + 6), dn = 0, tot = to - from + 1;
                for (var d = from; d <= to; d++) if (state.done[d]) dn++;
                var cell = el("button", "wk" + (dn === tot ? " full" : dn ? " part" : ""), (w + 1));
                cell.type = "button"; cell.title = "Неделя " + (w + 1) + ": " + dn + "/" + tot;
                (function (f) { cell.addEventListener("click", function () { close(); jumpToDay(f); }); })(from);
                mapWrap.appendChild(cell);
            }
            body.appendChild(el("div", "bk-sub", "Недели (клик — прыжок):"));
            body.appendChild(mapWrap);
        });
    }

    // ── поиск по книге ──────────────────────────────────────────────────────
    function openSearch() {
        overlay("🔎 Поиск по книге", function (body) {
            body.appendChild(el("div", "bk-sub", "Ищем по темам и тексту всех 200 дней:"));
            var inp = el("input", "bk-search-input"); inp.type = "search"; inp.placeholder = "например: случайность, сервер, класс…";
            body.appendChild(inp);
            var res = el("div", "bk-results", "");
            body.appendChild(res);
            var articles = Array.prototype.slice.call(document.querySelectorAll(".day-page"));
            var index = articles.map(function (a) {
                return {n: dayNumOf(a), t: (a.textContent || "").toLowerCase(),
                        title: (a.querySelector("h3") ? a.querySelector("h3").textContent : "")};
            }).filter(function (x) { return x.n; });
            function run() {
                var q = inp.value.trim().toLowerCase();
                res.innerHTML = "";
                if (q.length < 2) return;
                var hits = index.filter(function (x) { return x.t.indexOf(q) >= 0; }).slice(0, 40);
                if (!hits.length) { res.appendChild(el("div", "bk-sub", "Ничего не нашлось.")); return; }
                hits.forEach(function (h) {
                    var pos = h.t.indexOf(q), from = Math.max(0, pos - 24);
                    var snip = (from > 0 ? "…" : "") + h.t.slice(from, pos + q.length + 34) + "…";
                    var item = el("button", "bk-hit", '<b>День ' + h.n + '</b> · ' + h.title + '<span class="snip">' + snip + '</span>');
                    item.type = "button";
                    item.addEventListener("click", function () {
                        document.querySelector(".bk-overlay").remove(); jumpToDay(h.n);
                    });
                    res.appendChild(item);
                });
            }
            inp.addEventListener("input", run);
            inp.addEventListener("keydown", function (e) { e.stopPropagation(); });
            setTimeout(function () { inp.focus(); }, 30);
        });
    }

    // ── общий проход по DOM ────────────────────────────────────────────────
    function enhanceAll() {
        buildHud();
        document.querySelectorAll(".day-page").forEach(function (a) {
            enhanceDay(a); enhanceReal(a); enhanceTerms(a);
        });
        document.querySelectorAll(".demo-mount").forEach(buildDemo);
        updateHud();
        relayout();
    }

    // старт: и для инлайновой книги (контент уже в DOM), и для data-driven
    // (render.js кинет событие book:rendered после сборки страниц)
    if (document.querySelector(".day-page")) enhanceAll();
    document.addEventListener("book:rendered", enhanceAll);
})();
