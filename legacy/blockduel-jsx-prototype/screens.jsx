// ============================================================
// Экраны: меню, настройка матча, результат + переключатель тем.
// ============================================================

function Logo({ size = "big" }) {
  return (
    <div className={"logo " + size}>
      <span className="logo-block">BLOCK</span>
      <span className="logo-dot">·</span>
      <span className="logo-duel">DUEL</span>
      <span className="logo-9">9×9</span>
    </div>
  );
}

// Переключатель тем — карусель свотчей
function ThemeSwitch({ theme, setTheme, compact }) {
  return (
    <div className={"theme-switch " + (compact ? "compact" : "")}>
      {!compact && <div className="ts-cap">тема оформления</div>}
      <div className="ts-row">
        {THEME_ORDER.map(id => {
          const t = THEMES[id];
          const on = id === theme;
          return (
            <button key={id} className={"ts-chip " + (on ? "on" : "")}
              onClick={() => setTheme(id)}
              data-swatch={id}>
              <span className="ts-swatch" style={{
                background: `linear-gradient(135deg, ${t.vars["--p0"]} 0 50%, ${t.vars["--p1"]} 50% 100%)`,
                ...(id === "candy" ? {} : {}),
              }} />
              {!compact && <span className="ts-name">{t.label}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Парящая кнопка-переключатель тем (на всех экранах)
function FloatingTheme({ theme, setTheme }) {
  const idx = THEME_ORDER.indexOf(theme);
  const next = THEME_ORDER[(idx + 1) % THEME_ORDER.length];
  const t = THEMES[next];
  return (
    <button className="floating-theme" onClick={() => setTheme(next)} title={"Тема: " + THEMES[theme].label}>
      <span className="ft-swatch" style={{
        background: `linear-gradient(135deg, ${t.vars["--p0"]} 0 50%, ${t.vars["--p1"]} 50% 100%)`,
      }} />
      <span className="ft-lbl">{THEMES[theme].label}</span>
    </button>
  );
}

function MenuScreen({ theme, setTheme, onStart, profile }) {
  const [modeOpen, setModeOpen] = React.useState(false);
  return (
    <div className="screen menu-screen">
      <div className="menu-top">
        <button className="avatar-chip">
          <span className="avatar-face">{profile.avatar}</span>
          <span className="avatar-meta">
            <span className="avatar-nick">{profile.nick}</span>
            <span className="avatar-lvl">ур. {profile.level}</span>
          </span>
        </button>
        <span className="mode-badge">demo · ts core</span>
      </div>

      <div className="menu-hero">
        <Logo size="big" />
        <div className="menu-tagline">дуэль на поле 9×9 · ставь, очищай, побеждай</div>
        <MiniDeco />
      </div>

      <div className="menu-actions">
        {!modeOpen ? (
          <Button kind="primary" className="hero-btn" onClick={() => setModeOpen(true)}>
            ▶ Играть
          </Button>
        ) : (
          <div className="mode-list">
            <Button kind="primary" className="mode-btn" onClick={() => onStart("bot")}>
              <span className="mode-ico">🤖</span>
              <span className="mode-txt"><b>С ботом</b><i>быстрая партия против ИИ</i></span>
            </Button>
            <Button kind="ghost" className="mode-btn" owner={1} onClick={() => onStart("hotseat")}>
              <span className="mode-ico">👥</span>
              <span className="mode-txt"><b>Вдвоём</b><i>hot-seat на одном устройстве</i></span>
            </Button>
            <button className="mode-btn ghost-mode disabled" disabled>
              <span className="mode-ico">🌐</span>
              <span className="mode-txt"><b>Онлайн</b><i>скоро</i></span>
            </button>
            <button className="back-link" onClick={() => setModeOpen(false)}>← назад</button>
          </div>
        )}
        {!modeOpen && (
          <div className="menu-secondary">
            <button className="sec-btn">Профиль</button>
            <button className="sec-btn">Ачивки</button>
            <button className="sec-btn">Настройки</button>
          </div>
        )}
      </div>

      <div className="menu-foot">
        <ThemeSwitch theme={theme} setTheme={setTheme} />
        <div className="version">v1.0 · prototype</div>
      </div>
    </div>
  );
}

// мини-анимация из фигур под логотипом
function MiniDeco() {
  const demo = ["T", "L", "S", "O", "I"];
  return (
    <div className="mini-deco">
      {demo.map((t, i) => (
        <MiniPiece key={i} cells={PIECES[t]} owner={i % 2} cellSize={11} />
      ))}
    </div>
  );
}

function Segment({ options, value, onChange }) {
  return (
    <div className="segment">
      {options.map(o => (
        <button key={o.v} className={"seg-item " + (value === o.v ? "on" : "")}
          onClick={() => onChange(o.v)}>
          <b>{o.label}</b>
          {o.sub && <i>{o.sub}</i>}
        </button>
      ))}
    </div>
  );
}

function Toggle({ label, checked, onChange }) {
  return (
    <button className={"toggle " + (checked ? "on" : "")} onClick={() => onChange(!checked)}>
      <span className="tg-track"><span className="tg-knob" /></span>
      <span className="tg-label">{label}</span>
    </button>
  );
}

function SetupScreen({ theme, setTheme, mode, cfg, setCfg, botLevel, setBotLevel, blitz, setBlitz, onBack, onStart }) {
  const upd = (k, v) => setCfg({ ...cfg, [k]: v });
  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>←</button>
        <div className="setup-title">Настройка матча</div>
        <span className="mode-badge">{mode === "bot" ? "vs bot" : "hot-seat"}</span>
      </div>

      <div className="setup-body">
        {mode === "bot" && (
          <section className="setup-sec">
            <div className="sec-cap">Соперник</div>
            <Segment value={botLevel} onChange={setBotLevel} options={[
              { v: "easy", label: "Тупой", sub: "новичок" },
              { v: "medium", label: "Умный", sub: "по умолч." },
              { v: "hard", label: "Сложный", sub: "вызов" },
            ]} />
          </section>
        )}

        <section className="setup-sec">
          <div className="sec-cap">Правила</div>
          <div className="toggle-row">
            <Toggle label="Повороты" checked={cfg.rotationEnabled} onChange={v => upd("rotationEnabled", v)} />
            <Toggle label="Отражения" checked={cfg.flipEnabled} onChange={v => upd("flipEnabled", v)} />
          </div>
          <div className="sub-cap">Размер руки</div>
          <Segment value={cfg.handSize} onChange={v => upd("handSize", v)} options={[
            { v: 2, label: "2" }, { v: 3, label: "3" }, { v: 4, label: "4" },
          ]} />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Блиц · время на ход</div>
          <Segment value={blitz} onChange={setBlitz} options={[
            { v: "hard", label: "Хардкор", sub: "8 → 2с" },
            { v: "norm", label: "Норма", sub: "12 → 3с" },
            { v: "casual", label: "Казуал", sub: "20 → 6с" },
          ]} />
        </section>
      </div>

      <div className="setup-foot">
        <ThemeSwitch theme={theme} setTheme={setTheme} compact />
        <Button kind="primary" className="start-btn" onClick={onStart}>Начать →</Button>
      </div>
    </div>
  );
}

function ResultOverlay({ result, names, onRematch, onMenu, xp }) {
  if (!result) return null;
  const { winner, scores } = result;
  let title, cls, emo;
  if (winner === 0) { title = "Победа"; cls = "win owner0"; emo = "🏆"; }
  else if (winner === 1) { title = names[1] + " победил"; cls = "lose owner1"; emo = "🤖"; }
  else { title = "Ничья"; cls = "draw"; emo = "🤝"; }
  return (
    <div className="overlay">
      <div className={"result-card " + cls}>
        <div className="result-emo">{emo}</div>
        <div className="result-title">{title}</div>
        <div className="result-sub">ходы кончились</div>
        <div className="result-scores">
          <div className="rs owner0"><span>{names[0]}</span><b>{scores[0]}</b></div>
          <div className="rs-vs">:</div>
          <div className="rs owner1"><span>{names[1]}</span><b>{scores[1]}</b></div>
        </div>
        <div className="result-xp">
          <span>+{xp} XP</span>
          <div className="xp-bar"><div className="xp-fill" style={{ width: "62%" }} /></div>
        </div>
        <div className="result-actions">
          <Button kind="primary" onClick={onRematch}>Реванш</Button>
          <Button kind="ghost" onClick={onMenu}>В меню</Button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  Logo, ThemeSwitch, FloatingTheme, MenuScreen, MiniDeco,
  Segment, Toggle, SetupScreen, ResultOverlay,
});
