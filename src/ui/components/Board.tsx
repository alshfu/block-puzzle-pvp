import { forwardRef, memo } from "react";
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
  /** CSS-класс скина клеток. Default: "skin-default". */
  skinClass?: string;
  /** Если true — на доску вешается курсор pointer (desktop click-to-place). */
  hasSelection?: boolean;
}

const BoardImpl = forwardRef<HTMLDivElement, Props>(function BoardImpl(
  { board, ghost, flash, popups, skinClass = "skin-default", hasSelection = false }: Props,
  ref,
) {
  return (
    <div className="board-wrap">
      <div className={`board ${skinClass} ${hasSelection ? "has-selection" : ""}`} ref={ref}>
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
            return <div key={key} className={cls} />;
          })
        )}
      </div>
      <div className="box-sep vert v1" />
      <div className="box-sep vert v2" />
      <div className="box-sep horz h1" />
      <div className="box-sep horz h2" />
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
});

export const Board = memo(BoardImpl);
