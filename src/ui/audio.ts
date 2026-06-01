/**
 * Лёгкий звуковой модуль на Web Audio API без внешних файлов.
 * Все звуки синтезируются осцилляторами на лету.
 */

let ctx: AudioContext | null = null;
let soundEnabled = true;
let soundVolume = 0.7;
let vibrateEnabled = true;
let vibrateScale = 1; // 0 / 0.5 / 1 для off/light/strong

export function setSoundEnabled(v: boolean): void {
  soundEnabled = v;
}
export function setSoundVolume(v: number): void {
  soundVolume = Math.max(0, Math.min(1, v));
}

export function setVibrateEnabled(v: boolean): void {
  vibrateEnabled = v;
}
export function setVibrateIntensity(v: "off" | "light" | "strong"): void {
  vibrateScale = v === "off" ? 0 : v === "light" ? 0.4 : 1;
}

function ensureCtx(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (!ctx) {
    const AC =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AC) return null;
    try {
      ctx = new AC();
    } catch {
      return null;
    }
  }
  // Если контекст был «приостановлен» (Chrome до user-gesture), пробуем поднять.
  if (ctx.state === "suspended") {
    ctx.resume().catch(() => {});
  }
  return ctx;
}

interface ToneOpts {
  freq: number;
  duration: number;
  type?: OscillatorType;
  gain?: number;
  start?: number;
}

function tone({ freq, duration, type = "sine", gain = 0.1, start = 0 }: ToneOpts): void {
  if (!soundEnabled || soundVolume <= 0) return;
  const c = ensureCtx();
  if (!c) return;
  const t0 = c.currentTime + start;
  const osc = c.createOscillator();
  const g = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  const peak = gain * soundVolume;
  g.gain.setValueAtTime(0, t0);
  g.gain.linearRampToValueAtTime(peak, t0 + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + duration);
  osc.connect(g).connect(c.destination);
  osc.start(t0);
  osc.stop(t0 + duration + 0.02);
}

// --- public sound API ---

export function playPlace(): void {
  tone({ freq: 280, duration: 0.08, type: "triangle", gain: 0.08 });
}

export function playInvalid(): void {
  tone({ freq: 140, duration: 0.18, type: "sawtooth", gain: 0.09 });
  tone({ freq: 110, duration: 0.18, type: "sawtooth", gain: 0.06, start: 0.04 });
}

/** Очистка: количество единиц N → восходящий аккорд из N нот. */
export function playClear(n: number): void {
  const base = [392, 494, 587, 698, 784, 880, 988, 1047]; // G4, B4, D5, F5, G5, A5, B5, C6
  const count = Math.min(Math.max(n, 1), base.length);
  for (let i = 0; i < count; i++) {
    tone({ freq: base[i], duration: 0.25, type: "triangle", gain: 0.07, start: i * 0.06 });
  }
}

export function playPerfect(): void {
  const seq = [523, 659, 784, 1047, 1319]; // C5 E5 G5 C6 E6 — мажорный арпеджио вверх
  seq.forEach((f, i) =>
    tone({ freq: f, duration: 0.32, type: "triangle", gain: 0.09, start: i * 0.08 }),
  );
}

export function playWin(): void {
  const seq = [523, 659, 784, 1047]; // C maj
  seq.forEach((f, i) => tone({ freq: f, duration: 0.32, type: "triangle", gain: 0.09, start: i * 0.12 }));
}

export function playLose(): void {
  const seq = [392, 330, 262, 196]; // нисходящий
  seq.forEach((f, i) => tone({ freq: f, duration: 0.4, type: "sine", gain: 0.09, start: i * 0.15 }));
}

export function playDraw(): void {
  tone({ freq: 392, duration: 0.4, type: "sine", gain: 0.08 });
  tone({ freq: 494, duration: 0.4, type: "sine", gain: 0.08, start: 0.1 });
}

export function playTick(): void {
  // короткий «тик» таймера в danger-зоне
  tone({ freq: 880, duration: 0.05, type: "square", gain: 0.04 });
}

export function playClick(): void {
  tone({ freq: 660, duration: 0.04, type: "square", gain: 0.04 });
}

// --- vibration ---

export function vibrate(pattern: number | number[]): void {
  if (!vibrateEnabled || vibrateScale <= 0) return;
  if (typeof navigator === "undefined") return;
  if (typeof navigator.vibrate !== "function") return;
  const scaled = typeof pattern === "number"
    ? Math.round(pattern * vibrateScale)
    : pattern.map((p) => Math.round(p * vibrateScale));
  try {
    navigator.vibrate(scaled);
  } catch {
    /* ignore */
  }
}

export function vibratePlace(): void {
  vibrate(8);
}

export function vibrateInvalid(): void {
  vibrate([20, 30, 20]);
}

export function vibrateClear(n: number): void {
  vibrate(Math.min(20 + n * 10, 80));
}

export function vibratePerfect(): void {
  vibrate([40, 50, 40, 50, 100]);
}

export function vibrateWin(): void {
  vibrate([60, 40, 60, 40, 80]);
}

export function vibrateLose(): void {
  vibrate(120);
}
