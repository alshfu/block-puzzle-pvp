import type { Coord } from "../../core";

interface Props {
  cells: Coord[];
  owner?: 0 | 1;
  cellSize?: number;
  dead?: boolean;
}

export function MiniPiece({ cells, owner = 0, cellSize = 16, dead = false }: Props) {
  const maxR = Math.max(...cells.map((c) => c[0]));
  const maxC = Math.max(...cells.map((c) => c[1]));
  const rows = maxR + 1;
  const cols = maxC + 1;
  const set = new Set(cells.map(([r, c]) => `${r},${c}`));
  return (
    <div
      className="mini-piece"
      style={{
        display: "grid",
        gridTemplateColumns: `repeat(${cols}, ${cellSize}px)`,
        gridTemplateRows: `repeat(${rows}, ${cellSize}px)`,
        gap: 3,
        opacity: dead ? 0.32 : 1,
        filter: dead ? "grayscale(0.6)" : "none",
      }}
    >
      {Array.from({ length: rows * cols }).map((_, i) => {
        const r = Math.floor(i / cols);
        const c = i % cols;
        const on = set.has(`${r},${c}`);
        return <span key={i} className={on ? `mini-cell filled owner${owner}` : "mini-cell"} />;
      })}
    </div>
  );
}
