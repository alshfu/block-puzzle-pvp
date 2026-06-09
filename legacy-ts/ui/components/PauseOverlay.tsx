import { Button } from "./Button";

interface Props {
  onResume: () => void;
  onRestart: () => void;
  onExit: () => void;
}

export function PauseOverlay({ onResume, onRestart, onExit }: Props) {
  return (
    <div className="overlay">
      <div className="pause-card">
        <div className="pause-title">Пауза</div>
        <Button kind="primary" onClick={onResume}>
          ▶ Продолжить
        </Button>
        <Button kind="ghost" onClick={onRestart}>
          ⟳ Новая игра
        </Button>
        <Button kind="ghost" onClick={onExit}>
          ← В меню
        </Button>
      </div>
    </div>
  );
}
