import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import type { BotLevel, RuleConfig } from "../core";
import { processMatchAchievements, processOnlineAchievements, streakXpBonus } from "./achievements/engine";
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
import type { OnlineProfile } from "../../party/protocol";
import { observeAuthUser, type AuthUser } from "./auth/auth";
import { pullCloud, pushCloud, type CloudSnapshot } from "./auth/sync";
import { applyMatchToDaily, type DailyMatchContext } from "./daily/engine";
import { SKINS_BY_ID, type SkinDef } from "./shop/skins";
import { AchievementsScreen } from "./screens/AchievementsScreen";
import { DailyScreen } from "./screens/DailyScreen";
import { MenuScreen, type GameMode } from "./screens/MenuScreen";
import { LeaderboardScreen } from "./screens/LeaderboardScreen";
import { OnlineGameScreen } from "./screens/OnlineGameScreen";
import { OnlineMenuScreen } from "./screens/OnlineMenuScreen";
import { ProfileScreen } from "./screens/ProfileScreen";
import { SettingsScreen } from "./screens/SettingsScreen";
import { ShopScreen } from "./screens/ShopScreen";
import { TutorialScreen } from "./screens/TutorialScreen";
import { TUTORIAL_REWARD_COINS } from "./tutorial/steps";
import { loadDaily, saveDaily, type DailyState } from "./storage/daily";
import { loadPlayerSkins, savePlayerSkins, type PlayerSkins } from "./storage/skins";
import { claimQuest as claimQuestEngine } from "./daily/engine";
import { addScoreForCrystals, coinsForMatch, loadWallet, saveWallet, type Wallet } from "./storage/wallet";
import { loadInventory, saveInventory, type Inventory } from "./storage/inventory";
import type { PowerupId, PowerupDef } from "./shop/powerups";
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
  applyOnlineMatchToStats,
  DEFAULT_STATS,
  loadStats,
  saveStats,
  type MatchOutcome,
  type Stats,
} from "./storage/stats";
import { isThemeId, THEMES, THEME_STORAGE_KEY, type ThemeId } from "./themes";

type Screen =
  | "menu"
  | "setup"
  | "game"
  | "profile"
  | "settings"
  | "achievements"
  | "online-menu"
  | "online-game"
  | "shop"
  | "daily"
  | "tutorial"
  | "leaderboard";

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
  const [onlineMatch, setOnlineMatch] = useState<{ roomId: string; opponent: OnlineProfile } | null>(null);
  const [wallet, setWallet] = useState<Wallet>(loadWallet);
  const [inventory, setInventory] = useState<Inventory>(loadInventory);
  const [playerSkins, setPlayerSkins] = useState<PlayerSkins>(loadPlayerSkins);
  const [daily, setDaily] = useState<DailyState>(loadDaily);
  const [authUser, setAuthUser] = useState<AuthUser | null>(null);
  const wasRematchRef = useRef(false);
  const pushTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const initialPulledRef = useRef(false);
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
    saveWallet(wallet);
  }, [wallet]);

  useEffect(() => {
    saveInventory(inventory);
  }, [inventory]);

  useEffect(() => {
    savePlayerSkins(playerSkins);
  }, [playerSkins]);

  useEffect(() => {
    saveDaily(daily);
  }, [daily]);

  // На монтировании App пересчитываем daily — может смениться день, пока приложение не было открыто.
  useEffect(() => {
    setDaily(loadDaily());
  }, []);

  // Auth observer + pull cloud snapshot при логине.
  useEffect(() => {
    const unsub = observeAuthUser((u) => {
      setAuthUser(u);
      initialPulledRef.current = false;
      if (u) {
        pullCloud(u.uid)
          .then((snap) => {
            if (snap) {
              if (snap.profile) setProfile(snap.profile);
              if (snap.stats) setStats(snap.stats);
              if (snap.wallet) setWallet(snap.wallet);
              if (snap.achievements) setAchievements(snap.achievements);
              if (snap.skins) setPlayerSkins(snap.skins);
              // daily не тянем — он привязан к дате локального устройства.
            }
            initialPulledRef.current = true;
          })
          .catch(() => {
            initialPulledRef.current = true;
          });
      } else {
        initialPulledRef.current = true;
      }
    });
    return unsub;
  }, []);

  // Debounced push в cloud при изменении прогресса.
  useEffect(() => {
    if (!authUser || !initialPulledRef.current) return;
    if (pushTimerRef.current) clearTimeout(pushTimerRef.current);
    pushTimerRef.current = setTimeout(() => {
      const snap: CloudSnapshot = {
        profile,
        stats,
        wallet,
        achievements,
        skins: playerSkins,
      };
      pushCloud(authUser.uid, snap).catch(() => {
        /* silent — не блокируем UX */
      });
    }, 1500);
    return () => {
      if (pushTimerRef.current) clearTimeout(pushTimerRef.current);
    };
  }, [authUser, profile, stats, wallet, achievements, playerSkins]);

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
    if (m === "online") {
      setOnlineMatch(null);
      setScreen("online-menu");
      return;
    }
    if (m === "arcade") {
      setCfg(settings.defaultCfg);
      setBlitz(settings.defaultBlitz);
      wasRematchRef.current = false;
      setScreen("game");
      return;
    }
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

    // Монеты за матч + кристаллы из накопленного score (150 score = 1 кристалл)
    const coins = coinsForMatch(outcome.myScore, outcome.winner === 0);
    setWallet((w) => {
      const withCoins = { ...w, coins: w.coins + coins, totalEarned: w.totalEarned + coins };
      const { wallet: withCrystals } = addScoreForCrystals(withCoins, outcome.myScore);
      return withCrystals;
    });

    // Daily quests
    const dailyCtx: DailyMatchContext = {
      mode,
      winner: outcome.winner,
      myScore: outcome.myScore,
      totalClearsThisMatch: outcome.totalClearsThisMatch,
      hadPerfectClear: outcome.hadPerfectClear,
      bestComboThisMatch: outcome.bestComboThisMatch,
      botLevel: mode === "bot" ? botLevel : undefined,
    };
    const dailyApply = applyMatchToDaily(daily, dailyCtx);
    setDaily(dailyApply.next);
    if (dailyApply.newlyCompleted.length > 0) {
      // Конвертируем QuestDef в формат AchievementDef для совместимости с ToastStack
      const questToasts: AchievementDef[] = dailyApply.newlyCompleted.map((q) => ({
        id: `daily_${q.id}`,
        title: `Дейли: ${q.title}`,
        description: q.description,
        icon: q.icon,
        total: q.target,
        category: "single",
        rewardXp: 0,
        hidden: false,
      }));
      setToasts((cur) => [...cur, ...questToasts]);
    }

    setSavedGame(null);
  };

  const handleClaimQuest = (defId: string) => {
    const { next, coinsAwarded } = claimQuestEngine(daily, defId);
    setDaily(next);
    if (coinsAwarded > 0) {
      setWallet((w) => ({ ...w, coins: w.coins + coinsAwarded, totalEarned: w.totalEarned + coinsAwarded }));
    }
  };

  const handleBuySkin = (skin: SkinDef) => {
    if (playerSkins.unlocked.includes(skin.id)) return;
    if (wallet.coins < skin.price) return;
    setWallet((w) => ({ ...w, coins: w.coins - skin.price }));
    setPlayerSkins((p) => ({ unlocked: [...p.unlocked, skin.id], equipped: skin.id }));
  };

  const handleEquipSkin = (id: SkinDef["id"]) => {
    setPlayerSkins((p) =>
      p.unlocked.includes(id) ? { ...p, equipped: id } : p,
    );
  };

  const handleBuyPowerup = (p: PowerupDef) => {
    if (wallet.crystals < p.price) return;
    setWallet((w) => ({ ...w, crystals: w.crystals - p.price }));
    setInventory((inv) => ({ ...inv, [p.id]: inv[p.id] + 1 }));
  };

  const handleConsumePowerup = (id: PowerupId) => {
    setInventory((inv) => ({ ...inv, [id]: Math.max(0, inv[id] - 1) }));
  };

  const handleTutorialCompleted = () => {
    setWallet((w) => ({
      ...w,
      coins: w.coins + TUTORIAL_REWARD_COINS,
      totalEarned: w.totalEarned + TUTORIAL_REWARD_COINS,
    }));
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
            onOpenShop={() => setScreen("shop")}
            onOpenDaily={() => setScreen("daily")}
            onOpenTutorial={() => setScreen("tutorial")}
            profile={menuProfile}
            savedGame={savedGame}
            coins={wallet.coins}
          />
        )}
        {screen === "shop" && (
          <ShopScreen
            wallet={wallet}
            player={playerSkins}
            inventory={inventory}
            onBuySkin={handleBuySkin}
            onEquipSkin={handleEquipSkin}
            onBuyPowerup={handleBuyPowerup}
            onBack={() => setScreen("menu")}
          />
        )}
        {screen === "daily" && (
          <DailyScreen
            daily={daily}
            coins={wallet.coins}
            onClaim={handleClaimQuest}
            onBack={() => setScreen("menu")}
          />
        )}
        {screen === "tutorial" && (
          <TutorialScreen
            skinClass={SKINS_BY_ID[playerSkins.equipped]?.cssClass ?? "skin-default"}
            onExit={() => setScreen("menu")}
            onCompleted={handleTutorialCompleted}
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
            skinClass={SKINS_BY_ID[playerSkins.equipped]?.cssClass ?? "skin-default"}
            inventory={inventory}
            onConsumePowerup={handleConsumePowerup}
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
        {screen === "leaderboard" && (
          <LeaderboardScreen myId={profile.id} onBack={() => setScreen("online-menu")} />
        )}
        {screen === "online-menu" && (
          <OnlineMenuScreen
            profile={{ id: profile.id, nick: profile.nick, avatar: profile.avatar }}
            onBack={() => setScreen("menu")}
            onOpenLeaderboard={() => setScreen("leaderboard")}
            onMatched={(roomId, opponent) => {
              setOnlineMatch({ roomId, opponent });
              setScreen("online-game");
            }}
            onBotFallback={() => {
              // никого не нашлось — играем с локальным ботом medium.
              setMode("bot");
              setCfg(settings.defaultCfg);
              setBotLevel("medium");
              setBlitz(settings.defaultBlitz);
              wasRematchRef.current = false;
              setScreen("game");
            }}
          />
        )}
        {screen === "online-game" && onlineMatch && (
          <OnlineGameScreen
            theme={theme}
            roomId={onlineMatch.roomId}
            profile={{ id: profile.id, nick: profile.nick, avatar: profile.avatar }}
            opponent={onlineMatch.opponent}
            onExit={() => {
              setOnlineMatch(null);
              setScreen("menu");
            }}
            onMatchEnded={(summary) => {
              const d = new Date();
              const today = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
              const wasOpKnown = !!stats.onlineOpponents[summary.opponentId];
              const matchInfo = {
                won: summary.won,
                drew: summary.drew,
                myScore: summary.myScore,
                opponentScore: summary.opponentScore,
                scoreGap: summary.scoreGap,
                opponentId: summary.opponentId,
                opponentNick: summary.opponentNick,
                turnCount: summary.turnCount,
                themeId: summary.themeId,
                reason: summary.reason,
                isRematchOfSameOpponent: wasOpKnown,
                bestComboThisMatch: 0,
                maxMultiClearThisMatch: 0,
                myClearsThisMatch: 0,
                hadPerfectClear: false,
                today,
              };
              const nextStats = applyOnlineMatchToStats(stats, matchInfo);
              setStats(nextStats);

              const { next: nextAch, unlocked } = processOnlineAchievements(achievements, {
                stats: nextStats,
                match: matchInfo,
              });
              setAchievements(nextAch);
              if (unlocked.length > 0) setToasts((cur) => [...cur, ...unlocked]);
              const achXp = unlocked.reduce((sum, a) => sum + a.rewardXp, 0);

              const reward = summary.won ? 30 : summary.drew ? 15 : 8;
              setWallet((w) => {
                const withCoins = { ...w, coins: w.coins + reward, totalEarned: w.totalEarned + reward };
                const { wallet: withCrystals } = addScoreForCrystals(withCoins, summary.myScore);
                return withCrystals;
              });
              if (achXp > 0) setProfile((p) => ({ ...p, xp: p.xp + achXp }));
            }}
          />
        )}
        {screen === "settings" && (
          <SettingsScreen
            theme={theme}
            setTheme={setTheme}
            settings={settings}
            setSettings={setSettings}
            authUser={authUser}
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
