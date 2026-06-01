interface Props {
  name: string;
  score: number;
  combo: number;
  owner: 0 | 1;
  active: boolean;
  side: "left" | "right";
}

export function PlayerCard({ name, score, combo, owner, active, side }: Props) {
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
    </div>
  );
}
