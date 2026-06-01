import { useEffect, useMemo, useRef, useState, type PointerEvent } from "react";
import {
  applyClears,
  canPlace,
  cloneBoard,
  DEFAULT_CONFIG,
  findClears,
  flipH,
  hasAnyMove,
  isPerfectClear,
  normalize,
  pieceHasMove,
  place,
  rotate90,
  SIZE,
  type Board as BoardType,
  type Coord,
  type PieceInstance,
} from "../../core";
import { Board } from "../components/Board";
import { Button } from "../components/Button";
import { DragLayer } from "../components/DragLayer";
import { Hand } from "../components/Hand";
import { Logo } from "../components/Logo";
import { TransformControls } from "../components/TransformControls";
import { TUTORIAL_REWARD_COINS, TUTORIAL_STEPS } from "../tutorial/steps";

interface Props {
  /** Класс активного скина клеток. */
  skinClass?: string;
  onExit: () => void;
  /** Зовётся ровно один раз когда последний шаг пройден. */
  onCompleted: () => void;
}

interface Selection {
  pieceId: string;
  cells: Coord[];
}

interface DragState {
  piece: PieceInstance;
  pointerId: number;
  x: number;
  y: number;
  active: boolean;
}

const DRAG_THRESHOLD_PX = 6;

export function TutorialScreen({ skinClass, onExit, onCompleted }: Props) {
  const cfg = DEFAULT_CONFIG;
  const [stepIdx, setStepIdx] = useState(0);
  const step = TUTORIAL_STEPS[stepIdx];

  const [board, setBoard] = useState<BoardType>(() => step.buildBoard());
  const [hand, setHand] = useState<PieceInstance[]>(() => step.buildHand());
  const [comboInStep, setComboInStep] = useState(0);
  const [doneStep, setDoneStep] = useState(false);
  const [statusMsg, setStatusMsg] = useState(step.hint);
  const completedRef = useRef(false);

  // Перезагружаем доску и руку при смене шага.
  useEffect(() => {
    setBoard(step.buildBoard());
    setHand(step.buildHand());
    setComboInStep(0);
    setDoneStep(false);
    setStatusMsg(step.hint);
  }, [stepIdx, step]);

  // ─── drag / sel state ──────────────────────────────────────────────────
  const [sel, setSel] = useState<Selection | null>(null);
  const [hover, setHover] = useState<{ r: number; c: number } | null>(null);
  const [drag, setDrag] = useState<DragState | null>(null);
  const dragRef = useRef<DragState | null>(null);
  dragRef.current = drag;
  const lastHoverRef = useRef<{ r: number; c: number } | null>(null);
  const [shaking, setShaking] = useState(false);

  const boardRef = useRef<HTMLDivElement | null>(null);
  const [cellPx, setCellPx] = useState<number>(36);
  useEffect(() => {
    const update = () => {
      const el = boardRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
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

  function clientToCell(x: number, y: number, cells: Coord[]): { r: number; c: number } | null {
    const el = boardRef.current;
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    const PAD = 9;
    const GAP = 3;
    const step2 = cellPx + GAP;
    const localX = x - rect.left - PAD;
    const localY = y - rect.top - PAD;
    const pc = Math.floor(localX / step2);
    const pr = Math.floor(localY / step2);
    if (pr < 0 || pr >= SIZE || pc < 0 || pc >= SIZE) return null;
    const maxR = Math.max(...cells.map((c2) => c2[0]));
    const maxC = Math.max(...cells.map((c2) => c2[1]));
    const offR = Math.round(maxR / 2);
    const offC = Math.round(maxC / 2);
    let r = pr - offR;
    let c = pc - offC;
    if (r < 0 || c < 0 || r + maxR >= SIZE || c + maxC >= SIZE) {
      r = Math.max(0, Math.min(r, SIZE - 1 - maxR));
      c = Math.max(0, Math.min(c, SIZE - 1 - maxC));
    }
    return { r, c };
  }

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
        const cellsToUse = sel?.cells ?? d.piece.cells;
        const cell = clientToCell(e.clientX, e.clientY, cellsToUse);
        if (cell) {
          lastHoverRef.current = cell;
          setHover(cell);
        } else {
          lastHoverRef.current = null;
          setHover(null);
        }
      }
    };
    const onUp = (e: globalThis.PointerEvent) => {
      const d = dragRef.current;
      if (!d || e.pointerId !== d.pointerId) return;
      if (d.active && sel) {
        const cell = lastHoverRef.current;
        if (cell && canPlace(board, sel.cells, cell.r, cell.c)) {
          applyPlayerMove(sel.pieceId, sel.cells, cell.r, cell.c);
        } else {
          setShaking(true);
          setStatusMsg("Сюда не помещается");
          setTimeout(() => setShaking(false), 320);
        }
        setSel(null);
      } else if (!d.active) {
        // tap — оставляем selected (для rotate-tap)
      }
      lastHoverRef.current = null;
      setDrag(null);
      setHover(null);
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [drag, sel, board, cellPx]);

  function applyPlayerMove(pieceId: string, cells: Coord[], r: number, c: number) {
    if (doneStep) return;
    const newBoard = cloneBoard(board);
    place(newBoard, cells, r, c, 0);
    const cl = findClears(newBoard);
    let combo = comboInStep;
    if (cl.count > 0) {
      applyClears(newBoard, cl.cleared);
      combo += 1;
    } else {
      combo = 0;
    }
    setBoard(newBoard);
    setHand((h) => h.filter((p) => p.id !== pieceId));
    setComboInStep(combo);

    const boardEmpty = isPerfectClear(newBoard);
    if (
      step.isGoalMet({
        clearsCount: cl.count,
        combo,
        boardEmptyAfter: boardEmpty,
      })
    ) {
      setDoneStep(true);
      setStatusMsg("✓ Готово! Жми «Дальше».");
    } else if (!hasAnyMove(newBoard, hand.filter((p) => p.id !== pieceId), cfg)) {
      // ходов не осталось, цель не достигнута — даём шанс перезапустить шаг
      setStatusMsg("Не вышло. Жми «Заново», чтобы попробовать снова.");
    } else {
      if (cl.count > 0) setStatusMsg(`Очистка! Продолжай (${step.hint}).`);
      else setStatusMsg(step.hint);
    }
  }

  // ─── derived: ghost, dead ──────────────────────────────────────────────
  const ghost = useMemo(() => {
    if (!sel || !hover) return null;
    const { r, c } = hover;
    const ok = canPlace(board, sel.cells, r, c);
    const map = new Map<string, "good" | "bad">();
    for (const [dr, dc] of sel.cells) {
      const rr = r + dr;
      const cc = c + dc;
      if (rr >= 0 && rr < SIZE && cc >= 0 && cc < SIZE && !board[rr][cc].filled) {
        map.set(`${rr},${cc}`, ok ? "good" : "bad");
      }
    }
    return { map };
  }, [board, sel, hover]);

  const deadIds = useMemo(() => {
    const s = new Set<string>();
    for (const piece of hand) {
      if (!pieceHasMove(board, piece, cfg)) s.add(piece.id);
    }
    return s;
  }, [board, hand, cfg]);

  // ─── handlers ──────────────────────────────────────────────────────────
  const handlePiecePointerDown = (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => {
    if (doneStep) return;
    setSel({ pieceId: piece.id, cells: normalize(piece.cells) });
    setDrag({ piece, pointerId: e.pointerId, x: e.clientX, y: e.clientY, active: false });
  };
  const handlePieceTap = (piece: PieceInstance) => {
    if (doneStep) return;
    if (sel?.pieceId === piece.id) {
      setSel({ ...sel, cells: rotate90(sel.cells) });
    } else {
      setSel({ pieceId: piece.id, cells: normalize(piece.cells) });
    }
  };
  const handleRotate = () => sel && setSel({ ...sel, cells: rotate90(sel.cells) });
  const handleFlip = () => sel && setSel({ ...sel, cells: flipH(sel.cells) });
  const handleClearSel = () => setSel(null);
  const handleNext = () => {
    if (stepIdx + 1 >= TUTORIAL_STEPS.length) {
      if (!completedRef.current) {
        completedRef.current = true;
        onCompleted();
      }
      onExit();
    } else {
      setStepIdx((i) => i + 1);
    }
  };
  const handleRetry = () => {
    setBoard(step.buildBoard());
    setHand(step.buildHand());
    setComboInStep(0);
    setDoneStep(false);
    setStatusMsg(step.hint);
    setSel(null);
  };

  // hotkeys
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const k = e.key.toLowerCase();
      if (k === "r" || k === "к") handleRotate();
      else if (k === "f" || k === "а") handleFlip();
      else if (k === "escape") handleClearSel();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sel]);

  const pct = ((stepIdx + (doneStep ? 1 : 0)) / TUTORIAL_STEPS.length) * 100;

  return (
    <div className={"screen game-screen " + (shaking ? "shake" : "")}>
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">обучение · {stepIdx + 1} / {TUTORIAL_STEPS.length}</span>
        <button className="pause-btn" onClick={onExit}>
          ←
        </button>
      </div>

      <div className="tut-progress">
        <div className="tut-progress-fill" style={{ width: `${pct}%` }} />
      </div>

      <div className="tut-card">
        <div className="tut-title">{step.title}</div>
        <div className="tut-desc">{step.description}</div>
      </div>

      <Board
        ref={boardRef}
        board={board}
        ghost={ghost}
        flash={null}
        popups={[]}
        skinClass={skinClass}
      />

      <div className="status-bar">{statusMsg}</div>

      <Hand
        title="Твоя рука"
        hint={doneStep ? "шаг пройден" : "перетащи фигуру на доску"}
        hand={hand}
        owner={0}
        selId={sel?.pieceId ?? null}
        deadIds={deadIds}
        interactive={!doneStep}
        tone="play"
        onPiecePointerDown={!doneStep ? handlePiecePointerDown : undefined}
        onPieceTap={!doneStep ? handlePieceTap : undefined}
      />

      <TransformControls
        hasSelection={!!sel}
        cfg={cfg}
        onRotate={handleRotate}
        onFlip={handleFlip}
        onClear={handleClearSel}
      />

      {drag?.active && sel && (
        <DragLayer cells={sel.cells} owner={0} x={drag.x} y={drag.y} cellPx={cellPx} visible />
      )}

      <div className="tut-actions">
        {doneStep ? (
          <Button kind="primary" className="start-btn" onClick={handleNext}>
            {stepIdx + 1 === TUTORIAL_STEPS.length
              ? `🪙 Завершить · +${TUTORIAL_REWARD_COINS}`
              : "Дальше →"}
          </Button>
        ) : (
          <button className="back-link" onClick={handleRetry}>
            ↻ Заново
          </button>
        )}
      </div>
    </div>
  );
}
