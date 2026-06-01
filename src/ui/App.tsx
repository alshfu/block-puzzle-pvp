import { useEffect, useMemo, useState, type CSSProperties } from "react";
import type { BotLevel, RuleConfig } from "../core";
import { ThemeBackdrop } from "./components/ThemeBackdrop";
import { GameScreen } from "./screens/GameScreen";
import { MenuScreen, type GameMode } from "./screens/MenuScreen";
import { ProfileScreen } from "./screens/ProfileScreen";
import { SettingsScreen } from "./screens/SettingsScreen";
import { SetupScreen, type BlitzPreset } from "./screens/SetupScreen";
import {
  DEFAULT_PROFILE,
  levelFromXp,
  loadProfile,
  saveProfile,
  type Profile,
} from "./storage/profile";
import {
  clearSavedGame,
  loadSavedGame,
  type SavedGame,
} from "./storage/saveGame";
import {
  loadSettings,
  saveSettings,
  type AppSettings,
} from "./storage/settings";
import {
  applyMatchToStats,
  DEFAULT_STATS,
  loadStats,
  saveStats,
  type MatchOutcome,
  type Stats,
} from "./storage/stats";
import { isThemeId, THEMES, THEME_STORAGE_KEY, type ThemeId } from "./themes";

type Screen = "menu" | "setup" | "game" | "profile" | "settings";

function loadTheme(): ThemeId {
  try {
    const raw = localStorage.getItem(THEME_STORAGE_KEY);
    if (isThemeId(raw)) return raw;
  } catch {
    /* ignore */
  }
  return "neutral";
}

export function App() {
  const [theme, setTheme] = useState<ThemeId>(loadTheme);
  const [screen, setScreen] = useState<Screen>("menu");
  const [profile, setProfile] = useState<Profile>(loadProfile);
  const [stats, setStats] = useState<Stats>(loadStats);
  const [settings, setSettings] = useState<AppSettings>(loadSettings);

  // Активные настройки матча — берутся из settings.default*, но можно изменить в Setup.
  const [mode, setMode] = useState<GameMode>("bot");
  const [cfg, setCfg] = useState<RuleConfig>(settings.defaultCfg);
  const [botLevel, setBotLevel] = useState<BotLevel>(settings.defaultBotLevel);
  const [blitz, setBlitz] = useState<BlitzPreset>(settings.defaultBlitz);

  const [savedGame, setSavedGame] = useState<SavedGame | null>(loadSavedGame);
  const [restoring, setRestoring] = useState(false);

  useEffect(() => {
    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch {
      /* ignore */
    }
  }, [theme]);

  useEffect(() => {
    saveProfile(profile);
  }, [profile]);

  useEffect(() => {
    saveStats(stats);
  }, [stats]);

  useEffect(() => {
    saveSettings(settings);
  }, [settings]);

  const t = THEMES[theme];
  const rootStyle: CSSProperties = t.vars;

  const menuProfile = useMemo(
    () => ({ nick: profile.nick, avatar: profile.avatar, level: levelFromXp(profile.xp) }),
    [profile],
  );

  const handleStart = (m: GameMode) => {
    // Свежий матч — сбросим возможное предыдущее сохранение.
    clearSavedGame();
    setSavedGame(null);
    setRestoring(false);
    setMode(m);
    setCfg(settings.defaultCfg);
    setBotLevel(settings.defaultBotLevel);
    setBlitz(settings.defaultBlitz);
    setScreen("setup");
  };

  const handleResume = () => {
    if (!savedGame) return;
    setMode(savedGame.mode);
    setCfg(savedGame.cfg);
    setBotLevel(savedGame.botLevel);
    setBlitz(savedGame.blitz);
    setRestoring(true);
    setScreen("game");
  };

  const handleDiscardSave = () => {
    clearSavedGame();
    setSavedGame(null);
  };

  const handleMatchOver = (outcome: MatchOutcome) => {
    setStats((prev) => applyMatchToStats(prev, outcome));
    // XP: победа +50, ничья +25, поражение +10, плюс по 1 за очистку.
    const xpGain =
      (outcome.winner === 0 ? 50 : outcome.winner === -1 ? 25 : 10) +
      outcome.totalClearsThisMatch;
    setProfile((prev) => ({ ...prev, xp: prev.xp + xpGain }));
    // savedGame убирается из storage самим useGame; обновим локальный кэш.
    setSavedGame(null);
  };

  const handleExitGame = () => {
    // выход из игры не очищает save — пользователь сможет продолжить
    setRestoring(false);
    setSavedGame(loadSavedGame());
    setScreen("menu");
  };

  const handleResetStats = () => {
    setStats(DEFAULT_STATS);
  };

  return (
    <div className="app-root" data-theme={theme} data-kind={t.kind} style={rootStyle}>
      <ThemeBackdrop theme={theme} />
      <div className="phone">
        {screen === "menu" && (
          <MenuScreen
            theme={theme}
            setTheme={setTheme}
            onStart={handleStart}
            onResume={handleResume}
            onDiscardSave={handleDiscardSave}
            onOpenProfile={() => setScreen("profile")}
            onOpenSettings={() => setScreen("settings")}
            profile={menuProfile}
            savedGame={savedGame}
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
            onStart={() => {
              setRestoring(false);
              setScreen("game");
            }}
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
            savedGame={restoring ? savedGame : null}
            onExit={handleExitGame}
            onMatchOver={handleMatchOver}
          />
        )}
        {screen === "profile" && (
          <ProfileScreen
            profile={profile}
            stats={stats}
            onSave={(p) => {
              setProfile(p);
              setScreen("menu");
            }}
            onResetStats={handleResetStats}
            onBack={() => setScreen("menu")}
          />
        )}
        {screen === "settings" && (
          <SettingsScreen
            theme={theme}
            setTheme={setTheme}
            settings={settings}
            setSettings={setSettings}
            onBack={() => setScreen("menu")}
          />
        )}
      </div>
    </div>
  );
}

// re-export DEFAULT_PROFILE для удобства внешних потребителей (тестов и т.п.)
export { DEFAULT_PROFILE };
