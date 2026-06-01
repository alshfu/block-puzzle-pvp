import { useState } from "react";
import { BASE_SHAPES, type PieceType } from "../../core";
import { Button } from "../components/Button";
import { Logo } from "../components/Logo";
import { MiniPiece } from "../components/MiniPiece";
import { ThemeSwitch } from "../components/ThemeSwitch";
import type { ThemeId } from "../themes";

export type GameMode = "bot" | "hotseat";

export interface Profile {
  nick: string;
  avatar: string;
  level: number;
}

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  onStart: (mode: GameMode) => void;
  profile: Profile;
}

export function MenuScreen({ theme, setTheme, onStart, profile }: Props) {
  const [modeOpen, setModeOpen] = useState(false);
  return (
    <div className="screen menu-screen">
      <div className="menu-top">
        <button className="avatar-chip">
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
            <button className="mode-btn ghost-mode" disabled>
              <span className="mode-ico">👥</span>
              <span className="mode-txt">
                <b>Вдвоём</b>
                <i>скоро · hot-seat на одном устройстве</i>
              </span>
            </button>
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
            <button className="sec-btn">Профиль</button>
            <button className="sec-btn">Ачивки</button>
            <button className="sec-btn">Настройки</button>
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
