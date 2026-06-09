import { THEME_ORDER, THEMES, type ThemeId } from "../themes";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
}

export function FloatingTheme({ theme, setTheme }: Props) {
  const idx = THEME_ORDER.indexOf(theme);
  const next = THEME_ORDER[(idx + 1) % THEME_ORDER.length];
  const t = THEMES[next];
  const p0 = (t.vars as Record<string, string>)["--p0"];
  const p1 = (t.vars as Record<string, string>)["--p1"];
  return (
    <button
      className="floating-theme"
      onClick={() => setTheme(next)}
      title={"Тема: " + THEMES[theme].label}
    >
      <span
        className="ft-swatch"
        style={{ background: `linear-gradient(135deg, ${p0} 0 50%, ${p1} 50% 100%)` }}
      />
      <span className="ft-lbl">{THEMES[theme].label}</span>
    </button>
  );
}
