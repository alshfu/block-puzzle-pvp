import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import type { BotLevel, RuleConfig } from "../core";
import { processMatchAchievements, streakXpBonus } from "./achievements/engine";
import type { AchievementDef } from "./achievements/definitions";
import { setSoundEnabled, setVibrateEnabled } from "./audio";
import { setMusicEnabled, setMusicTheme } from "./music";
import { ThemeBackdrop } from "./components/ThemeBackdrop";
import { ToastStack } from "./components/ToastStack";
import {
  loadAchievements,
  saveAchievements,
  type PlayerAchievements,
} from "./storage/achievements";
import { GameScreen } from "./screens/GameScreen";
import { AchievementsScreen } from "./screens/AchievementsScreen";
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

type Screen = "menu" | "setup" | "game" | "profile" | "settings" | "achievements";

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
  const [botLevelB, setBotLevelB] = useState<BotLevel>(settings.defaultBotLevel);
  const [blitz, setBlitz] = useState<BlitzPreset>(settings.defaultBlitz);

  const [savedGame, setSavedGame] = useState<SavedGame | null>(loadSavedGame);
  const [restoring, setRestoring] = useState(false);
  const [achievements, setAchievements] = useState<PlayerAchievements>(loadAchievements);
  const [toasts, setToasts] = useState<AchievementDef[]>([]);
  const wasRematchRef = useRef(false);
  const prevBestStreakRef = useRef(loadStats().bestWinStreak);

  useEffect(() => {
    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    } catch {
      /* ignore */
    }
    setMusicTheme(theme);
  }, [theme]);

  useEffect(() => {
    saveProfile(profile);
  }, [profile]);

  useEffect(() => {
    saveStats(stats);
  }, [stats]);

  useEffect(() => {
    saveAchievements(achievements);
  }, [achievements]);

  useEffect(() => {
    saveSettings(settings);
    setSoundEnabled(settings.sound);
    setVibrateEnabled(settings.vibrate);
    setMusicEnabled(settings.music);
  }, [settings]);

  // Применяем сохранённые тумблеры сразу при первом рендере (до изменения settings).
  useEffect(() => {
    setSoundEnabled(settings.sound);
    setVibrateEnabled(settings.vibrate);
    setMusicEnabled(settings.music);
    setMusicTheme(theme);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
    setBotLevelB(settings.defaultBotLevel);
    setBlitz(settings.defaultBlitz);
    wasRematchRef.current = false;
    setScreen("setup");
  };

  const handleResume = () => {
    if (!savedGame) return;
    setMode(savedGame.mode);
    setCfg(savedGame.cfg);
    setBotLevel(savedGame.botLevels?.[1] ?? savedGame.botLevel);
    setBotLevelB(savedGame.botLevels?.[0] ?? savedGame.botLevel);
    setBlitz(savedGame.blitz);
    setRestoring(true);
    setScreen("game");
  };

  const handleDiscardSave = () => {
    clearSavedGame();
    setSavedGame(null);
  };

  const handleMatchOver = (outcome: MatchOutcome) => {
    prevBestStreakRef.current = stats.bestWinStreak; // снимаем «до» для UI «новый рекорд»
    const nextStats = applyMatchToStats(stats, outcome);
    // rematch streak: засчитываем продление, только если предыдущий выход был через «Реванш».
    nextStats.rematchStreak = wasRematchRef.current ? nextStats.rematchStreak + 1 : 1;
    setStats(nextStats);

    // Базовый XP: победа +50 / ничья +25 / поражение +10 + 1 за каждую очистку.
    const matchXp =
      (outcome.winner === 0 ? 50 : outcome.winner === -1 ? 25 : 10) +
      outcome.totalClearsThisMatch;
    const streakBonus = streakXpBonus(nextStats.currentWinStreak);

    // Ачивки
    const { next, unlocked } = processMatchAchievements(achievements, {
      winner: outcome.winner,
      myScore: outcome.myScore,
      totalClearsThisMatch: outcome.totalClearsThisMatch,
      maxMultiClearThisMatch: outcome.maxMultiClearThisMatch,
      bestComboThisMatch: outcome.bestComboThisMatch,
      hadPerfectClear: outcome.hadPerfectClear,
      mode,
      botLevel: mode === "bot" ? botLevel : null,
      statsAfter: nextStats,
      winStreak: nextStats.currentWinStreak,
      rematchStreak: nextStats.rematchStreak,
    });
    setAchievements(next);

    const achXp = unlocked.reduce((sum, a) => sum + a.rewardXp, 0);
    setProfile((p) => ({ ...p, xp: p.xp + matchXp + streakBonus + achXp }));

    if (unlocked.length > 0) {
      setToasts((cur) => [...cur, ...unlocked]);
    }

    setSavedGame(null);
  };

  const dismissToast = (id: string) => {
    setToasts((cur) => cur.filter((a) => a.id !== id));
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
            mode={mode}
            cfg={cfg}
            setCfg={setCfg}
            botLevel={botLevel}
            setBotLevel={setBotLevel}
            botLevelB={botLevelB}
            setBotLevelB={setBotLevelB}
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
            mode={mode}
            cfg={cfg}
            botLevel={botLevel}
            botLevelB={botLevelB}
            blitz={blitz}
            savedGame={restoring ? savedGame : null}
            currentStreak={stats.currentWinStreak}
            prevBestStreak={prevBestStreakRef.current}
            onExit={handleExitGame}
            onMatchOver={handleMatchOver}
            onRematch={() => { wasRematchRef.current = true; }}
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
            onOpenAchievements={() => setScreen("achievements")}
            onBack={() => setScreen("menu")}
          />
        )}
        {screen === "achievements" && (
          <AchievementsScreen
            achievements={achievements}
            onBack={() => setScreen("profile")}
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
      <ToastStack toasts={toasts} onDismiss={dismissToast} />
    </div>
  );
}

// re-export DEFAULT_PROFILE для удобства внешних потребителей (тестов и т.п.)
export { DEFAULT_PROFILE };
