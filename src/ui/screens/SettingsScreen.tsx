import { useRef, useState } from "react";
import type { BotLevel } from "../../core";
import type { AuthUser } from "../auth/auth";
import { signInWithGoogle, signOut as authSignOut } from "../auth/auth";
import { isAuthEnabled } from "../auth/firebase";
import { Button } from "../components/Button";
import { Segment } from "../components/Segment";
import { ThemeSwitch } from "../components/ThemeSwitch";
import { Toggle } from "../components/Toggle";
import type { AppSettings, ClearSpeed, VibrateIntensity } from "../storage/settings";
import type { ThemeId } from "../themes";
import type { BlitzPreset } from "./SetupScreen";

interface Props {
  theme: ThemeId;
  setTheme: (t: ThemeId) => void;
  settings: AppSettings;
  setSettings: (s: AppSettings) => void;
  authUser: AuthUser | null;
  /** Сериализуют всё прогресс-state в JSON. */
  onExport: () => void;
  onImport: (json: string) => void;
  /** Полный сброс прогресса (с подтверждением). */
  onResetAll: () => void;
  onBack: () => void;
}

// Версия запекается Vite через define из package.json в момент сборки.
declare const __APP_VERSION__: string;
const APP_VERSION = typeof __APP_VERSION__ !== "undefined" ? `v${__APP_VERSION__}` : "v0.0.0-dev";
const REPO_URL = "https://github.com/alshfu/block-puzzle-pvp";

export function SettingsScreen({
  theme,
  setTheme,
  settings,
  setSettings,
  authUser,
  onExport,
  onImport,
  onResetAll,
  onBack,
}: Props) {
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [confirmReset, setConfirmReset] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const authEnabled = isAuthEnabled();

  const upd = <K extends keyof AppSettings>(k: K, v: AppSettings[K]) =>
    setSettings({ ...settings, [k]: v });
  const updCfg = <K extends keyof AppSettings["defaultCfg"]>(k: K, v: AppSettings["defaultCfg"][K]) =>
    setSettings({ ...settings, defaultCfg: { ...settings.defaultCfg, [k]: v } });

  async function handleSignIn() {
    setAuthBusy(true);
    setAuthError(null);
    try {
      await signInWithGoogle();
    } catch (e) {
      setAuthError(e instanceof Error ? e.message : String(e));
    } finally {
      setAuthBusy(false);
    }
  }

  async function handleSignOut() {
    setAuthBusy(true);
    try {
      await authSignOut();
    } finally {
      setAuthBusy(false);
    }
  }

  function handleImportClick() {
    fileInputRef.current?.click();
  }

  function handleFileChosen(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => {
      const text = String(reader.result ?? "");
      if (text) onImport(text);
    };
    reader.readAsText(f);
    e.target.value = "";
  }

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Настройки</div>
      </div>

      <div className="setup-body">
        {/* ─── Аккаунт ─── */}
        {authEnabled && (
          <section className="setup-sec">
            <div className="sec-cap">Аккаунт</div>
            {authUser ? (
              <div className="auth-card">
                {authUser.photoURL && <img className="auth-avatar" src={authUser.photoURL} alt="" />}
                <div className="auth-text">
                  <div className="auth-name">{authUser.displayName ?? "Пользователь Google"}</div>
                  <div className="auth-email">{authUser.email ?? authUser.uid}</div>
                  <div className="auth-sync">синхронизация прогресса включена</div>
                </div>
                <button className="resume-btn" onClick={handleSignOut} disabled={authBusy}>
                  Выйти
                </button>
              </div>
            ) : (
              <>
                <Button kind="primary" className="start-btn" onClick={handleSignIn} disabled={authBusy}>
                  {authBusy ? "Подключение…" : "Войти через Google"}
                </Button>
                <div className="status-bar">Синхронизация профиля, статистики, монеты, ачивок и скинов между устройствами.</div>
                {authError && <div className="status-bar danger">Ошибка: {authError}</div>}
              </>
            )}
          </section>
        )}

        {/* ─── Тема ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Тема</div>
          <ThemeSwitch theme={theme} setTheme={setTheme} />
        </section>

        {/* ─── Звук ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Звук</div>
          <div className="toggle-row">
            <Toggle label="Звуки эффектов" checked={settings.sound} onChange={(v) => upd("sound", v)} />
          </div>
          <div className="sub-cap">Громкость эффектов · {Math.round(settings.soundVolume * 100)}%</div>
          <input
            type="range" min={0} max={100} step={5}
            value={Math.round(settings.soundVolume * 100)}
            onChange={(e) => upd("soundVolume", Number(e.target.value) / 100)}
            disabled={!settings.sound}
            className="range-slider"
          />

          <div className="toggle-row" style={{ marginTop: 10 }}>
            <Toggle label="Музыка" checked={settings.music} onChange={(v) => upd("music", v)} />
          </div>
          <div className="sub-cap">Громкость музыки · {Math.round(settings.musicVolume * 100)}%</div>
          <input
            type="range" min={0} max={100} step={5}
            value={Math.round(settings.musicVolume * 100)}
            onChange={(e) => upd("musicVolume", Number(e.target.value) / 100)}
            disabled={!settings.music}
            className="range-slider"
          />
        </section>

        {/* ─── Вибрация ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Вибрация (только тач-устройства)</div>
          <Segment<VibrateIntensity>
            value={settings.vibrate ? settings.vibrateIntensity : "off"}
            onChange={(v) => {
              if (v === "off") upd("vibrate", false);
              else { upd("vibrate", true); upd("vibrateIntensity", v); }
            }}
            options={[
              { v: "off", label: "Выкл" },
              { v: "light", label: "Лёгкая" },
              { v: "strong", label: "Сильная" },
            ]}
          />
        </section>

        {/* ─── Анимации ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Анимации и эффекты</div>
          <div className="toggle-row">
            <Toggle label="Вспышки очисток" checked={settings.flashEnabled} onChange={(v) => upd("flashEnabled", v)} />
            <Toggle label="Конфетти" checked={settings.confettiEnabled} onChange={(v) => upd("confettiEnabled", v)} />
          </div>
          <div className="toggle-row">
            <Toggle label="Пони/мульт-декор" checked={settings.mascotEnabled} onChange={(v) => upd("mascotEnabled", v)} />
            <Toggle label="Снизить движение" checked={settings.reducedMotion} onChange={(v) => upd("reducedMotion", v)} />
          </div>
          <div className="sub-cap">Скорость анимации очистки</div>
          <Segment<ClearSpeed>
            value={settings.clearSpeed}
            onChange={(v) => upd("clearSpeed", v)}
            options={[
              { v: "fast", label: "Быстро", sub: "180мс" },
              { v: "normal", label: "Обычно", sub: "430мс" },
              { v: "slow", label: "Кинематично", sub: "700мс" },
            ]}
          />
        </section>

        {/* ─── Геймплей ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Геймплей</div>
          <div className="toggle-row">
            <Toggle label="Подсветка цели (ghost)" checked={settings.showGhost} onChange={(v) => upd("showGhost", v)} />
          </div>
          <div className="sub-cap">Задержка хода бота · {settings.botDelayMs}мс</div>
          <input
            type="range" min={0} max={1500} step={100}
            value={settings.botDelayMs}
            onChange={(e) => upd("botDelayMs", Number(e.target.value))}
            className="range-slider"
          />
        </section>

        {/* ─── Правила по умолчанию ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Правила по умолчанию</div>
          <div className="toggle-row">
            <Toggle label="Повороты" checked={settings.defaultCfg.rotationEnabled} onChange={(v) => updCfg("rotationEnabled", v)} />
            <Toggle label="Отражения" checked={settings.defaultCfg.flipEnabled} onChange={(v) => updCfg("flipEnabled", v)} />
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
          <div className="sub-cap">Таймер хода по умолчанию</div>
          <div className="toggle-row">
            <Toggle
              label={settings.defaultCfg.turnTimerEnabled ? "Блиц включён" : "Без таймера"}
              checked={settings.defaultCfg.turnTimerEnabled}
              onChange={(v) => updCfg("turnTimerEnabled", v)}
            />
          </div>
        </section>

        {/* ─── Сложность ─── */}
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

        {/* ─── Данные ─── */}
        <section className="setup-sec">
          <div className="sec-cap">Прогресс и данные</div>
          <div className="data-row">
            <button className="resume-btn" onClick={onExport}>📤 Экспорт JSON</button>
            <button className="resume-btn" onClick={handleImportClick}>📥 Импорт JSON</button>
            <input ref={fileInputRef} type="file" accept="application/json" onChange={handleFileChosen} style={{ display: "none" }} />
          </div>
          <div className="status-bar">Экспорт сохраняет профиль, статистику, ачивки, кошелёк, скины и инвентарь. Импорт перезапишет локальные данные.</div>
          {!confirmReset ? (
            <button className="back-link danger" onClick={() => setConfirmReset(true)}>
              ⚠️ Сбросить весь прогресс…
            </button>
          ) : (
            <div className="reset-confirm">
              <div className="status-bar danger">
                Удалит профиль, статистику, ачивки, кошелёк, скины, инвентарь и сохранённую партию. Действие необратимо.
              </div>
              <div className="data-row">
                <button className="resume-btn primary" onClick={() => { onResetAll(); setConfirmReset(false); }}>
                  Да, удалить всё
                </button>
                <button className="resume-btn" onClick={() => setConfirmReset(false)}>Отмена</button>
              </div>
            </div>
          )}
        </section>

        {/* ─── О приложении ─── */}
        <section className="setup-sec">
          <div className="sec-cap">О приложении</div>
          <div className="about-card">
            <div className="about-line"><b>BlockDuel 9×9</b> · {APP_VERSION}</div>
            <div className="about-line"><span className="about-key">GitHub</span> <a href={REPO_URL} target="_blank" rel="noopener noreferrer">{REPO_URL.replace("https://", "")}</a></div>
            <div className="about-line"><span className="about-key">PvP-сервер</span> pvp.alshfu.com</div>
            <div className="about-line muted">Собрано с Claude Code · TS + React + Vite</div>
          </div>
        </section>
      </div>
    </div>
  );
}
