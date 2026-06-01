import { memo } from "react";
import { SIZE, type Board as BoardType } from "../../core";

export interface Ghost {
  map: Map<string, "good" | "bad">;
}

export interface ScorePopup {
  id: number;
  r: number;
  c: number;
  owner: 0 | 1;
  text: string;
}

interface Props {
  board: BoardType;
  ghost: Ghost | null;
  flash: Set<string> | null;
  popups: ScorePopup[];
  interactive: boolean;
  onHover: (r: number, c: number) => void;
  onLeave: () => void;
  onPlace: (r: number, c: number) => void;
}

function BoardImpl({ board, ghost, flash, popups, interactive, onHover, onLeave, onPlace }: Props) {
  return (
    <div className="board-wrap">
      <div className="board" onMouseLeave={onLeave}>
        {board.map((row, r) =>
          row.map((cell, c) => {
            const key = `${r},${c}`;
            const gh = ghost?.map.get(key);
            const isFlash = flash?.has(key) ?? false;
            let cls = "cell";
            if (cell.filled) cls += " filled owner" + cell.owner;
            if (gh === "good") cls += " ghost-good";
            else if (gh === "bad") cls += " ghost-bad";
            if (isFlash) cls += " flash";
            return (
              <div
                key={key}
                className={cls}
                onMouseEnter={interactive ? () => onHover(r, c) : undefined}
                onClick={interactive ? () => onPlace(r, c) : undefined}
              />
            );
          })
        )}
      </div>
      <div className="box-sep vert" style={{ left: "33.33%" }} />
      <div className="box-sep vert" style={{ left: "66.66%" }} />
      <div className="box-sep horz" style={{ top: "33.33%" }} />
      <div className="box-sep horz" style={{ top: "66.66%" }} />
      {popups.map((p) => (
        <div
          key={p.id}
          className={"score-pop owner" + p.owner}
          style={{
            left: `${((p.c + 0.5) / SIZE) * 100}%`,
            top: `${((p.r + 0.5) / SIZE) * 100}%`,
          }}
        >
          {p.text}
        </div>
      ))}
    </div>
  );
}

export const Board = memo(BoardImpl);
