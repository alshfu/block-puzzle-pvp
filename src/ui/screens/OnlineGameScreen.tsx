import { useEffect, useMemo, useRef, useState, type PointerEvent } from "react";
import {
  canPlace,
  DEFAULT_CONFIG,
  flipH,
  hasAnyMove,
  normalize,
  rotate90,
  SIZE,
  type Coord,
  type PieceInstance,
} from "../../core";
import type { OnlineProfile } from "../../../party/protocol";
import { Board } from "../components/Board";
import { DragLayer } from "../components/DragLayer";
import { Hand } from "../components/Hand";
import { Logo } from "../components/Logo";
import { Scoreboard } from "../components/Scoreboard";
import { TransformControls } from "../components/TransformControls";
import { useBoardPointer } from "../hooks/useBoardPointer";
import { useOnlineGame } from "../online/useOnlineGame";
import { ResultOverlay } from "./ResultOverlay";
import type { ThemeId } from "../themes";

interface Props {
  theme: ThemeId;
  roomId: string;
  profile: OnlineProfile;
  opponent: OnlineProfile;
  onExit: () => void;
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

export function OnlineGameScreen({ theme, roomId, profile, opponent, onExit }: Props) {
  const { state: onlineState, sendMove, resign } = useOnlineGame(roomId, profile);

  const cfg = DEFAULT_CONFIG; // онлайн фиксирует конфиг сервера; без таймера
  const [sel, setSel] = useState<Selection | null>(null);
  const [hover, setHover] = useState<{ r: number; c: number } | null>(null);
  const [drag, setDrag] = useState<DragState | null>(null);
  const dragRef = useRef<DragState | null>(null);
  dragRef.current = drag;
  const lastHoverRef = useRef<{ r: number; c: number } | null>(null);

  const [shaking, setShaking] = useState(false);
  useEffect(() => {
    if (onlineState.rejectTick === 0) return;
    setShaking(true);
    const t = setTimeout(() => setShaking(false), 320);
    return () => clearTimeout(t);
  }, [onlineState.rejectTick]);

  const board = onlineState.state?.board ?? null;
  const you = onlineState.you;
  const myTurn =
    !!onlineState.state &&
    onlineState.state.status === "playing" &&
    you !== null &&
    onlineState.state.current === you;

  const youView = onlineState.state && you !== null ? onlineState.state.players[you] : null;
  const oppIdx: 0 | 1 | null = you !== null ? ((1 - you) as 0 | 1) : null;
  const oppView = onlineState.state && oppIdx !== null ? onlineState.state.players[oppIdx] : null;

  const names = useMemo<[string, string]>(
    () => [profile.nick, opponent.nick],
    [profile.nick, opponent.nick],
  );

  // ─── derived: ghost, deadIds ───────────────────────────────────────────
  const ghost = useMemo(() => {
    if (!board || !sel || !hover) return null;
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
    if (!board || !youView) return new Set<string>();
    const s = new Set<string>();
    for (const piece of youView.hand) {
      if (!hasAnyMove(board, [piece], cfg)) s.add(piece.id);
    }
    return s;
  }, [board, youView, cfg]);

  // ─── drag-and-drop координаты доски ────────────────────────────────────
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
    const step = cellPx + GAP;
    const localX = x - rect.left - PAD;
    const localY = y - rect.top - PAD;
    const pc = Math.floor(localX / step);
    const pr = Math.floor(localY / step);
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
      if (d.active && sel && board) {
        const cell = lastHoverRef.current;
        if (cell && canPlace(board, sel.cells, cell.r, cell.c)) {
          sendMove(sel.pieceId, sel.cells, cell.r, cell.c);
          setSel(null);
        } else {
          setSel(null);
        }
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
  }, [drag, sel, board, cellPx, sendMove]);

  // desktop fallback
  useBoardPointer({
    boardRef,
    cellPx,
    sel,
    dragActive: !!drag?.active,
    enabled: myTurn,
    onHover: (r, c) => setHover((h) => (h?.r === r && h?.c === c ? h : { r, c })),
    onLeave: () => setHover(null),
    onPlace: (r, c) => {
      if (sel && board && canPlace(board, sel.cells, r, c)) {
        sendMove(sel.pieceId, sel.cells, r, c);
        setSel(null);
      }
    },
  });

  const handlePiecePointerDown = (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => {
    if (!myTurn) return;
    setSel({ pieceId: piece.id, cells: normalize(piece.cells) });
    setDrag({ piece, pointerId: e.pointerId, x: e.clientX, y: e.clientY, active: false });
  };

  const handlePieceTap = (piece: PieceInstance) => {
    if (!myTurn) return;
    if (sel?.pieceId === piece.id && cfg.rotationEnabled) {
      setSel({ ...sel, cells: rotate90(sel.cells) });
    } else {
      setSel({ pieceId: piece.id, cells: normalize(piece.cells) });
    }
  };

  // ─── ResultOverlay → outcome ───────────────────────────────────────────
  const result =
    onlineState.state?.status === "over" && onlineState.state.result
      ? { winner: remapWinner(onlineState.state.result.winner, you), scores: orderScores(onlineState.state.result.scores, you) }
      : null;

  // ─── рендер ────────────────────────────────────────────────────────────
  if (!onlineState.state || you === null || !youView || !oppView) {
    return (
      <div className="screen game-screen">
        <div className="game-head">
          <Logo size="mini" />
          <span className="mode-badge">online</span>
          <button className="pause-btn" onClick={() => { resign(); onExit(); }}>
            ←
          </button>
        </div>
        <div className="status-bar">
          {onlineState.connected ? "Ждём оппонента…" : "Подключение…"}
        </div>
      </div>
    );
  }

  const youDisplay = { score: youView.score, combo: youView.combo };
  const oppDisplay = { score: oppView.score, combo: oppView.combo };

  return (
    <div className={"screen game-screen " + (shaking ? "shake" : "")}>
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">online · vs {opponent.nick}</span>
        <button className="pause-btn" onClick={() => { resign(); onExit(); }}>
          ⏏
        </button>
      </div>

      <Scoreboard
        players={[youDisplay, oppDisplay]}
        names={names}
        current={(you === onlineState.state.current ? 0 : 1) as 0 | 1}
        status={onlineState.state.status}
        timer={{ remaining: Infinity, perTurn: Infinity }}
      />

      <Hand
        title={`${opponent.nick}${onlineState.opponentLeft ? " (отвалился…)" : ""}`}
        hint={onlineState.state.current === oppIdx ? "ходит" : "ждёт"}
        hand={oppView.hand}
        owner={1}
        selId={null}
        deadIds={null}
        interactive={false}
        tone="watch"
      />

      <Board
        ref={boardRef}
        board={onlineState.state.board}
        ghost={ghost}
        flash={null}
        popups={[]}
        hasSelection={!!sel}
      />

      <div className="status-bar">
        {onlineState.opponentLeft
          ? `${opponent.nick} отвалился — ждём 30с реконнекта…`
          : myTurn
            ? "Твой ход — перетащи фигуру"
            : `Ходит ${opponent.nick}…`}
      </div>

      <Hand
        title="Твоя рука"
        hint={myTurn ? "перетащи на доску" : "ждёт хода"}
        hand={youView.hand}
        owner={0}
        selId={sel?.pieceId ?? null}
        selCells={sel?.cells ?? null}
        deadIds={myTurn ? deadIds : null}
        interactive={myTurn}
        tone="play"
        onPiecePointerDown={myTurn ? handlePiecePointerDown : undefined}
        onPieceTap={myTurn ? handlePieceTap : undefined}
      />

      <TransformControls
        hasSelection={!!sel}
        cfg={cfg}
        onRotate={() => sel && setSel({ ...sel, cells: rotate90(sel.cells) })}
        onFlip={() => sel && setSel({ ...sel, cells: flipH(sel.cells) })}
        onClear={() => setSel(null)}
      />

      {drag?.active && sel && (
        <DragLayer
          cells={sel.cells}
          owner={0}
          x={drag.x}
          y={drag.y}
          cellPx={cellPx}
          visible
        />
      )}

      <ResultOverlay
        result={result}
        names={names}
        theme={theme}
        xp={0}
        onRematch={onExit}
        onMenu={onExit}
      />
    </div>
  );
}

/** Конвертирует winner-индекс с server perspective (0/1) в "мою" (0 = ты, 1 = соперник). */
function remapWinner(winner: 0 | 1 | -1, you: 0 | 1 | null): 0 | 1 | -1 {
  if (winner === -1 || you === null) return winner;
  return (winner === you ? 0 : 1) as 0 | 1;
}

function orderScores(scores: [number, number], you: 0 | 1 | null): [number, number] {
  if (you === null) return scores;
  return [scores[you], scores[1 - you]];
}
