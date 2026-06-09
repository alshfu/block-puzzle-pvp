/**
 * Entry-point UI-пилота. Загружается через dynamic import только когда
 * isPilotEnabled() === true, поэтому в обычной prod-сборке весь pilot
 * не попадает в initial bundle.
 *
 * Параметры через URL: ?pilot=1[&pilotLevel=easy|medium|hard][&pilotTick=600]
 */
import { startPilot, pausePilot, resumePilot, stopPilot, isPilotRunning } from "./pilot";
import { downloadJournal, size as journalSize } from "./journal";

declare global {
  interface Window {
    __bdPilotStart?: () => void;
    __bdPilotStop?: () => void;
    __bdPilotPause?: () => void;
    __bdPilotResume?: () => void;
  }
}

function mountHud(): HTMLElement {
  const root = document.createElement("div");
  root.id = "bd-pilot-hud";
  root.style.cssText = `
    position: fixed; bottom: 8px; right: 8px; z-index: 99999;
    background: rgba(20,22,28,.92); color: #fff;
    border: 1px solid #ff4d97; border-radius: 8px;
    padding: 8px 10px; font: 11px/1.4 monospace;
    display: flex; gap: 6px; align-items: center;
    user-select: none;
  `;
  root.innerHTML = `
    <span style="color:#ff4d97;font-weight:700">PILOT</span>
    <span id="bd-pilot-state">idle</span>
    <button data-act="toggle" style="padding:3px 6px;font:11px monospace;cursor:pointer">⏸</button>
    <button data-act="download" style="padding:3px 6px;font:11px monospace;cursor:pointer">⬇ log</button>
    <span id="bd-pilot-count" style="opacity:.6">0</span>
  `;
  document.body.appendChild(root);
  return root;
}

function readParams(): { level: "easy" | "medium" | "hard"; tickMs: number } {
  const p = new URLSearchParams(window.location.search);
  const lvlRaw = p.get("pilotLevel");
  const level = lvlRaw === "easy" || lvlRaw === "hard" ? lvlRaw : "medium";
  const tickMs = Math.max(100, Number(p.get("pilotTick")) || 600);
  return { level, tickMs };
}

export async function initPilot(): Promise<void> {
  if (typeof document === "undefined") return;
  // ждём загрузку DOM (на всякий случай)
  if (document.readyState === "loading") {
    await new Promise<void>((r) => document.addEventListener("DOMContentLoaded", () => r(), { once: true }));
  }
  const hud = mountHud();
  const stateEl = hud.querySelector<HTMLElement>("#bd-pilot-state");
  const countEl = hud.querySelector<HTMLElement>("#bd-pilot-count");
  const toggleBtn = hud.querySelector<HTMLButtonElement>('button[data-act="toggle"]');
  const downloadBtn = hud.querySelector<HTMLButtonElement>('button[data-act="download"]');

  const refresh = () => {
    if (stateEl) stateEl.textContent = isPilotRunning() ? "running" : "paused";
    if (countEl) countEl.textContent = String(journalSize());
  };
  setInterval(refresh, 500);

  let runningStarted = false;
  toggleBtn?.addEventListener("click", () => {
    if (!runningStarted) return;
    if (isPilotRunning()) pausePilot();
    else resumePilot();
    refresh();
  });
  downloadBtn?.addEventListener("click", () => downloadJournal());

  // Expose helpers в global для DevTools.
  window.__bdPilotStart = () => {
    if (runningStarted) return;
    runningStarted = true;
    void startPilot(readParams());
  };
  window.__bdPilotStop = () => {
    stopPilot();
    runningStarted = false;
  };
  window.__bdPilotPause = pausePilot;
  window.__bdPilotResume = resumePilot;

  // Авто-старт после небольшой задержки — даём приложению смонтироваться.
  setTimeout(() => {
    if (!runningStarted) {
      runningStarted = true;
      void startPilot(readParams());
    }
  }, 1500);
}
