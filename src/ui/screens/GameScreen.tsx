import { useEffect, useMemo, useRef, useState, type PointerEvent } from "react";
import type { BotLevel, Coord, PieceInstance, RuleConfig } from "../../core";
import { SIZE } from "../../core";
import { Board } from "../components/Board";
import { Confetti } from "../components/Confetti";
import { DragLayer } from "../components/DragLayer";
import { FloatingTheme } from "../components/FloatingTheme";
import { Hand } from "../components/Hand";
import { Logo } from "../components/Logo";
import { PauseOverlay } from "../components/PauseOverlay";
import { Scoreboard } from "../components/Scoreboard";
import { TransformControls } from "../components/TransformControls";
import type { SavedGame } from "../storage/saveGame";
import type { MatchOutcome } from "../storage/stats";
import { THEMES, type ThemeId } from "../themes";
import { useGame } from "../useGame";
import type { GameMode } from "./MenuScreen";
import { ResultOverlay } from "./ResultOverlay";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  mode: GameMode;
  cfg: RuleConfig;
  botLevel: BotLevel;
  botLevelB: BotLevel;
  blitz: BlitzPreset;
  savedGame: SavedGame | null;
  onExit: () => void;
  onMatchOver: (outcome: MatchOutcome) => void;
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
  setTheme,
  mode,
  cfg,
  botLevel,
  botLevelB,
  blitz,
  savedGame,
  onExit,
  onMatchOver,
}: Props) {
  const names = useMemo<[string, string]>(() => {
    if (mode === "hotseat") return ["Игрок 1", "Игрок 2"];
    if (mode === "botvbot") return [`Бот A · ${botLevelB}`, `Бот B · ${botLevel}`];
    return [THEMES[theme].p0name, THEMES[theme].p1name];
  }, [mode, theme, botLevel, botLevelB]);

  const botLevels = useMemo<[BotLevel | null, BotLevel | null]>(() => {
    if (mode === "bot") return [null, botLevel];
    if (mode === "hotseat") return [null, null];
    return [botLevelB, botLevel]; // botvbot: A first, B second
  }, [mode, botLevel, botLevelB]);

  const [confettiTick, setConfettiTick] = useState(0);
  const game = useGame({
    session: { cfg, mode, botLevels, blitz, names },
    savedGame,
    onMatchOver,
    onPerfect: () => setConfettiTick((t) => t + 1),
  });
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

  const handlePiecePointerDown = (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => {
    if (paused || state.status !== "playing") return;
    if (state.players[state.current].isBot) return;
    // выбираем фигуру в ядре, чтобы ghost мог рассчитаться
    game.selectPiece(piece);
    setDrag({
      piece,
      pointerId: e.pointerId,
      x: e.clientX,
      y: e.clientY,
      active: false,
    });
  };

  const handlePieceTap = (piece: PieceInstance) => {
    // короткий клик без движения: если та же выбранная фигура — повернуть; иначе оставить выбранной.
    if (paused || state.status !== "playing") return;
    if (state.players[state.current].isBot) return;
    if (state.sel?.pieceId === piece.id && cfg.rotationEnabled) {
      game.rotateSel();
    } else {
      game.selectPiece(piece);
    }
  };

  // В режимах с человеком — активная рука внизу. В bot×bot — фиксируем 0 снизу, 1 сверху.
  const bottomOwner: 0 | 1 = mode === "hotseat" ? state.current : 0;
  const topOwner: 0 | 1 = (1 - bottomOwner) as 0 | 1;
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

  return (
    <div className={"screen game-screen " + (shaking ? "shake" : "")}>
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">
          {mode === "bot"
            ? "vs bot · " + botLevel
            : mode === "hotseat"
              ? "hot-seat"
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
      />

      <Hand
        title={
          mode === "bot"
            ? "Рука соперника"
            : mode === "botvbot"
              ? `${names[topOwner]}`
              : `${names[topOwner]} · ждёт`
        }
        hint={
          mode === "botvbot"
            ? state.current === topOwner ? "ходит" : "ждёт"
            : mode === "bot"
              ? "наблюдай"
              : state.current === topOwner ? "ходит" : "ждёт"
        }
        hand={state.players[topOwner].hand}
        owner={topOwner}
        selId={null}
        deadIds={null}
        interactive={false}
        tone="watch"
      />

      <Board ref={boardRef} board={state.board} ghost={ghost} flash={state.flash} popups={state.popups} />

      <div className="status-bar">{state.statusMsg}</div>

      <Hand
        title={
          mode === "bot"
            ? "Твоя рука"
            : mode === "botvbot"
              ? `${names[bottomOwner]}`
              : `Ходит: ${names[bottomOwner]}`
        }
        hint={
          bottomInteractive
            ? "перетащи фигуру на доску"
            : mode === "botvbot"
              ? state.current === bottomOwner ? "ходит" : "ждёт"
              : "ждёт хода"
        }
        hand={state.players[bottomOwner].hand}
        owner={bottomOwner}
        selId={state.sel?.pieceId ?? null}
        deadIds={bottomIsActive ? deadIds : null}
        interactive={bottomInteractive}
        tone="play"
        onPiecePointerDown={bottomInteractive ? handlePiecePointerDown : undefined}
        onPieceTap={bottomInteractive ? handlePieceTap : undefined}
      />

      <TransformControls
        hasSelection={!!state.sel}
        cfg={cfg}
        onRotate={game.rotateSel}
        onFlip={game.flipSel}
        onClear={game.clearSel}
      />

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
