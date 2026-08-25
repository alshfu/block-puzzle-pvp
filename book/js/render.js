// render.js — data-driven сборка книги из content/book.json + content/spreads/*.json.
//
// Идея: HTML-оболочка (app.html) почти пустая. Весь контент — это ДАННЫЕ:
//   • content/book.json      — манифест: flow (порядок страниц) + список разворотов;
//   • content/spreads/NNN.json — по 2 дня в файле («каждые две страницы — файл»).
// Здесь мы грузим манифест, параллельно тянем все развороты, из структурных полей
// собираем HTML дней (шаблон 1:1 с исходной вёрсткой), склеиваем с дословным
// «хромом» (главы, обложки, план, промпты, футер) и одной вставкой кладём как
// innerHTML в .wrap. Так CSS-колонки книги-разворота флоучат контент как раньше,
// а reader.js (листание/пагинация) продолжает работать без изменений.
//
// Картинки всегда по URL (assets/img/…), никогда в base64 — файл-оболочка лёгкий.
(function () {
    "use strict";

    var BASE = "content/";
    var wrap = document.querySelector(".wrap");
    if (!wrap) return;

    function esc() { /* контент доверенный (наш генератор) — html вставляется как есть */ }

    // --- шаблоны дня (1:1 с исходной вёрсткой index.html) ---
    function renderProse(prose) {
        if (!prose || !prose.length) return "";
        var out = '<div class="prose">';
        for (var i = 0; i < prose.length; i++) {
            var p = prose[i];
            out += p.cls ? '<p class="' + p.cls + '">' + p.html + "</p>"
                         : "<p>" + p.html + "</p>";
        }
        return out + "</div>";
    }

    function renderReal(r) {
        if (!r) return "";
        return '<div class="real-word"><div class="h">'
            + (r.title || "🔬 Настоящее слово") + "</div>" + (r.html || "") + "</div>";
    }

    function renderDemo(demo) {
        if (!demo) return "";
        var t = typeof demo === "string" ? demo : demo.type;
        var args = (typeof demo === "object" && demo.args)
            ? " data-demo-args='" + JSON.stringify(demo.args).replace(/'/g, "&#39;") + "'" : "";
        return '<div class="demo-mount" data-demo="' + t + '"' + args + "></div>";
    }

    function renderTask(task) {
        if (!task) return "";
        var out = '<div class="task"><div class="h">' + (task.title || "") + "</div>";
        if (task.steps && task.steps.length) {
            out += "<ol>";
            for (var i = 0; i < task.steps.length; i++) out += "<li>" + task.steps[i] + "</li>";
            out += "</ol>";
        }
        if (task.together) out += '<p class="together">' + task.together + "</p>";
        return out + "</div>";
    }

    function renderHead(day) {
        // вариант B (недели 7–29): бейдж-спрайт + заголовок в day-head
        if (day.badge) {
            return '<div class="day-head"><div class="day-badge" title="'
                + (day.seen || "") + '"><svg><use href="#' + day.badge
                + '"/></svg></div><h3>' + (day.title || "") + "</h3></div>";
        }
        // вариант A (недели 1–6): отдельный h3 + фото-сцена
        var out = "<h3>" + (day.title || "") + "</h3>";
        if (day.image) {
            out += '<div class="scene"><div class="scene-frame"><img src="'
                + day.image.src + '" alt="' + (day.image.alt || "") + '">';
            if (day.topic) {
                out += '<div class="scene-topic"><small>Тема дня</small>' + day.topic + "</div>";
            }
            out += "</div></div>";
        }
        return out;
    }

    function renderDay(day) {
        var kicker = "День " + day.day + " · из " + (day.of || 200)
            + (day.theme ? " · тема: " + day.theme : "");
        var html = '<article class="day-page" id="d' + pad3(day.day) + '">'
            + '<div class="day-kicker">' + kicker + "</div>"
            + renderHead(day)
            + renderProse(day.prose)
            + renderReal(day.real)
            + renderDemo(day.demo)
            + renderTask(day.task);
        if (day.next) {
            html += '<div class="day-next"><a href="#d' + pad3(day.next)
                + '">День ' + day.next + " →</a></div>";
        }
        return html + "</article>";
    }

    function pad3(n) { return ("00" + n).slice(-3); }

    function fail(msg, e) {
        console.error("[render] " + msg, e || "");
        wrap.insertAdjacentHTML("afterbegin",
            '<p style="padding:20px;color:#b00;font:16px system-ui">'
            + "Не удалось собрать книгу из данных: " + msg
            + ". Открой страницу через веб-сервер (fetch по file:// заблокирован браузером)."
            + "</p>");
    }

    function getJSON(url) {
        return fetch(url, {cache: "force-cache"}).then(function (r) {
            if (!r.ok) throw new Error(url + " → HTTP " + r.status);
            return r.json();
        });
    }

    getJSON(BASE + "book.json").then(function (book) {
        // собрать словарь дней из всех разворотов (параллельно)
        var files = book.spreads.map(function (s) { return BASE + s.file; });
        return Promise.all(files.map(getJSON)).then(function (spreads) {
            var days = {};
            spreads.forEach(function (sp) {
                sp.days.forEach(function (d) { days[d.day] = d; });
            });
            // склеить flow: дословный хром + отрендеренные дни
            var parts = [];
            book.flow.forEach(function (node) {
                if (node.chrome != null) parts.push(node.chrome);
                else if (node.day != null && days[node.day]) parts.push(renderDay(days[node.day]));
            });
            var probe = wrap.querySelector(".end-probe");
            wrap.insertAdjacentHTML("afterbegin", parts.join(""));
            // маркер конца (reader.js считает по нему число страниц) — держим последним
            if (probe) wrap.appendChild(probe);
            // пересчитать пагинацию/перерисовать разворот
            if (window.__reader && window.__reader.layout) window.__reader.layout();
            // если целились в якорь (#dNNN) — прыгнуть к нему
            if (location.hash && window.__reader && window.__reader.jump) {
                var t = document.getElementById(location.hash.slice(1));
                if (t) window.__reader.jump(t);
            }
            document.dispatchEvent(new Event("book:rendered"));
        });
    }).catch(function (e) { fail(e.message, e); });
})();
