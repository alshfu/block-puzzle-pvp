import type { BotLevel, RuleConfig } from "../../core";
import { Button } from "../components/Button";
import { Segment } from "../components/Segment";
import { ThemeSwitch } from "../components/ThemeSwitch";
import { Toggle } from "../components/Toggle";
import type { ThemeId } from "../themes";
import type { GameMode } from "./MenuScreen";

export type BlitzPreset = "hard" | "norm" | "casual";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  mode: GameMode;
  cfg: RuleConfig;
  setCfg: (c: RuleConfig) => void;
  botLevel: BotLevel;
  setBotLevel: (l: BotLevel) => void;
  blitz: BlitzPreset;
  setBlitz: (b: BlitzPreset) => void;
  onBack: () => void;
  onStart: () => void;
}

export function SetupScreen({
  theme, setTheme, mode, cfg, setCfg,
  botLevel, setBotLevel, blitz, setBlitz, onBack, onStart,
}: Props) {
  const upd = <K extends keyof RuleConfig>(k: K, v: RuleConfig[K]) =>
    setCfg({ ...cfg, [k]: v });

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Настройка матча</div>
        <span className="mode-badge">{mode === "bot" ? "vs bot" : "hot-seat"}</span>
      </div>

      <div className="setup-body">
        {mode === "bot" && (
          <section className="setup-sec">
            <div className="sec-cap">Соперник</div>
            <Segment<BotLevel>
              value={botLevel}
              onChange={setBotLevel}
              options={[
                { v: "easy", label: "Тупой", sub: "новичок" },
                { v: "medium", label: "Умный", sub: "по умолч." },
                { v: "hard", label: "Сложный", sub: "вызов" },
              ]}
            />
          </section>
        )}

        <section className="setup-sec">
          <div className="sec-cap">Правила</div>
          <div className="toggle-row">
            <Toggle
              label="Повороты"
              checked={cfg.rotationEnabled}
              onChange={(v) => upd("rotationEnabled", v)}
            />
            <Toggle
              label="Отражения"
              checked={cfg.flipEnabled}
              onChange={(v) => upd("flipEnabled", v)}
            />
          </div>
          <div className="sub-cap">Размер руки</div>
          <Segment<number>
            value={cfg.handSize}
            onChange={(v) => upd("handSize", v)}
            options={[
              { v: 2, label: "2" },
              { v: 3, label: "3" },
              { v: 4, label: "4" },
            ]}
          />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Блиц · время на ход</div>
          <Segment<BlitzPreset>
            value={blitz}
            onChange={setBlitz}
            options={[
              { v: "hard", label: "Хардкор", sub: "8 → 2с" },
              { v: "norm", label: "Норма", sub: "12 → 3с" },
              { v: "casual", label: "Казуал", sub: "20 → 6с" },
            ]}
          />
        </section>
      </div>

      <div className="setup-foot">
        <ThemeSwitch theme={theme} setTheme={setTheme} compact />
        <Button kind="primary" className="start-btn" onClick={onStart}>
          Начать →
        </Button>
      </div>
    </div>
  );
}

export const BLITZ_PRESETS: Record<BlitzPreset, { start: number; min: number }> = {
  hard: { start: 8, min: 2 },
  norm: { start: 12, min: 3 },
  casual: { start: 20, min: 6 },
};
