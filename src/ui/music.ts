/**
 * Тематические фоновые мелодии, синтезируемые Web Audio API «вживую».
 * Каждый трек — список голосов (voices), каждый голос — последовательность нот.
 * Планировщик подкладывает ноты вперёд на ~1.5с в audio-контекст; на смене темы
 * новые ноты уже создаются от нового трека — старые доигрывают свой буфер.
 */

import type { ThemeId } from "./themes";

interface Note {
  /** Частота в Гц. 0 — пауза. */
  f: number;
  /** Длительность в долях такта (beat). */
  d: number;
}

interface Voice {
  type: OscillatorType;
  /** Базовая громкость голоса (≤ 0.1 — фоновая). */
  gain: number;
  /** Сдвиг octave для удобства записи (e.g. -1 = на октаву ниже). */
  oct?: number;
  notes: Note[];
}

interface Track {
  bpm: number;
  voices: Voice[];
}

// ─── Ноты по нотным символам ─────────────────────────────────────────────
const A4 = 440;
const semi = (n: number) => A4 * Math.pow(2, n / 12);
// semitones from A4 (A=0, A#=1, B=2, C=3 …) MIDI-like:
// функция по имени: name = "C5", "F#4", "Bb3", ...
function n(name: string): number {
  const m = name.match(/^([A-G])([#b]?)(-?\d+)$/);
  if (!m) return 0;
  const [, l, acc, octStr] = m;
  const oct = parseInt(octStr, 10);
  const base: Record<string, number> = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };
  let semitones = base[l] + (acc === "#" ? 1 : acc === "b" ? -1 : 0);
  semitones += (oct - 4) * 12;
  return semi(semitones);
}
const R = 0; // пауза

// ─── Треки ────────────────────────────────────────────────────────────────

const TRACKS: Record<ThemeId, Track> = {
  // Neutral — synthwave-ambient, минорное настроение, спокойная пульсация.
  neutral: {
    bpm: 92,
    voices: [
      {
        // pad — длинные басовые ноты
        type: "triangle",
        gain: 0.05,
        notes: [
          { f: n("A2"), d: 4 },
          { f: n("F2"), d: 4 },
          { f: n("G2"), d: 4 },
          { f: n("E2"), d: 4 },
        ],
      },
      {
        // лид — арпеджио по аккорду
        type: "triangle",
        gain: 0.045,
        notes: [
          { f: n("A4"), d: 1 }, { f: n("C5"), d: 1 }, { f: n("E5"), d: 1 }, { f: n("A5"), d: 1 },
          { f: n("F4"), d: 1 }, { f: n("A4"), d: 1 }, { f: n("C5"), d: 1 }, { f: n("F5"), d: 1 },
          { f: n("G4"), d: 1 }, { f: n("B4"), d: 1 }, { f: n("D5"), d: 1 }, { f: n("G5"), d: 1 },
          { f: n("E4"), d: 1 }, { f: n("G4"), d: 1 }, { f: n("B4"), d: 1 }, { f: n("E5"), d: 1 },
        ],
      },
      {
        // hi-counter — редкие верхние ноты
        type: "sine",
        gain: 0.025,
        notes: [
          { f: R, d: 8 },
          { f: n("E6"), d: 2 }, { f: R, d: 2 },
          { f: n("D6"), d: 2 }, { f: n("E6"), d: 2 },
        ],
      },
    ],
  },

  // Candy — светлая мажорная карусель, чуть быстрее.
  candy: {
    bpm: 116,
    voices: [
      {
        // basa — мажорный аккорд через arpeggio
        type: "triangle",
        gain: 0.04,
        notes: [
          { f: n("C3"), d: 2 }, { f: n("G3"), d: 2 },
          { f: n("F3"), d: 2 }, { f: n("C4"), d: 2 },
          { f: n("A2"), d: 2 }, { f: n("E3"), d: 2 },
          { f: n("G3"), d: 2 }, { f: n("D4"), d: 2 },
        ],
      },
      {
        // sparkle лид — звонкие плёски
        type: "sine",
        gain: 0.06,
        notes: [
          { f: n("C5"), d: 0.5 }, { f: n("E5"), d: 0.5 }, { f: n("G5"), d: 0.5 }, { f: n("C6"), d: 0.5 },
          { f: n("G5"), d: 0.5 }, { f: n("E5"), d: 0.5 }, { f: n("C5"), d: 0.5 }, { f: n("E5"), d: 0.5 },
          { f: n("F5"), d: 0.5 }, { f: n("A5"), d: 0.5 }, { f: n("C6"), d: 0.5 }, { f: n("F6"), d: 0.5 },
          { f: n("C6"), d: 0.5 }, { f: n("A5"), d: 0.5 }, { f: n("F5"), d: 0.5 }, { f: n("A5"), d: 0.5 },
          { f: n("A5"), d: 0.5 }, { f: n("C6"), d: 0.5 }, { f: n("E6"), d: 0.5 }, { f: n("A6"), d: 0.5 },
          { f: n("E6"), d: 0.5 }, { f: n("C6"), d: 0.5 }, { f: n("A5"), d: 0.5 }, { f: n("C6"), d: 0.5 },
          { f: n("G5"), d: 0.5 }, { f: n("B5"), d: 0.5 }, { f: n("D6"), d: 0.5 }, { f: n("G6"), d: 0.5 },
          { f: n("D6"), d: 0.5 }, { f: n("B5"), d: 0.5 }, { f: n("G5"), d: 0.5 }, { f: n("B5"), d: 0.5 },
        ],
      },
      {
        // высокая колокольня — редкие звёздочки
        type: "triangle",
        gain: 0.04,
        notes: [
          { f: R, d: 4 }, { f: n("E6"), d: 0.5 }, { f: R, d: 3.5 },
          { f: R, d: 4 }, { f: n("G6"), d: 0.5 }, { f: R, d: 3.5 },
        ],
      },
    ],
  },

  // Night — неон-нуар, тёмно, пульсирующий бас, готически-восточный лад.
  night: {
    bpm: 80,
    voices: [
      {
        // pulsing bass — ровный пульс восьмыми
        type: "sawtooth",
        gain: 0.04,
        notes: [
          { f: n("D2"), d: 0.5 }, { f: R, d: 0.5 }, { f: n("D2"), d: 0.5 }, { f: R, d: 0.5 },
          { f: n("D2"), d: 0.5 }, { f: R, d: 0.5 }, { f: n("D2"), d: 0.5 }, { f: R, d: 0.5 },
          { f: n("C2"), d: 0.5 }, { f: R, d: 0.5 }, { f: n("C2"), d: 0.5 }, { f: R, d: 0.5 },
          { f: n("Bb2"), d: 0.5 }, { f: R, d: 0.5 }, { f: n("A2"), d: 0.5 }, { f: R, d: 0.5 },
        ],
      },
      {
        // лид — фригийская мелодия
        type: "square",
        gain: 0.035,
        notes: [
          { f: n("D4"), d: 2 }, { f: n("F4"), d: 1 }, { f: n("A4"), d: 1 },
          { f: n("Bb4"), d: 2 }, { f: n("A4"), d: 2 },
          { f: n("G4"), d: 1 }, { f: n("F4"), d: 1 }, { f: n("E4"), d: 1 }, { f: n("F4"), d: 1 },
          { f: n("D4"), d: 4 },
        ],
      },
      {
        // высокая «искра» — редкая высокая нота
        type: "triangle",
        gain: 0.03,
        notes: [
          { f: R, d: 12 },
          { f: n("F5"), d: 1 }, { f: n("A5"), d: 1 }, { f: n("D6"), d: 2 },
        ],
      },
    ],
  },
};

// ─── Глобальное состояние модуля ──────────────────────────────────────────

let ctx: AudioContext | null = null;
let masterGain: GainNode | null = null;
let scheduler: ReturnType<typeof setInterval> | null = null;
let nextEnd = 0;
let enabled = false;
let currentTheme: ThemeId = "neutral";
const VOLUME = 0.55;

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
  if (!masterGain && ctx) {
    masterGain = ctx.createGain();
    masterGain.gain.value = enabled ? VOLUME : 0;
    masterGain.connect(ctx.destination);
  }
  return ctx;
}

function playNote(freq: number, duration: number, type: OscillatorType, gain: number, when: number): void {
  if (!ctx || !masterGain) return;
  if (freq <= 0) return;
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, when);
  g.gain.setValueAtTime(0, when);
  g.gain.linearRampToValueAtTime(gain, when + 0.03);
  g.gain.exponentialRampToValueAtTime(0.0001, when + duration);
  osc.connect(g).connect(masterGain);
  osc.start(when);
  osc.stop(when + duration + 0.08);
}

function scheduleLoop(track: Track, startAt: number): number {
  const beat = 60 / track.bpm;
  let end = startAt;
  for (const v of track.voices) {
    const octShift = v.oct ?? 0;
    const mult = Math.pow(2, octShift);
    let t = startAt;
    for (const note of v.notes) {
      const dur = note.d * beat;
      if (note.f > 0) playNote(note.f * mult, dur, v.type, v.gain, t);
      t += dur;
    }
    if (t > end) end = t;
  }
  return end;
}

function startScheduler(): void {
  if (scheduler) return;
  scheduler = setInterval(() => {
    if (!enabled) return;
    const c = ensureCtx();
    if (!c) return;
    if (c.state !== "running") {
      c.resume().catch(() => {});
      return;
    }
    const now = c.currentTime;
    if (nextEnd < now + 0.05) nextEnd = now + 0.05;
    // подкладываем вперёд на ~1.5 секунды
    while (nextEnd - now < 1.5) {
      nextEnd = scheduleLoop(TRACKS[currentTheme], nextEnd);
    }
  }, 400);
}

function stopScheduler(): void {
  if (scheduler) clearInterval(scheduler);
  scheduler = null;
}

export function setMusicEnabled(v: boolean): void {
  enabled = v;
  if (!v) {
    // плавный фейд, чтобы не было щелчка
    if (ctx && masterGain) {
      const t = ctx.currentTime;
      masterGain.gain.cancelScheduledValues(t);
      masterGain.gain.setValueAtTime(masterGain.gain.value, t);
      masterGain.gain.linearRampToValueAtTime(0, t + 0.15);
    }
    stopScheduler();
  } else {
    ensureCtx();
    if (ctx && masterGain) {
      const t = ctx.currentTime;
      masterGain.gain.cancelScheduledValues(t);
      masterGain.gain.setValueAtTime(masterGain.gain.value, t);
      masterGain.gain.linearRampToValueAtTime(VOLUME, t + 0.25);
    }
    if (ctx) nextEnd = ctx.currentTime;
    startScheduler();
  }
}

export function setMusicTheme(theme: ThemeId): void {
  currentTheme = theme;
  // ноты, которые уже запланированы, доиграют — но через 1.5с уже пойдёт новый трек.
  // Чтобы быстрее переключиться, прибиваем nextEnd, заставляя scheduler писать новый трек вместо
  // продолжения старого.
  if (ctx) nextEnd = Math.min(nextEnd, ctx.currentTime + 0.5);
}
