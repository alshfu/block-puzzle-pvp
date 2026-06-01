import { useEffect, useState, type CSSProperties } from "react";
import { DEFAULT_CONFIG, type BotLevel, type RuleConfig } from "../core";
import { ThemeBackdrop } from "./components/ThemeBackdrop";
import { GameScreen } from "./screens/GameScreen";
import { MenuScreen, type GameMode, type Profile } from "./screens/MenuScreen";
import { SetupScreen, type BlitzPreset } from "./screens/SetupScreen";
import { isThemeId, THEMES, THEME_STORAGE_KEY, type ThemeId } from "./themes";

type Screen = "menu" | "setup" | "game";

const DEFAULT_PROFILE: Profile = { nick: "Игрок", avatar: "🙂", level: 3 };

function loadTheme(): ThemeId {
  try {
    const raw = localStorage.getItem(THEME_STORAGE_KEY);
    if (isThemeId(raw)) return raw;
  } catch {
    /* localStorage может быть недоступен */
  }
  return "neutral";
}

export function App() {
  const [theme, setTheme] = useState<ThemeId>(loadTheme);
  const [screen, setScreen] = useState<Screen>("menu");
  const [mode, setMode] = useState<GameMode>("bot");
  const [cfg, setCfg] = useState<RuleConfig>(DEFAULT_CONFIG);
  const [botLevel, setBotLevel] = useState<BotLevel>("medium");
  const [blitz, setBlitz] = useState<BlitzPreset>("norm");

  useEffect(() => {
    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch {
      /* ignore */
    }
  }, [theme]);

  const t = THEMES[theme];
  const rootStyle: CSSProperties = t.vars;

  return (
    <div className="app-root" data-theme={theme} data-kind={t.kind} style={rootStyle}>
      <ThemeBackdrop theme={theme} />
      <div className="phone">
        {screen === "menu" && (
          <MenuScreen
            theme={theme}
            setTheme={setTheme}
            onStart={(m) => {
              setMode(m);
              setScreen("setup");
            }}
            profile={DEFAULT_PROFILE}
          />
        )}
        {screen === "setup" && (
          <SetupScreen
            theme={theme}
            setTheme={setTheme}
            mode={mode}
            cfg={cfg}
            setCfg={setCfg}
            botLevel={botLevel}
            setBotLevel={setBotLevel}
            blitz={blitz}
            setBlitz={setBlitz}
            onBack={() => setScreen("menu")}
            onStart={() => setScreen("game")}
          />
        )}
        {screen === "game" && (
          <GameScreen
            theme={theme}
            setTheme={setTheme}
            mode={mode}
            cfg={cfg}
            botLevel={botLevel}
            blitz={blitz}
            onExit={() => setScreen("menu")}
          />
        )}
      </div>
    </div>
  );
}
