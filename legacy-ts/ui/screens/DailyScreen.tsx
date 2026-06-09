import { QUEST_BY_ID } from "../daily/definitions";
import type { DailyState, QuestProgress } from "../storage/daily";

interface Props {
  daily: DailyState;
  coins: number;
  onClaim: (defId: string) => void;
  onBack: () => void;
}

export function DailyScreen({ daily, coins, onClaim, onBack }: Props) {
  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Дейли</div>
        <span className="coin-chip read-only">
          <span className="coin-icon">🪙</span>
          <span className="coin-amount">{coins}</span>
        </span>
      </div>

      <div className="setup-body">
        <section className="setup-sec">
          <div className="sec-cap">Задания на сегодня · {daily.date}</div>
          <div className="ach-list">
            {daily.quests.map((q) => (
              <QuestCard key={q.defId} q={q} onClaim={() => onClaim(q.defId)} />
            ))}
          </div>
        </section>
        <section className="setup-sec">
          <div className="ach-card">
            <div className="ach-ico">⏱</div>
            <div className="ach-text">
              <div className="ach-title">Новый набор завтра</div>
              <div className="ach-desc">3 случайных задания пересоздаются ежедневно в полночь по локальному времени.</div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function QuestCard({ q, onClaim }: { q: QuestProgress; onClaim: () => void }) {
  const def = QUEST_BY_ID[q.defId];
  if (!def) return null;
  const pct = Math.min(100, (q.current / def.target) * 100);
  const canClaim = q.completed && !q.claimed;
  return (
    <div className={`ach-card ${q.completed ? "unlocked" : ""}`}>
      <div className="ach-ico">{def.icon}</div>
      <div className="ach-text">
        <div className="ach-title">{def.title}</div>
        <div className="ach-desc">{def.description}</div>
        <div className="ach-progress">
          <div className="ach-bar">
            <div className="ach-fill" style={{ width: `${pct}%` }} />
          </div>
          <span className="ach-num">
            {Math.min(q.current, def.target)} / {def.target}
          </span>
        </div>
      </div>
      <div className="shop-action">
        {q.claimed ? (
          <span className="shop-status equipped">получено</span>
        ) : canClaim ? (
          <button className="resume-btn primary" onClick={onClaim}>
            🪙 +{def.reward}
          </button>
        ) : (
          <span className="ach-xp">+{def.reward}</span>
        )}
      </div>
    </div>
  );
}
