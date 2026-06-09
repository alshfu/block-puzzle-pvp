import { useEffect } from "react";
import type { AchievementDef } from "../achievements/definitions";

interface Props {
  toasts: AchievementDef[];
  onDismiss: (id: string) => void;
  durationMs?: number;
}

export function ToastStack({ toasts, onDismiss, durationMs = 4000 }: Props) {
  useEffect(() => {
    if (toasts.length === 0) return;
    const timers = toasts.map((t) =>
      setTimeout(() => onDismiss(t.id), durationMs),
    );
    return () => timers.forEach(clearTimeout);
  }, [toasts, onDismiss, durationMs]);

  if (toasts.length === 0) return null;
  return (
    <div className="toast-stack">
      {toasts.map((t) => (
        <div key={t.id} className="toast" onClick={() => onDismiss(t.id)}>
          <span className="toast-ico">{t.icon}</span>
          <span className="toast-text">
            <span className="toast-title">Ачивка: {t.title}</span>
            <span className="toast-desc">{t.description} · +{t.rewardXp} XP</span>
          </span>
        </div>
      ))}
    </div>
  );
}
