import type { Coord } from "../../core";
import { MiniPiece } from "./MiniPiece";

interface Props {
  cells: Coord[];
  owner: 0 | 1;
  x: number;
  y: number;
  /** Сторона клетки доски (px) — чтобы plавающая фигура была того же масштаба. */
  cellPx: number;
  /** Если null — не подсвечиваем валидность; для UX используем подсветку на доске. */
  visible: boolean;
}

/**
 * Полупрозрачный «парящий» вид фигуры под курсором/пальцем во время drag.
 * Позиционируется фиксированно (viewport coords).
 */
export function DragLayer({ cells, owner, x, y, cellPx, visible }: Props) {
  if (!visible) return null;
  return (
    <div
      className="drag-layer"
      style={{
        position: "fixed",
        left: 0,
        top: 0,
        transform: `translate(${x}px, ${y}px) translate(-50%, -50%)`,
        pointerEvents: "none",
        zIndex: 60,
        opacity: 0.92,
      }}
    >
      <MiniPiece cells={cells} owner={owner} cellSize={cellPx} />
    </div>
  );
}
