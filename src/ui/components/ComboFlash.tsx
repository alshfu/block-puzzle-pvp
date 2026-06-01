import type { ThemeId } from "../themes";
import { Mascot } from "./Mascot";

interface Props {
  theme: ThemeId;
  level: 1 | 2 | 3;
  combo: number;
  message: string;
  variant?: "combo" | "streak";
  /** Для streak: subtitle типа «личный рекорд» */
  subtitle?: string;
}

export const COMBO_MESSAGES: Record<ThemeId, { 1: string[]; 2: string[]; 3: string[] }> = {
  neutral: {
    1: ["EFFICIENT", "CLEAN", "NICE"],
    2: ["EXCELLENT", "MASTERFUL", "FLAWLESS"],
    3: ["LEGEND", "TRANSCENDENT", "MAX OUTPUT"],
  },
  candy: {
    1: ["Молодец!", "Волшебно!", "Здорово!"],
    2: ["Невероятно!", "Магия!", "Сладко!"],
    3: ["Магистр карамели!", "Звёздное чудо!", "Радужный шторм!"],
  },
  night: {
    1: ["Жестоко", "Холодно", "Тень одобряет"],
    2: ["Безжалостно", "Идеальный удар", "Чистая ночь"],
    3: ["Ты — тьма", "Чемпион ночи", "Бесконечность"],
  },
};

export function pickComboMessage(theme: ThemeId, level: 1 | 2 | 3, rng = Math.random): string {
  const opts = COMBO_MESSAGES[theme][level];
  return opts[Math.floor(rng() * opts.length)];
}

export function ComboFlash({ theme, level, combo, message, variant = "combo", subtitle }: Props) {
  return (
    <div className={`combo-flash level-${level} variant-${variant}`}>
      <div className="combo-flash-inner">
        <div className="combo-flash-mascot">
          <Mascot theme={theme} size={level === 3 ? 160 : level === 2 ? 130 : 110} />
        </div>
        <div className="combo-flash-text">
          <div className="combo-flash-title">{message}</div>
          {variant === "combo" ? (
            <div className="combo-flash-sub">комбо ×{combo}</div>
          ) : (
            <div className="combo-flash-sub">{subtitle ?? `${combo} побед подряд`}</div>
          )}
        </div>
      </div>
    </div>
  );
}
