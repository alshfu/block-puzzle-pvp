/**
 * Журнал действий UI-пилота. Каждая запись — что сделал, на чём, успешно ли.
 * Можно скачать как JSON (для post-mortem багов).
 */

export type JournalKind =
  | "start"
  | "stop"
  | "wait"
  | "selectPiece"
  | "rotate"
  | "flip"
  | "drag"
  | "moveSent"
  | "noMove"
  | "stateSnapshot"
  | "error";

export interface JournalEntry {
  ts: number;
  rel: number; // ms с начала сессии
  kind: JournalKind;
  detail?: unknown;
}

const entries: JournalEntry[] = [];
let t0 = Date.now();

declare global {
  interface Window {
    __BD_PILOT_JOURNAL__?: JournalEntry[];
    __bdPilotDownload?: () => void;
  }
}

export function resetJournal(): void {
  entries.length = 0;
  t0 = Date.now();
  window.__BD_PILOT_JOURNAL__ = entries;
}

export function record(kind: JournalKind, detail?: unknown): void {
  const now = Date.now();
  entries.push({ ts: now, rel: now - t0, kind, detail });
  window.__BD_PILOT_JOURNAL__ = entries;
}

export function size(): number {
  return entries.length;
}

export function dumpJSON(): string {
  return JSON.stringify({ startedAt: t0, count: entries.length, entries }, null, 2);
}

export function downloadJournal(): void {
  const blob = new Blob([dumpJSON()], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `bd-pilot-${new Date(t0).toISOString().replace(/[:.]/g, "-")}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// expose для удобства из DevTools
if (typeof window !== "undefined") {
  window.__bdPilotDownload = downloadJournal;
}
