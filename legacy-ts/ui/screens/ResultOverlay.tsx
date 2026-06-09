import { Button } from "../components/Button";
import { Mascot } from "../components/Mascot";
import type { ThemeId } from "../themes";

export interface MatchResult {
  winner: 0 | 1 | -1;
  scores: [number, number];
}

export interface ScoreBreakdown {
  base: number;
  combo: number;
  perfect: number;
}

interface Props {
  result: MatchResult | null;
  names: [string, string];
  breakdown?: ScoreBreakdown;
  xp: number;
  /** Текущий стрик после партии (после applyMatchToStats). */
  streak?: number;
  /** Лучший стрик до партии — чтобы понять, побит ли он. */
  prevBestStreak?: number;
  theme?: ThemeId;
  /** Online: ты уже нажал «Реванш». */
  rematchYours?: boolean;
  /** Online: соперник уже нажал «Реванш». */
  rematchTheirs?: boolean;
  onRematch: () => void;
  onMenu: () => void;
}

export function ResultOverlay({
  result,
  names,
  breakdown,
  xp,
  streak = 0,
  prevBestStreak = 0,
  theme = "neutral",
  rematchYours,
  rematchTheirs,
  onRematch,
  onMenu,
}: Props) {
  if (!result) return null;
  const { winner, scores } = result;
  let title: string;
  let cls: string;
  let emo: string;
  if (winner === 0) {
    title = `${names[0]} победил`;
    cls = "win owner0";
    emo = "🏆";
  } else if (winner === 1) {
    title = `${names[1]} победил`;
    cls = "lose owner1";
    emo = "🥇";
  } else {
    title = "Ничья";
    cls = "draw";
    emo = "🤝";
  }
  const showStreak = winner === 0 && streak >= 3;
  const isPersonalRecord = winner === 0 && streak > prevBestStreak && streak >= 3;
  return (
    <div className="overlay">
      <div className={`result-card ${cls}`}>
        {showStreak && (
          <div className={`streak-banner ${isPersonalRecord ? "record" : ""}`}>
            <div className="streak-mascot">
              <Mascot theme={theme} size={64} />
            </div>
            <div className="streak-text">
              <div className="streak-title">
                {isPersonalRecord ? "Новый личный рекорд!" : `${streak} побед подряд!`}
              </div>
              <div className="streak-sub">
                {isPersonalRecord
                  ? `${streak} подряд — больше, чем когда-либо`
                  : `Лучший: ${Math.max(prevBestStreak, streak)}`}
              </div>
            </div>
          </div>
        )}
        <div className="result-emo">{emo}</div>
        <div className="result-title">{title}</div>
        <div className="result-sub">ходы кончились</div>
        <div className="result-scores">
          <div className="rs owner0">
            <span>{names[0]}</span>
            <b>{scores[0]}</b>
          </div>
          <div className="rs-vs">:</div>
          <div className="rs owner1">
            <span>{names[1]}</span>
            <b>{scores[1]}</b>
          </div>
        </div>
        {breakdown && (breakdown.base > 0 || breakdown.combo > 0 || breakdown.perfect > 0) && (
          <div className="breakdown">
            <div className="bd-row">
              <span>База</span>
              <b>{breakdown.base}</b>
            </div>
            {breakdown.combo > 0 && (
              <div className="bd-row">
                <span>Комбо</span>
                <b>+{breakdown.combo}</b>
              </div>
            )}
            {breakdown.perfect > 0 && (
              <div className="bd-row">
                <span>Perfect</span>
                <b>+{breakdown.perfect}</b>
              </div>
            )}
          </div>
        )}
        <div className="result-xp">
          <span>+{xp} XP</span>
          <div className="xp-bar">
            <div className="xp-fill" style={{ width: "62%" }} />
          </div>
        </div>
        <div className="result-actions">
          <Button kind="primary" onClick={onRematch}>
            {rematchYours === undefined
              ? "Реванш"
              : rematchYours && rematchTheirs
                ? "Запуск…"
                : rematchYours
                  ? "Жду соперника…"
                  : rematchTheirs
                    ? "Соперник хочет реванш"
                    : "Реванш"}
          </Button>
          <Button kind="ghost" onClick={onMenu}>
            В меню
          </Button>
        </div>
      </div>
    </div>
  );
}
