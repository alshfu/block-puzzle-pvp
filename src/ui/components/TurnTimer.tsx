interface Props {
  remaining: number;
  total: number;
  owner: 0 | 1;
  danger: boolean;
}

export function TurnTimer({ remaining, total, owner, danger }: Props) {
  const R = 26;
  const C = 2 * Math.PI * R;
  const frac = total > 0 && Number.isFinite(total)
    ? Math.max(0, Math.min(1, remaining / total))
    : 1;
  const display = Number.isFinite(remaining) ? Math.ceil(remaining) : "∞";
  return (
    <div className={"turn-timer " + (danger ? "danger" : "")}>
      <svg width="68" height="68" viewBox="0 0 68 68">
        <circle cx="34" cy="34" r={R} className="tt-track" />
        <circle
          cx="34"
          cy="34"
          r={R}
          className={"tt-fill owner" + owner}
          strokeDasharray={C}
          strokeDashoffset={C * (1 - frac)}
          transform="rotate(-90 34 34)"
        />
      </svg>
      <span className="tt-num">{display}</span>
    </div>
  );
}
