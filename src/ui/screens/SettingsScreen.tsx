import type { BotLevel } from "../../core";
import { Segment } from "../components/Segment";
import { ThemeSwitch } from "../components/ThemeSwitch";
import { Toggle } from "../components/Toggle";
import type { AppSettings } from "../storage/settings";
import type { ThemeId } from "../themes";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  settings: AppSettings;
  setSettings: (s: AppSettings) => void;
  onBack: () => void;
}

export function SettingsScreen({ theme, setTheme, settings, setSettings, onBack }: Props) {
  const upd = <K extends keyof AppSettings>(k: K, v: AppSettings[K]) =>
    setSettings({ ...settings, [k]: v });
  const updCfg = <K extends keyof AppSettings["defaultCfg"]>(
    k: K,
    v: AppSettings["defaultCfg"][K],
  ) => setSettings({ ...settings, defaultCfg: { ...settings.defaultCfg, [k]: v } });

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Настройки</div>
      </div>

      <div className="setup-body">
        <section className="setup-sec">
          <div className="sec-cap">Тема</div>
          <ThemeSwitch theme={theme} setTheme={setTheme} />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Звук и тактильно</div>
          <div className="toggle-row">
            <Toggle label="Звук" checked={settings.sound} onChange={(v) => upd("sound", v)} />
            <Toggle label="Вибро" checked={settings.vibrate} onChange={(v) => upd("vibrate", v)} />
          </div>
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Правила по умолчанию</div>
          <div className="toggle-row">
            <Toggle
              label="Повороты"
              checked={settings.defaultCfg.rotationEnabled}
              onChange={(v) => updCfg("rotationEnabled", v)}
            />
            <Toggle
              label="Отражения"
              checked={settings.defaultCfg.flipEnabled}
              onChange={(v) => updCfg("flipEnabled", v)}
            />
          </div>
          <div className="sub-cap">Размер руки</div>
          <Segment<number>
            value={settings.defaultCfg.handSize}
            onChange={(v) => updCfg("handSize", v)}
            options={[
              { v: 2, label: "2" },
              { v: 3, label: "3" },
              { v: 4, label: "4" },
            ]}
          />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Сложность бота по умолчанию</div>
          <Segment<BotLevel>
            value={settings.defaultBotLevel}
            onChange={(v) => upd("defaultBotLevel", v)}
            options={[
              { v: "easy", label: "Тупой" },
              { v: "medium", label: "Умный" },
              { v: "hard", label: "Сложный" },
            ]}
          />
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Блиц по умолчанию</div>
          <Segment<BlitzPreset>
            value={settings.defaultBlitz}
            onChange={(v) => upd("defaultBlitz", v)}
            options={[
              { v: "hard", label: "Хардкор" },
              { v: "norm", label: "Норма" },
              { v: "casual", label: "Казуал" },
            ]}
          />
        </section>
      </div>
    </div>
  );
}
