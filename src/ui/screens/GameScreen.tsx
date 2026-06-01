import { useEffect, useMemo, useState } from "react";
import type { BotLevel, RuleConfig } from "../../core";
import { Board } from "../components/Board";
import { Confetti } from "../components/Confetti";
import { FloatingTheme } from "../components/FloatingTheme";
import { Hand } from "../components/Hand";
import { Logo } from "../components/Logo";
import { PauseOverlay } from "../components/PauseOverlay";
import { Scoreboard } from "../components/Scoreboard";
import { TransformControls } from "../components/TransformControls";
import { THEMES, type ThemeId } from "../themes";
import { useGame } from "../useGame";
import type { SavedGame } from "../storage/saveGame";
import type { MatchOutcome } from "../storage/stats";
import type { GameMode } from "./MenuScreen";
import { ResultOverlay } from "./ResultOverlay";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  mode: GameMode;
  cfg: RuleConfig;
  botLevel: BotLevel;
  blitz: BlitzPreset;
  savedGame: SavedGame | null;
  onExit: () => void;
  onMatchOver: (outcome: MatchOutcome) => void;
}

export function GameScreen({
  theme,
  setTheme,
  mode,
  cfg,
  botLevel,
  blitz,
  savedGame,
  onExit,
  onMatchOver,
}: Props) {
  const names = useMemo<[string, string]>(() => {
    if (mode === "hotseat") return ["Игрок 1", "Игрок 2"];
    return [THEMES[theme].p0name, THEMES[theme].p1name];
  }, [mode, theme]);

  const [confettiTick, setConfettiTick] = useState(0);
  const game = useGame({
    session: { cfg, mode, botLevel, blitz, names },
    savedGame,
    onMatchOver,
    onPerfect: () => setConfettiTick((t) => t + 1),
  });
  // confetti виден ~1.7с после триггера
  const [showConfetti, setShowConfetti] = useState(false);
  useEffect(() => {
    if (confettiTick === 0) return;
    setShowConfetti(true);
    const t = setTimeout(() => setShowConfetti(false), 1700);
    return () => clearTimeout(t);
  }, [confettiTick]);
  const { state, ghost, deadIds } = game;

  const [paused, setPausedLocal] = useState(false);
  useEffect(() => {
    game.setPaused(paused);
  }, [paused, game]);

  // shake-эффект на невалидной постановке: всплеск .shake тика → класс на 320мс
  const [shaking, setShaking] = useState(false);
  useEffect(() => {
    if (state.shake === 0) return;
    setShaking(true);
    const t = setTimeout(() => setShaking(false), 320);
    return () => clearTimeout(t);
  }, [state.shake]);

  // hotkeys: R / Ф для поворота (Ф — соседняя по раскладке к R), F / А для отражения, Esc — снять.
  // Прототип использовал К/А (русские) — оставляю их совместимыми.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (paused || state.status !== "playing") return;
      const k = e.key.toLowerCase();
      if (k === "r" || k === "к") {
        if (state.sel && cfg.rotationEnabled) game.rotateSel();
      } else if (k === "f" || k === "а") {
        if (state.sel && cfg.flipEnabled) game.flipSel();
      } else if (k === "escape") {
        game.clearSel();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [paused, state.status, state.sel, cfg.rotationEnabled, cfg.flipEnabled, game]);

  // нижняя рука — активного игрока (для бот-режима всегда человек = 0)
  const bottomOwner: 0 | 1 = mode === "bot" ? 0 : state.current;
  const topOwner: 0 | 1 = (1 - bottomOwner) as 0 | 1;
  const isLocalTurn =
    state.status === "playing" &&
    !state.animating &&
    !paused &&
    !state.players[state.current].isBot;
  const bottomIsActive = state.current === bottomOwner;
  const bottomInteractive = isLocalTurn && bottomIsActive;

  const xp = Math.round(state.players[0].score / 3) + 20;

  return (
    <div className={"screen game-screen " + (shaking ? "shake" : "")}>
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">
          {mode === "bot" ? "vs bot · " + botLevel : "hot-seat"}
        </span>
        <button className="pause-btn" onClick={() => setPausedLocal(true)}>
          ⏸
        </button>
      </div>

      <Scoreboard
        players={[
          { score: state.players[0].score, combo: state.players[0].combo },
          { score: state.players[1].score, combo: state.players[1].combo },
        ]}
        names={names}
        current={state.current}
        status={state.status}
        timer={{ remaining: state.timer.remaining, perTurn: state.timer.perTurn }}
      />

      <Hand
        title={mode === "bot" ? "Рука соперника" : `${names[topOwner]} · ждёт`}
        hint={mode === "bot" ? "наблюдай" : state.current === topOwner ? "ходит" : "ждёт"}
        hand={state.players[topOwner].hand}
        owner={topOwner}
        selId={null}
        deadIds={null}
        interactive={false}
        tone="watch"
      />

      <Board
        board={state.board}
        ghost={ghost}
        flash={state.flash}
        popups={state.popups}
        interactive={bottomInteractive}
        onHover={game.onHover}
        onLeave={game.onLeave}
        onPlace={game.onPlace}
      />

      <div className="status-bar">{state.statusMsg}</div>

      <Hand
        title={mode === "bot" ? "Твоя рука" : `Ходит: ${names[bottomOwner]}`}
        hint={bottomInteractive ? "выбери фигуру" : "ждёт хода"}
        hand={state.players[bottomOwner].hand}
        owner={bottomOwner}
        selId={state.sel?.pieceId ?? null}
        deadIds={bottomIsActive ? deadIds : null}
        interactive={bottomInteractive}
        tone="play"
        onSelect={game.selectPiece}
      />

      <TransformControls
        hasSelection={!!state.sel}
        cfg={cfg}
        onRotate={game.rotateSel}
        onFlip={game.flipSel}
        onClear={game.clearSel}
      />

      <ResultOverlay
        result={state.result}
        names={names}
        xp={xp}
        onRematch={game.restart}
        onMenu={onExit}
      />

      {paused && state.status === "playing" && (
        <PauseOverlay
          onResume={() => setPausedLocal(false)}
          onRestart={() => {
            game.restart();
            setPausedLocal(false);
          }}
          onExit={onExit}
        />
      )}

      {showConfetti && <Confetti tick={confettiTick} />}

      <FloatingTheme theme={theme} setTheme={setTheme} />
    </div>
  );
}
