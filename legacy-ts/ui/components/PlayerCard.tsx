import type { PieceInstance } from "../../core";
import { MiniPiece } from "./MiniPiece";

interface Props {
  name: string;
  score: number;
  combo: number;
  owner: 0 | 1;
  active: boolean;
  side: "left" | "right";
  /** Если задано — компактная inline-рука этого игрока (показывается рядом со счётом). */
  miniHand?: PieceInstance[];
}

export function PlayerCard({ name, score, combo, owner, active, side, miniHand }: Props) {
  return (
    <div className={`pcard owner${owner} ${active ? "active" : ""} ${side}`}>
      <div className="pcard-label">
        {owner === 0 ? (
          <>
            <span className="dot" /> {name}
          </>
        ) : (
          <>
            {name} <span className="dot" />
          </>
        )}
      </div>
      <div className="pcard-score">{score}</div>
      <div className="pcard-combo" style={{ visibility: combo > 1 ? "visible" : "hidden" }}>
        комбо ×{combo}
      </div>
      {miniHand && miniHand.length > 0 && (
        <div className="pcard-hand">
          {miniHand.map((p) => (
            <MiniPiece key={p.id} cells={p.cells} owner={owner} cellSize={6} />
          ))}
        </div>
      )}
    </div>
  );
}
