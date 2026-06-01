import { memo } from "react";
import type { PieceInstance } from "../../core";
import { MiniPiece } from "./MiniPiece";

interface Props {
  title: string;
  hint: string;
  hand: PieceInstance[];
  owner: 0 | 1;
  selId: string | null;
  deadIds: Set<string> | null;
  interactive: boolean;
  tone: "play" | "watch";
  onSelect?: (p: PieceInstance) => void;
}

function HandImpl({ title, hint, hand, owner, selId, deadIds, interactive, tone, onSelect }: Props) {
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
          return (
            <div
              key={piece.id}
              className={`hand-slot ${selected ? "sel" : ""} ${dead ? "dead" : ""}`}
              onClick={interactive && !dead ? () => onSelect?.(piece) : undefined}
            >
              <MiniPiece cells={piece.cells} owner={owner} cellSize={13} dead={dead} />
            </div>
          );
        })}
      </div>
    </div>
  );
}

export const Hand = memo(HandImpl);
