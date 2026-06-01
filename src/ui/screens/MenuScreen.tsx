import { useState } from "react";
import { BASE_SHAPES, type PieceType } from "../../core";
import { Button } from "../components/Button";
import { Logo } from "../components/Logo";
import { MiniPiece } from "../components/MiniPiece";
import { ThemeSwitch } from "../components/ThemeSwitch";
import type { ThemeId } from "../themes";
import type { SavedGame } from "../storage/saveGame";

export type GameMode = "bot" | "hotseat" | "botvbot";

export interface Profile {
  nick: string;
  avatar: string;
  level: number;
}

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  onStart: (mode: GameMode) => void;
  onResume: () => void;
  onDiscardSave: () => void;
  onOpenProfile: () => void;
  onOpenSettings: () => void;
  profile: Profile;
  savedGame: SavedGame | null;
}

export function MenuScreen({
  theme,
  setTheme,
  onStart,
  onResume,
  onDiscardSave,
  onOpenProfile,
  onOpenSettings,
  profile,
  savedGame,
}: Props) {
  const [modeOpen, setModeOpen] = useState(false);

  return (
    <div className="screen menu-screen">
      <div className="menu-top">
        <button className="avatar-chip" onClick={onOpenProfile}>
          <span className="avatar-face">{profile.avatar}</span>
          <span className="avatar-meta">
            <span className="avatar-nick">{profile.nick}</span>
            <span className="avatar-lvl">ур. {profile.level}</span>
          </span>
        </button>
        <span className="mode-badge">mvp · ts core</span>
      </div>

      <div className="menu-hero">
        <Logo size="big" />
        <div className="menu-tagline">дуэль на поле 9×9 · ставь, очищай, побеждай</div>
        <MiniDeco />
      </div>

      <div className="menu-actions">
        {savedGame && !modeOpen && (
          <ResumeCard saved={savedGame} onResume={onResume} onDiscard={onDiscardSave} />
        )}

        {!modeOpen ? (
          <Button kind="primary" className="hero-btn" onClick={() => setModeOpen(true)}>
            ▶ Играть
          </Button>
        ) : (
          <div className="mode-list">
            <Button kind="primary" className="mode-btn" onClick={() => onStart("bot")}>
              <span className="mode-ico">🤖</span>
              <span className="mode-txt">
                <b>С ботом</b>
                <i>быстрая партия против ИИ</i>
              </span>
            </Button>
            <Button kind="ghost" className="mode-btn" owner={1} onClick={() => onStart("hotseat")}>
              <span className="mode-ico">👥</span>
              <span className="mode-txt">
                <b>Вдвоём</b>
                <i>hot-seat на одном устройстве</i>
              </span>
            </Button>
            <Button kind="ghost" className="mode-btn" onClick={() => onStart("botvbot")}>
              <span className="mode-ico">🎬</span>
              <span className="mode-txt">
                <b>Бот × бот</b>
                <i>смотри как ИИ играет с ИИ</i>
              </span>
            </Button>
            <button className="mode-btn ghost-mode" disabled>
              <span className="mode-ico">🌐</span>
              <span className="mode-txt">
                <b>Онлайн</b>
                <i>скоро</i>
              </span>
            </button>
            <button className="back-link" onClick={() => setModeOpen(false)}>
              ← назад
            </button>
          </div>
        )}
        {!modeOpen && (
          <div className="menu-secondary">
            <button className="sec-btn" onClick={onOpenProfile}>Профиль</button>
            <button className="sec-btn" disabled>Ачивки</button>
            <button className="sec-btn" onClick={onOpenSettings}>Настройки</button>
          </div>
        )}
      </div>

      <div className="menu-foot">
        <ThemeSwitch theme={theme} setTheme={setTheme} />
        <div className="version">v0.1 · mvp</div>
      </div>
    </div>
  );
}

function MiniDeco() {
  const demo: PieceType[] = ["T", "L", "S", "O", "I"];
  return (
    <div className="mini-deco">
      {demo.map((t, i) => (
        <MiniPiece key={i} cells={BASE_SHAPES[t]} owner={(i % 2) as 0 | 1} cellSize={11} />
      ))}
    </div>
  );
}

function ResumeCard({
  saved,
  onResume,
  onDiscard,
}: {
  saved: SavedGame;
  onResume: () => void;
  onDiscard: () => void;
}) {
  const modeLabel = saved.mode === "bot" ? `vs bot · ${saved.botLevel}` : "hot-seat";
  return (
    <div className="resume-card">
      <div className="resume-text">
        <div className="resume-title">Продолжить партию</div>
        <div className="resume-sub">
          {modeLabel} · счёт {saved.players[0].score}:{saved.players[1].score}
        </div>
      </div>
      <div className="resume-actions">
        <button className="resume-btn primary" onClick={onResume}>
          ▶
        </button>
        <button className="resume-btn" onClick={onDiscard}>
          ✕
        </button>
      </div>
    </div>
  );
}
