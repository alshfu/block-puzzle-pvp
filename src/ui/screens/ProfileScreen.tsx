import { useState } from "react";
import { Button } from "../components/Button";
import { levelFromXp, xpInLevel, type Profile } from "../storage/profile";
import type { Stats } from "../storage/stats";

interface Props {
  profile: Profile;
  stats: Stats;
  onSave: (p: Profile) => void;
  onResetStats: () => void;
  onOpenAchievements: () => void;
  onBack: () => void;
}

const AVATARS = ["🙂", "😎", "🦊", "🐱", "🦄", "🐉", "🤖", "👾", "🧙", "🥷", "👑", "🌟"];

export function ProfileScreen({ profile, stats, onSave, onResetStats, onOpenAchievements, onBack }: Props) {
  const [nick, setNick] = useState(profile.nick);
  const [avatar, setAvatar] = useState(profile.avatar);
  const level = levelFromXp(profile.xp);
  const xpInL = xpInLevel(profile.xp);
  const winrate = stats.games > 0 ? Math.round((stats.wins / stats.games) * 100) : 0;
  const dirty = nick.trim() !== profile.nick || avatar !== profile.avatar;

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Профиль</div>
      </div>

      <div className="setup-body">
        <section className="setup-sec">
          <div className="sec-cap">Никнейм</div>
          <input
            className="text-input"
            value={nick}
            maxLength={20}
            onChange={(e) => setNick(e.target.value)}
          />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Аватар</div>
          <div className="avatar-grid">
            {AVATARS.map((a) => (
              <button
                key={a}
                className={`avatar-pick ${avatar === a ? "on" : ""}`}
                onClick={() => setAvatar(a)}
              >
                {a}
              </button>
            ))}
          </div>
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Уровень</div>
          <div className="lvl-row">
            <div className="lvl-num">ур. {level}</div>
            <div className="xp-bar">
              <div className="xp-fill" style={{ width: `${(xpInL.current / xpInL.needed) * 100}%` }} />
            </div>
            <div className="xp-num">
              {xpInL.current} / {xpInL.needed} XP
            </div>
          </div>
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Статистика</div>
          <div className="stats-grid">
            <Stat label="Партий" value={stats.games} />
            <Stat label="Побед" value={stats.wins} />
            <Stat label="Поражений" value={stats.losses} />
            <Stat label="Ничьих" value={stats.draws} />
            <Stat label="Винрейт" value={`${winrate}%`} />
            <Stat label="Рекорд" value={stats.bestScore} />
            <Stat label="Очисток всего" value={stats.totalClears} />
            <Stat label="Мульти-очистка" value={`×${stats.maxMultiClear}`} />
            <Stat label="Стрик сейчас" value={stats.currentWinStreak} />
            <Stat label="Лучший стрик" value={stats.bestWinStreak} />
            <Stat label="Онлайн матчей" value={stats.onlineGames} />
            <Stat label="Онлайн побед" value={stats.onlineWins} />
          </div>
          <button className="back-link" onClick={onResetStats}>
            сбросить статистику
          </button>
        </section>

        <section className="setup-sec">
          <button className="sec-btn ach-link" onClick={onOpenAchievements}>
            🏅 Ачивки →
          </button>
        </section>
      </div>

      <div className="setup-foot">
        <Button
          kind="primary"
          className="start-btn"
          disabled={!dirty || nick.trim().length === 0}
          onClick={() => onSave({ ...profile, nick: nick.trim(), avatar })}
        >
          Сохранить
        </Button>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="stat-tile">
      <div className="stat-val">{value}</div>
      <div className="stat-lbl">{label}</div>
    </div>
  );
}
