import { ACHIEVEMENTS, type AchievementDef } from "../achievements/definitions";
import type { PlayerAchievements } from "../storage/achievements";

interface Props {
  achievements: PlayerAchievements;
  onBack: () => void;
}

const CATEGORY_LABEL: Record<AchievementDef["category"], string> = {
  single: "Вехи",
  progressive: "Прогресс",
  series: "Серии побед",
  hidden: "Секреты",
};

export function AchievementsScreen({ achievements, onBack }: Props) {
  const grouped: Record<AchievementDef["category"], AchievementDef[]> = {
    single: [],
    progressive: [],
    series: [],
    hidden: [],
  };
  for (const a of ACHIEVEMENTS) grouped[a.category].push(a);

  const unlockedCount = Object.values(achievements).filter((p) => p.unlockedAt).length;

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Ачивки</div>
        <span className="mode-badge">
          {unlockedCount} / {ACHIEVEMENTS.length}
        </span>
      </div>

      <div className="setup-body">
        {(Object.keys(grouped) as AchievementDef["category"][]).map((cat) => (
          <section className="setup-sec" key={cat}>
            <div className="sec-cap">{CATEGORY_LABEL[cat]}</div>
            <div className="ach-list">
              {grouped[cat].map((a) => (
                <AchCard key={a.id} def={a} progress={achievements[a.id]} />
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}

function AchCard({
  def,
  progress,
}: {
  def: AchievementDef;
  progress?: { current: number; unlockedAt?: number };
}) {
  const unlocked = !!progress?.unlockedAt;
  const hidden = def.hidden && !unlocked;
  const cur = progress?.current ?? 0;
  const pct = Math.min(100, (cur / def.total) * 100);

  return (
    <div className={`ach-card ${unlocked ? "unlocked" : hidden ? "hidden" : ""}`}>
      <div className="ach-ico">{hidden ? "❓" : def.icon}</div>
      <div className="ach-text">
        <div className="ach-title">{hidden ? "???" : def.title}</div>
        <div className="ach-desc">
          {hidden ? "разблокируй, чтобы узнать" : def.description}
        </div>
        {!hidden && def.total > 1 && (
          <div className="ach-progress">
            <div className="ach-bar">
              <div className="ach-fill" style={{ width: `${pct}%` }} />
            </div>
            <span className="ach-num">
              {Math.min(cur, def.total)} / {def.total}
            </span>
          </div>
        )}
      </div>
      <div className="ach-xp">+{def.rewardXp}</div>
    </div>
  );
}
