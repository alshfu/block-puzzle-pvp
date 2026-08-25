(function () {
    var intro = document.getElementById("intro");
    if (!intro) return;
    var book = document.getElementById("ourbook");
    var skip = document.getElementById("introSkip");
    var snow = document.getElementById("snow");
    var done = false;

    // насыпаем снежинки в окно
    if (snow) {
        for (var i = 0; i < 16; i++) {
            var f = document.createElement("i");
            var s = 3 + Math.round(Math.random() * 4);
            f.style.width = s + "px"; f.style.height = s + "px";
            f.style.left = Math.round(Math.random() * 100) + "%";
            f.style.animationDuration = (5 + Math.random() * 6).toFixed(1) + "s";
            f.style.animationDelay = (-Math.random() * 8).toFixed(1) + "s";
            snow.appendChild(f);
        }
    }

    function reveal() {
        if (done) return; done = true;
        intro.classList.add("gone");
        try { if (window.__reader) window.__reader.layout(); } catch (e) {}
        setTimeout(function () { if (intro && intro.parentNode) intro.parentNode.removeChild(intro); }, 620);
    }

    function launch() {
        if (done) return;
        var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        if (reduce) { reveal(); return; }
        // центр книги → смещение до центра экрана
        var r = book.getBoundingClientRect();
        var dx = Math.round(window.innerWidth / 2 - (r.left + r.width / 2));
        var dy = Math.round(window.innerHeight / 2 - (r.top + r.height / 2));
        book.style.setProperty("--dx", dx + "px");
        book.style.setProperty("--dy", dy + "px");
        intro.classList.add("launched");        // прячем текст
        book.classList.add("flying");           // фаза 1: вылет в центр
        setTimeout(function () { book.classList.add("opening"); }, 720);  // фаза 2: раскрытие + рост
        setTimeout(reveal, 720 + 720);          // фаза 3: показать книгу
    }

    book.addEventListener("click", launch);
    skip.addEventListener("click", reveal);
    // клики по сцене не должны листать читалку, спрятанную под заставкой
    intro.addEventListener("click", function (e) { e.stopPropagation(); });
    document.addEventListener("keydown", function (e) {
        if (done) return;
        if (e.key === "Escape") reveal();
        else if (e.key === "Enter" || e.key === " ") {
            if (document.activeElement === book) { e.preventDefault(); launch(); }
        }
    });
})();
