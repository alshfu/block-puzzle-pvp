import type { RuleConfig } from "../../core";

interface Props {
  hasSelection: boolean;
  cfg: RuleConfig;
  onRotate: () => void;
  onFlip: () => void;
  onClear: () => void;
}

export function TransformControls({ hasSelection, cfg, onRotate, onFlip, onClear }: Props) {
  return (
    <div className="transform-controls">
      <button
        className="tc-btn"
        disabled={!hasSelection || !cfg.rotationEnabled}
        onClick={onRotate}
      >
        <span className="tc-ico">↻</span> Повернуть
      </button>
      <button
        className="tc-btn"
        disabled={!hasSelection || !cfg.flipEnabled}
        onClick={onFlip}
      >
        <span className="tc-ico">⇄</span> Отразить
      </button>
      <button className="tc-btn" disabled={!hasSelection} onClick={onClear}>
        <span className="tc-ico">✕</span> Снять
      </button>
    </div>
  );
}
