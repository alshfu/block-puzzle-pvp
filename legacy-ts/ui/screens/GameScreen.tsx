import { useEffect, useMemo, useRef, useState, type PointerEvent } from "react";
import type { BotLevel, Coord, PieceInstance, RuleConfig } from "../../core";
import { SIZE } from "../../core";
import { Board } from "../components/Board";
import { useBoardPointer } from "../hooks/useBoardPointer";
import { ComboFlash, pickComboMessage } from "../components/ComboFlash";
import { PowerupsPanel } from "../components/PowerupsPanel";
import type { PowerupId } from "../shop/powerups";
import type { Inventory } from "../storage/inventory";
import { Confetti } from "../components/Confetti";
import { DragLayer } from "../components/DragLayer";
import { Hand } from "../components/Hand";
import { Logo } from "../components/Logo";
import { PauseOverlay } from "../components/PauseOverlay";
import { Scoreboard } from "../components/Scoreboard";
import { TransformControls } from "../components/TransformControls";
import type { SavedGame } from "../storage/saveGame";
import type { MatchOutcome } from "../storage/stats";
import { THEMES, type ThemeId } from "../themes";
import { useGame } from "../useGame";
import { isPilotEnabled } from "../pilot/flag";
import { clearPilotState, publishPilotState } from "../pilot/api";
import type { GameMode } from "./MenuScreen";
import { ResultOverlay } from "./ResultOverlay";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  mode: GameMode;
  cfg: RuleConfig;
  botLevel: BotLevel;
  botLevelB: BotLevel;
  blitz: BlitzPreset;
  savedGame: SavedGame | null;
  currentStreak: number;
  prevBestStreak: number;
  /** CSS-класс активного скина для клеток доски. */
  skinClass?: string;
  inventory: Inventory;
  onConsumePowerup: (id: PowerupId) => void;
  botDelayMs?: number;
  clearAnimMs?: number;
  confettiEnabled?: boolean;
  showGhost?: boolean;
  onExit: () => void;
  onMatchOver: (outcome: MatchOutcome) => void;
  onRematch: () => void;
}

interface DragState {
  piece: PieceInstance;
  pointerId: number;
  x: number; // viewport coords
  y: number;
  active: boolean; // false до тех пор пока не прошёл movement threshold
}

const DRAG_THRESHOLD_PX = 6;

export function GameScreen({
  theme,
  mode,
  cfg,
  botLevel,
  botLevelB,
  blitz,
  savedGame,
  currentStreak,
  prevBestStreak,
  skinClass,
  inventory,
  onConsumePowerup,
  botDelayMs,
  clearAnimMs,
  confettiEnabled = true,
  showGhost = true,
  onExit,
  onMatchOver,
  onRematch,
}: Props) {
  const names = useMemo<[string, string]>(() => {
    if (mode === "arcade") return [THEMES[theme].p0name, ""];
    if (mode === "hotseat") return ["Игрок 1", "Игрок 2"];
    if (mode === "botvbot") return [`Бот A · ${botLevelB}`, `Бот B · ${botLevel}`];
    return [THEMES[theme].p0name, THEMES[theme].p1name];
  }, [mode, theme, botLevel, botLevelB]);

  const botLevels = useMemo<[BotLevel | null, BotLevel | null]>(() => {
    if (mode === "bot") return [null, botLevel];
    if (mode === "hotseat" || mode === "arcade") return [null, null];
    return [botLevelB, botLevel]; // botvbot: A first, B second
  }, [mode, botLevel, botLevelB]);

  const [confettiTick, setConfettiTick] = useState(0);
  const [comboFlash, setComboFlash] = useState<{ key: number; level: 1 | 2 | 3; combo: number; message: string } | null>(null);
  const game = useGame({
    session: { cfg, mode, botLevels, blitz, names, botDelayMs, clearAnimMs },
    savedGame,
    onMatchOver,
    onPerfect: () => setConfettiTick((t) => t + 1),
    onComboMilestone: (level, combo) => {
      setComboFlash({
        key: Date.now(),
        level,
        combo,
        message: pickComboMessage(theme, level),
      });
    },
  });
  // авто-скрытие combo flash
  useEffect(() => {
    if (!comboFlash) return;
    const t = setTimeout(() => setComboFlash(null), 1700);
    return () => clearTimeout(t);
  }, [comboFlash]);
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

  const [shaking, setShaking] = useState(false);
  useEffect(() => {
    if (state.shake === 0) return;
    setShaking(true);
    const t = setTimeout(() => setShaking(false), 320);
    return () => clearTimeout(t);
  }, [state.shake]);

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

  // ─── drag-and-drop ────────────────────────────────────────────────────
  const boardRef = useRef<HTMLDivElement | null>(null);
  const [drag, setDrag] = useState<DragState | null>(null);
  const dragRef = useRef<DragState | null>(null);
  dragRef.current = drag;
  const lastHoverRef = useRef<{ r: number; c: number } | null>(null);

  // Сторона клетки доски — обновляется по resize, нужна для масштаба DragLayer и для расчёта r/c.
  const [cellPx, setCellPx] = useState<number>(36);
  useEffect(() => {
    const update = () => {
      const el = boardRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      // Доска: padding 9px по периметру, 9 ячеек, gap 3px между ними.
      const PAD = 9;
      const GAP = 3;
      const inner = rect.width - PAD * 2 - GAP * (SIZE - 1);
      const c = inner / SIZE;
      if (c > 0) setCellPx(c);
    };
    update();
    const ro = new ResizeObserver(update);
    if (boardRef.current) ro.observe(boardRef.current);
    window.addEventListener("resize", update);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", update);
    };
  }, []);

  // Конвертация viewport (x, y) → (row, col) с учётом offsets фигуры (cells).
  // Опорная точка — top-left ячейки фигуры; ставим клетку под центром указателя как «голову» фигуры.
  function clientToCell(x: number, y: number, cells: Coord[]): { r: number; c: number } | null {
    const el = boardRef.current;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    const PAD = 9;
    const GAP = 3;
    const step = cellPx + GAP;
    // координаты внутри доски относительно top-left первой ячейки
    const localX = x - rect.left - PAD;
    const localY = y - rect.top - PAD;
    // pointer-cell: куда указывает курсор
    const pc = Math.floor(localX / step);
    const pr = Math.floor(localY / step);
    if (pr < 0 || pr >= SIZE || pc < 0 || pc >= SIZE) return null;
    // Привязка: считаем что pointer указывает примерно на центр фигуры.
    // Берём отступ от top-left фигуры до её центра и вычитаем.
    const maxR = Math.max(...cells.map((c2) => c2[0]));
    const maxC = Math.max(...cells.map((c2) => c2[1]));
    const offR = Math.round(maxR / 2);
    const offC = Math.round(maxC / 2);
    const r = pr - offR;
    const c = pc - offC;
    if (r < 0 || c < 0 || r + maxR >= SIZE || c + maxC >= SIZE) {
      // частично вне поля — clamp
      const clampedR = Math.max(0, Math.min(r, SIZE - 1 - maxR));
      const clampedC = Math.max(0, Math.min(c, SIZE - 1 - maxC));
      return { r: clampedR, c: clampedC };
    }
    return { r, c };
  }

  // Глобальные обработчики drag.
  useEffect(() => {
    if (!drag) return;
    const onMove = (e: globalThis.PointerEvent) => {
      const d = dragRef.current;
      if (!d || e.pointerId !== d.pointerId) return;
      const dx = e.clientX - d.x;
      const dy = e.clientY - d.y;
      let active = d.active;
      if (!active && Math.hypot(dx, dy) > DRAG_THRESHOLD_PX) active = true;
      setDrag({ ...d, x: e.clientX, y: e.clientY, active });
      if (active) {
        const cellsToUse = state.sel?.cells ?? d.piece.cells;
        const cell = clientToCell(e.clientX, e.clientY, cellsToUse);
        if (cell) {
          lastHoverRef.current = cell;
          game.onHover(cell.r, cell.c);
        } else {
          lastHoverRef.current = null;
          game.onLeave();
        }
      }
    };
    const onUp = (e: globalThis.PointerEvent) => {
      const d = dragRef.current;
      if (!d || e.pointerId !== d.pointerId) return;
      if (d.active) {
        const cell = lastHoverRef.current;
        if (cell) {
          game.onPlace(cell.r, cell.c);
        } else {
          game.clearSel();
        }
      }
      lastHoverRef.current = null;
      setDrag(null);
    };
    const onCancel = (e: globalThis.PointerEvent) => {
      const d = dragRef.current;
      if (!d || e.pointerId !== d.pointerId) return;
      lastHoverRef.current = null;
      setDrag(null);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    window.addEventListener("pointercancel", onCancel);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onCancel);
    };
  }, [drag, game, state.sel, cellPx]);

  // Desktop fallback: click-to-place + hover ghost когда фигура уже выбрана и НЕТ drag.
  const isHumanTurn =
    state.status === "playing" &&
    !state.animating &&
    !paused &&
    !state.players[state.current].isBot;
  useBoardPointer({
    boardRef,
    cellPx,
    sel: state.sel,
    dragActive: !!drag?.active,
    enabled: isHumanTurn,
    onHover: game.onHover,
    onLeave: game.onLeave,
    onPlace: game.onPlace,
  });

  // ─── Power-ups ─────────────────────────────────────────────────────────
  const [activePowerup, setActivePowerup] = useState<PowerupId | null>(null);

  const handlePowerupClick = (id: PowerupId) => {
    if (inventory[id] <= 0) return;
    if (id === "swap_hand") {
      if (game.powerSwapHand()) onConsumePowerup(id);
      return;
    }
    if (id === "auto_play") {
      if (game.powerAutoPlay()) onConsumePowerup(id);
      return;
    }
    if (id === "hint") {
      const hint = game.powerHint();
      if (hint) {
        onConsumePowerup(id);
        // через 3 сек снять selection и hover
        setTimeout(() => { game.clearSel(); }, 3000);
      }
      return;
    }
    // stick_row / stick_col / bomb_3x3 — переходим в selection mode
    setActivePowerup(activePowerup === id ? null : id);
  };

  // клик по доске в power-up режиме: вычисляем (row,col) и вызываем нужный action
  useEffect(() => {
    if (!activePowerup) return;
    const el = boardRef.current;
    if (!el) return;
    const onClick = (e: MouseEvent) => {
      const rect = el.getBoundingClientRect();
      const PAD = 9;
      const GAP = 3;
      const step = cellPx + GAP;
      const lx = e.clientX - rect.left - PAD;
      const ly = e.clientY - rect.top - PAD;
      const c = Math.floor(lx / step);
      const r = Math.floor(ly / step);
      if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) return;
      let used = false;
      if (activePowerup === "stick_row") used = game.powerClearRow(r);
      else if (activePowerup === "stick_col") used = game.powerClearCol(c);
      else if (activePowerup === "bomb_3x3") used = game.powerBomb(r, c);
      if (used) {
        onConsumePowerup(activePowerup);
        setActivePowerup(null);
      }
    };
    el.addEventListener("click", onClick);
    return () => el.removeEventListener("click", onClick);
  }, [activePowerup, cellPx, game, onConsumePowerup]);

  // Esc — отменить power-up
  useEffect(() => {
    if (!activePowerup) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setActivePowerup(null);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [activePowerup]);

  // Был ли pieceId выбран ДО pointerdown — иначе первый же tap воспринимался
  // как повтор и крутил фигуру (pointerdown сам ставит sel перед tap-up).
  const wasSelBeforeDownRef = useRef<string | null>(null);

  const handlePiecePointerDown = (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => {
    if (paused || state.status !== "playing") return;
    wasSelBeforeDownRef.current = state.sel?.pieceId ?? null;
    // выбираем фигуру в ядре, чтобы ghost мог рассчитаться.
    // Если эта же фигура уже выбрана (с повёрнутой/отражённой ориентацией) — не сбрасываем её в normalize.
    if (state.sel?.pieceId !== piece.id) {
      game.selectPiece(piece);
    }
    // Drag начинаем только если СЕЙЧАС наш ход. Если ход бота — фигура
    // выбрана как preselect, но фактически тащить её на доску не имеет
    // смысла (onPlace всё равно отвергнет).
    const localTurn =
      state.status === "playing" &&
      !state.animating &&
      !paused &&
      !state.players[state.current].isBot;
    if (localTurn) {
      setDrag({
        piece,
        pointerId: e.pointerId,
        x: e.clientX,
        y: e.clientY,
        active: false,
      });
    }
  };

  const handlePieceTap = (piece: PieceInstance) => {
    // короткий клик без движения: крутим только если фигура была выбрана ДО этого клика.
    // Работает и во время preselect (когда ход бота).
    if (paused || state.status !== "playing") return;
    const wasSelectedBefore = wasSelBeforeDownRef.current === piece.id;
    wasSelBeforeDownRef.current = null;
    if (wasSelectedBefore && cfg.rotationEnabled) {
      game.rotateSel();
    } else if (state.sel?.pieceId !== piece.id) {
      game.selectPiece(piece);
    }
  };

  // В режимах с человеком — активная рука внизу. В bot×bot — фиксируем 0 снизу, 1 сверху.
  const bottomOwner: 0 | 1 = mode === "hotseat" ? state.current : 0;
  const isLocalTurn =
    state.status === "playing" &&
    !state.animating &&
    !paused &&
    !state.players[state.current].isBot;
  const bottomIsActive = state.current === bottomOwner;
  const bottomInteractive = isLocalTurn && bottomIsActive;

  const xp = Math.round(state.players[0].score / 3) + 20;

  const dragCells = state.sel?.cells ?? drag?.piece.cells ?? [];
  const dragOwner: 0 | 1 = state.current;

  // Public state для UI-пилота. Действия пилот выполняет через DOM-события.
  useEffect(() => {
    if (!isPilotEnabled()) return;
    publishPilotState({
      mode: "offline",
      playing: state.status === "playing",
      myTurn: bottomInteractive,
      board: state.board,
      myHand: state.players[bottomOwner].hand,
      cfg,
      matchId: `offline-${mode}`,
      selPieceId: state.sel?.pieceId ?? null,
      selCells: state.sel?.cells ?? null,
    });
    return () => {
      if (state.status !== "playing") clearPilotState();
    };
  }, [state.status, state.board, state.players, bottomOwner, bottomInteractive, cfg, mode, state.sel]);

  return (
    <div className={"screen game-screen " + (shaking ? "shake" : "")}>
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">
          {mode === "bot"
            ? "vs bot · " + botLevel
            : mode === "hotseat"
              ? "hot-seat"
              : mode === "arcade"
                ? "arcade · solo"
                : "bot × bot"}
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
        hands={
          mode === "arcade"
            ? undefined
            : [
                bottomOwner === 0 ? null : state.players[0].hand,
                bottomOwner === 1 ? null : state.players[1].hand,
              ]
        }
      />

      {/* Рука соперника inline в его pcard (через Scoreboard hands prop). */}

      <Board ref={boardRef} board={state.board} ghost={showGhost ? ghost : null} flash={state.flash} popups={state.popups} skinClass={skinClass} hasSelection={!!state.sel} />

      <Hand
        title={
          mode === "botvbot"
            ? names[bottomOwner]
            : bottomInteractive
              ? "Твоя рука · ходишь"
              : mode === "hotseat"
                ? `Твоя рука · ходит ${names[state.current]}`
                : "Твоя рука · ждёт"
        }
        hint={
          bottomInteractive
            ? "перетащи фигуру на доску"
            : mode === "botvbot"
              ? state.current === bottomOwner ? "ходит" : "ждёт"
              : ""
        }
        hand={state.players[bottomOwner].hand}
        owner={bottomOwner}
        selId={state.sel?.pieceId ?? null}
        selCells={state.sel?.cells ?? null}
        deadIds={bottomIsActive ? deadIds : null}
        interactive={mode !== "botvbot" && state.status === "playing"}
        tone="play"
        onPiecePointerDown={mode !== "botvbot" ? handlePiecePointerDown : undefined}
        onPieceTap={mode !== "botvbot" ? handlePieceTap : undefined}
      />

      {/* В spectator-режиме (botvbot) transform-controls и power-ups не нужны:
         игрок только наблюдает, не ходит. Экономим ~100px на мобиле. */}
      {mode !== "botvbot" && (
        <TransformControls
          hasSelection={!!state.sel}
          cfg={cfg}
          onRotate={game.rotateSel}
          onFlip={game.flipSel}
          onClear={game.clearSel}
        />
      )}

      {/* Power-ups доступны только пока ход локального игрока */}
      {mode !== "online" && mode !== "botvbot" && (
        <PowerupsPanel
          inventory={inventory}
          active={activePowerup}
          enabled={isLocalTurn}
          onClick={handlePowerupClick}
        />
      )}

      {drag?.active && (
        <DragLayer
          cells={dragCells}
          owner={dragOwner}
          x={drag.x}
          y={drag.y}
          cellPx={cellPx}
          visible
        />
      )}

      <ResultOverlay
        result={state.result}
        names={names}
        theme={theme}
        breakdown={{
          base: state.baseScoreP0,
          combo: state.comboBonusP0,
          perfect: state.perfectBonusP0,
        }}
        streak={currentStreak}
        prevBestStreak={prevBestStreak}
        xp={xp}
        onRematch={() => { onRematch(); game.restart(); }}
        onMenu={onExit}
      />

      {paused && state.status === "playing" && (
        <PauseOverlay
          onResume={() => setPausedLocal(false)}
          onRestart={() => {
            onRematch();
            game.restart();
            setPausedLocal(false);
          }}
          onExit={onExit}
        />
      )}

      {showConfetti && confettiEnabled && <Confetti tick={confettiTick} />}

      {comboFlash && (
        <ComboFlash
          key={comboFlash.key}
          theme={theme}
          level={comboFlash.level}
          combo={comboFlash.combo}
          message={comboFlash.message}
        />
      )}
    </div>
  );
}
