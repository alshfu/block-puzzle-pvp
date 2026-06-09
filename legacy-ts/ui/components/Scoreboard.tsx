import type { PieceInstance } from "../../core";
import { PlayerCard } from "./PlayerCard";
import { TurnTimer } from "./TurnTimer";

export interface PlayerSummary {
  score: number;
  combo: number;
}

export interface TimerSummary {
  remaining: number;
  perTurn: number;
}

interface Props {
  players: [PlayerSummary, PlayerSummary];
  names: [string, string];
  current: 0 | 1;
  status: "playing" | "over";
  timer: TimerSummary;
  /** Inline-руки в pcard. Если null/undefined — рука не показывается. */
  hands?: [PieceInstance[] | null, PieceInstance[] | null];
}

export function Scoreboard({ players, names, current, status, timer, hands }: Props) {
  let centerText = "игра окончена";
  if (status === "playing") {
    centerText = current === 0 ? "твой ход" : "ход соперника";
  }
  const danger = status === "playing" && Number.isFinite(timer.remaining) && timer.remaining <= 3;
  return (
    <div className="scoreboard">
      <PlayerCard
        name={names[0]}
        score={players[0].score}
        combo={players[0].combo}
        owner={0}
        active={status === "playing" && current === 0}
        side="left"
        miniHand={hands?.[0] ?? undefined}
      />
      <div className="turn-center">
        <div className={"turn-pill " + (danger ? "danger" : "")}>{centerText}</div>
        {Number.isFinite(timer.perTurn) ? (
          <TurnTimer remaining={timer.remaining} total={timer.perTurn} owner={current} danger={danger} />
        ) : (
          <div className={"turn-noclock owner" + current} title="Таймер отключён">∞</div>
        )}
      </div>
      <PlayerCard
        name={names[1]}
        score={players[1].score}
        combo={players[1].combo}
        owner={1}
        active={status === "playing" && current === 1}
        side="right"
        miniHand={hands?.[1] ?? undefined}
      />
    </div>
  );
}
