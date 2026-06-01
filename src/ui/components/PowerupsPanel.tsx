import { POWERUPS, type PowerupId } from "../shop/powerups";
import type { Inventory } from "../storage/inventory";

interface Props {
  inventory: Inventory;
  /** id активного power-up (selection mode) или null. */
  active: PowerupId | null;
  /** false = панель показана, но клики игнорируются (например ход бота). */
  enabled: boolean;
  onClick: (id: PowerupId) => void;
}

export function PowerupsPanel({ inventory, active, enabled, onClick }: Props) {
  return (
    <div className="powerups-panel">
      {POWERUPS.map((p) => {
        const count = inventory[p.id];
        const isActive = active === p.id;
        const disabled = !enabled || count <= 0;
        return (
          <button
            key={p.id}
            className={`pu-btn ${isActive ? "active" : ""} ${disabled ? "disabled" : ""}`}
            disabled={disabled}
            onClick={() => onClick(p.id)}
            title={`${p.name} — ${p.hint}`}
          >
            <span className="pu-ico">{p.icon}</span>
            <span className="pu-count">{count}</span>
          </button>
        );
      })}
    </div>
  );
}
