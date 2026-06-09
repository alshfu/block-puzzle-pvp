import { THEME_ORDER, THEMES, type ThemeId } from "../themes";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  compact?: boolean;
}

export function ThemeSwitch({ theme, setTheme, compact }: Props) {
  return (
    <div className={`theme-switch ${compact ? "compact" : ""}`}>
      {!compact && <div className="ts-cap">тема оформления</div>}
      <div className="ts-row">
        {THEME_ORDER.map((id) => {
          const t = THEMES[id];
          const on = id === theme;
          const p0 = (t.vars as Record<string, string>)["--p0"];
          const p1 = (t.vars as Record<string, string>)["--p1"];
          return (
            <button
              key={id}
              className={`ts-chip ${on ? "on" : ""}`}
              onClick={() => setTheme(id)}
              data-swatch={id}
            >
              <span
                className="ts-swatch"
                style={{ background: `linear-gradient(135deg, ${p0} 0 50%, ${p1} 50% 100%)` }}
              />
              {!compact && <span className="ts-name">{t.label}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
