import { useEffect, type RefObject } from "react";
import { SIZE, type Coord } from "../../core";

/**
 * Универсальная пара "click-to-place + hover-ghost" для доски.
 * Срабатывает только когда есть `sel` и НЕ активен drag (`dragActive=false`).
 *
 * Используется во всех игровых экранах после того как пользователь
 * "тапнул" фигуру в руке без перетаскивания — мышью можно сделать
 * hover по доске (ghost) и click для постановки.
 */
export interface UseBoardPointerOptions {
  boardRef: RefObject<HTMLDivElement | null>;
  cellPx: number;
  sel: { cells: Coord[] } | null;
  dragActive: boolean;
  /** Текущая доска нужна чтобы НЕ обновлять hover, если ничего не сделано (исключаем спам ререндеров). */
  enabled: boolean;
  onHover: (r: number, c: number) => void;
  onLeave: () => void;
  onPlace: (r: number, c: number) => void;
}

function clientToCell(
  el: HTMLDivElement,
  x: number,
  y: number,
  cells: Coord[],
  cellPx: number,
): { r: number; c: number } | null {
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

export function useBoardPointer({
  boardRef,
  cellPx,
  sel,
  dragActive,
  enabled,
  onHover,
  onLeave,
  onPlace,
}: UseBoardPointerOptions): void {
  useEffect(() => {
    const el = boardRef.current;
    if (!el) return;
    if (!enabled || !sel || dragActive) return;
    const handleMove = (e: PointerEvent) => {
      const cell = clientToCell(el, e.clientX, e.clientY, sel.cells, cellPx);
      if (cell) onHover(cell.r, cell.c);
      else onLeave();
    };
    const handleClick = (e: MouseEvent) => {
      const cell = clientToCell(el, e.clientX, e.clientY, sel.cells, cellPx);
      if (cell) onPlace(cell.r, cell.c);
    };
    const handleLeave = () => onLeave();
    el.addEventListener("pointermove", handleMove);
    el.addEventListener("pointerleave", handleLeave);
    el.addEventListener("click", handleClick);
    return () => {
      el.removeEventListener("pointermove", handleMove);
      el.removeEventListener("pointerleave", handleLeave);
      el.removeEventListener("click", handleClick);
    };
  }, [boardRef, cellPx, sel, dragActive, enabled, onHover, onLeave, onPlace]);
}
