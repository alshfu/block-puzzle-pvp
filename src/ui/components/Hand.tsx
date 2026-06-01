import { memo, useRef, type PointerEvent } from "react";
import type { Coord, PieceInstance } from "../../core";
import { MiniPiece } from "./MiniPiece";

interface Props {
  title: string;
  hint: string;
  hand: PieceInstance[];
  owner: 0 | 1;
  selId: string | null;
  /** Текущая (повёрнутая/отражённая) ориентация выбранной фигуры. Если задан — слот с selId перерисовывается с этими cells. */
  selCells?: Coord[] | null;
  deadIds: Set<string> | null;
  interactive: boolean;
  tone: "play" | "watch";
  /** Зовётся при pointerdown на фигуре. Если фигура уже выбрана — драг продолжается с её текущей ориентацией. */
  onPiecePointerDown?: (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => void;
  /** Зовётся при tap-без-перемещения (короткий клик), уже после pointerdown. Используется чтобы повернуть выбранную фигуру. */
  onPieceTap?: (piece: PieceInstance) => void;
}

function HandImpl({
  title,
  hint,
  hand,
  owner,
  selId,
  selCells,
  deadIds,
  interactive,
  tone,
  onPiecePointerDown,
  onPieceTap,
}: Props) {
  return (
    <div className={`hand owner${owner} ${tone}`}>
      <div className="hand-head">
        <span className="hand-title">{title}</span>
        <span className="hand-hint">{hint}</span>
      </div>
      <div className="hand-row">
        {hand.length === 0 && <span className="hand-empty">— пусто —</span>}
        {hand.map((piece) => {
          const dead = deadIds?.has(piece.id) ?? false;
          const selected = selId === piece.id;
          const displayCells = selected && selCells ? selCells : piece.cells;
          return (
            <PieceSlot
              key={piece.id}
              piece={piece}
              displayCells={displayCells}
              owner={owner}
              dead={dead}
              selected={selected}
              interactive={interactive && !dead}
              onPointerDown={onPiecePointerDown}
              onTap={onPieceTap}
            />
          );
        })}
      </div>
    </div>
  );
}

interface SlotProps {
  piece: PieceInstance;
  displayCells: Coord[];
  owner: 0 | 1;
  dead: boolean;
  selected: boolean;
  interactive: boolean;
  onPointerDown?: (piece: PieceInstance, e: PointerEvent<HTMLDivElement>) => void;
  onTap?: (piece: PieceInstance) => void;
}

function PieceSlot({ piece, displayCells, owner, dead, selected, interactive, onPointerDown, onTap }: SlotProps) {
  const downRef = useRef({ x: 0, y: 0, moved: false });
  if (!interactive) {
    return (
      <div className={`hand-slot ${selected ? "sel" : ""} ${dead ? "dead" : ""}`}>
        <MiniPiece cells={displayCells} owner={owner} cellSize={13} dead={dead} />
      </div>
    );
  }
  return (
    <div
      className={`hand-slot ${selected ? "sel" : ""}`}
      onPointerDown={(e) => {
        downRef.current.x = e.clientX;
        downRef.current.y = e.clientY;
        downRef.current.moved = false;
        onPointerDown?.(piece, e);
      }}
      onPointerMove={(e) => {
        const d = downRef.current;
        if (!d.moved && (Math.abs(e.clientX - d.x) > 6 || Math.abs(e.clientY - d.y) > 6)) {
          d.moved = true;
        }
      }}
      onPointerUp={() => {
        if (!downRef.current.moved) onTap?.(piece);
      }}
    >
      <MiniPiece cells={displayCells} owner={owner} cellSize={13} dead={dead} />
    </div>
  );
}

export const Hand = memo(HandImpl);
