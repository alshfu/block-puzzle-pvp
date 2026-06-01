import type { BotLevel, RuleConfig } from "../../core";
import { FloatingTheme } from "../components/FloatingTheme";
import { Logo } from "../components/Logo";
import type { ThemeId } from "../themes";
import type { GameMode } from "./MenuScreen";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  mode: GameMode;
  cfg: RuleConfig;
  botLevel: BotLevel;
  blitz: BlitzPreset;
  onExit: () => void;
}

/**
 * Каркас игрового экрана. Реальная игра (доска, руки, ход, таймер, бот)
 * подключается отдельным подшагом.
 */
export function GameScreen({ theme, setTheme, mode, botLevel, onExit }: Props) {
  return (
    <div className="screen game-screen">
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">
          {mode === "bot" ? "vs bot · " + botLevel : "hot-seat"}
        </span>
        <button className="pause-btn" onClick={onExit}>
          ←
        </button>
      </div>

      <div className="status-bar">Игровой экран — следующий подшаг</div>

      <FloatingTheme theme={theme} setTheme={setTheme} />
    </div>
  );
}
