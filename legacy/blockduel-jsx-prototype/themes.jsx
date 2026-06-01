// ============================================================
// Три темы оформления BlockDuel.
// Все оригинальные — навеяны вайбом, без копирования брендов.
//  • neutral — тёмная база из техдоки (янтарь / циан)
//  • candy   — «Магия & Карамель» (пастель, блёстки, сердечки)
//  • night   — «Ночной Страж» (неон-нуар, готика, прожектор)
// ============================================================

const THEMES = {
  neutral: {
    id: "neutral",
    label: "Нейтральная",
    sub: "тёмная база · янтарь / циан",
    kind: "dark",
    p0name: "Ты", p1name: "Бот",
    vars: {
      "--bg": "#0e1116", "--bg2": "#0b0e13",
      "--panel": "#161b22", "--panel2": "#1c232d", "--line": "#2a323d",
      "--ink": "#e7edf3", "--muted": "#8b97a6",
      "--p0": "#ff9d42", "--p0d": "#b3661f",
      "--p1": "#36d6e7", "--p1d": "#1c8794",
      "--good": "#37d67a", "--bad": "#ef5e6b",
      "--cell": "#10151c", "--cellline": "#222c37",
      "--board-r": "18px", "--card-r": "14px", "--btn-r": "10px", "--cell-r": "5px", "--mini-r": "4px",
      "--font-display": "'Bricolage Grotesque', sans-serif",
      "--font-mono": "'DM Mono', monospace",
      "--display-weight": "800", "--display-spacing": "-0.01em",
    },
  },
  candy: {
    id: "candy",
    label: "Магия & Карамель",
    sub: "для самых волшебных · пастель, блёстки",
    kind: "light",
    p0name: "Ты", p1name: "Пони-бот",
    vars: {
      "--bg": "#ffeaf6", "--bg2": "#f4e6ff",
      "--panel": "rgba(255,255,255,0.80)", "--panel2": "#ffe1f1", "--line": "#ffc7e6",
      "--ink": "#6b3b78", "--muted": "#b07fc4",
      "--p0": "#ff77b3", "--p0d": "#ff3d92",
      "--p1": "#3fd5d0", "--p1d": "#16b3ac",
      "--good": "#5fd38a", "--bad": "#ff6b8a",
      "--cell": "#fff6fb", "--cellline": "#ffd9ec",
      "--board-r": "26px", "--card-r": "22px", "--btn-r": "18px", "--cell-r": "9px", "--mini-r": "6px",
      "--font-display": "'Fredoka', sans-serif",
      "--font-mono": "'Baloo 2', cursive",
      "--display-weight": "600", "--display-spacing": "0em",
    },
  },
  night: {
    id: "night",
    label: "Ночной Страж",
    sub: "для отважных · неон-нуар, готика",
    kind: "dark",
    p0name: "Ты", p1name: "Тень",
    vars: {
      "--bg": "#070a12", "--bg2": "#04060b",
      "--panel": "#0e1422", "--panel2": "#141c2e", "--line": "#243049",
      "--ink": "#eaf0ff", "--muted": "#6f80a3",
      "--p0": "#ffd23f", "--p0d": "#c79410",
      "--p1": "#3aa6ff", "--p1d": "#1c6fd0",
      "--good": "#39e88a", "--bad": "#ff3b5c",
      "--cell": "#0b1120", "--cellline": "#1c2840",
      "--board-r": "6px", "--card-r": "6px", "--btn-r": "4px", "--cell-r": "2px", "--mini-r": "2px",
      "--font-display": "'Oswald', sans-serif",
      "--font-mono": "'Share Tech Mono', monospace",
      "--display-weight": "700", "--display-spacing": "0.02em",
    },
  },
};
const THEME_ORDER = ["neutral", "candy", "night"];

// ------------------------------------------------------------
// Декоративный фон под текущую тему.
// ------------------------------------------------------------
function ThemeBackdrop({ theme }) {
  if (theme === "candy") return <CandyBackdrop />;
  if (theme === "night") return <NightBackdrop />;
  return <NeutralBackdrop />;
}

function NeutralBackdrop() {
  return (
    <div className="backdrop" style={{
      background:
        "radial-gradient(120% 80% at 85% -10%, rgba(255,157,66,0.10), transparent 55%)," +
        "radial-gradient(120% 80% at 15% 110%, rgba(54,214,231,0.10), transparent 55%)," +
        "linear-gradient(180deg,#0e1116,#0b0e13)",
    }} />
  );
}

function CandyBackdrop() {
  // плавающие сердечки / звёздочки / блёстки
  const bits = React.useMemo(() => {
    const kinds = ["heart", "star", "spark", "spark", "star"];
    const arr = [];
    const rng = makeRng(7);
    for (let i = 0; i < 16; i++) {
      arr.push({
        kind: kinds[i % kinds.length],
        left: (rng() * 100).toFixed(2) + "%",
        size: 10 + rng() * 22,
        dur: 9 + rng() * 10,
        delay: -rng() * 18,
        hue: ["#ff9ecb", "#ffd166", "#b89cff", "#7fe7df", "#ff77b3"][Math.floor(rng() * 5)],
        drift: (rng() * 40 - 20).toFixed(0) + "px",
      });
    }
    return arr;
  }, []);
  return (
    <div className="backdrop candy-bd" style={{
      background:
        "radial-gradient(130% 90% at 50% -20%, #fff6fb 0%, #ffe4f4 30%, #f6dcff 60%, #e7e6ff 100%)",
    }}>
      {/* мягкая радуга-дуга вверху */}
      <div className="candy-rainbow" />
      {/* облачка */}
      <div className="candy-cloud" style={{ top: "12%", left: "-6%", transform: "scale(1.1)" }} />
      <div className="candy-cloud" style={{ top: "30%", right: "-8%", left: "auto" }} />
      <div className="candy-cloud" style={{ bottom: "10%", left: "8%" }} />
      {bits.map((b, i) => (
        <span key={i} className={"candy-bit " + b.kind} style={{
          left: b.left, width: b.size, height: b.size, color: b.hue,
          animationDuration: b.dur + "s", animationDelay: b.delay + "s",
          "--drift": b.drift,
        }} />
      ))}
    </div>
  );
}

function NightBackdrop() {
  // тёмное небо, прожектор-сигнал, силуэт города
  return (
    <div className="backdrop night-bd" style={{
      background:
        "radial-gradient(120% 70% at 50% 0%, #14213f 0%, #0a0f1f 45%, #05070d 100%)",
    }}>
      {/* звёзды */}
      <div className="night-stars" />
      {/* прожектор-луч */}
      <div className="night-beam" />
      {/* эмблема в луче — абстрактный ромб со звездой (оригинальная) */}
      <svg className="night-emblem" viewBox="0 0 100 100" width="120" height="120">
        <polygon points="50,6 94,50 50,94 6,50" fill="none" stroke="currentColor" strokeWidth="5" />
        <polygon points="50,26 60,44 80,44 64,57 70,77 50,65 30,77 36,57 20,44 40,44" fill="currentColor" />
      </svg>
      {/* силуэт города */}
      <div className="night-skyline">
        {Array.from({ length: 22 }).map((_, i) => {
          const rng = makeRng(100 + i);
          const w = 22 + Math.floor(rng() * 26);
          const h = 30 + Math.floor(rng() * 130);
          return <span key={i} style={{ width: w, height: h }} />;
        })}
      </div>
      {/* неоновая сетка-горизонт */}
      <div className="night-grid" />
    </div>
  );
}

Object.assign(window, { THEMES, THEME_ORDER, ThemeBackdrop });
