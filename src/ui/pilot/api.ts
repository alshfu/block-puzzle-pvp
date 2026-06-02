/**
 * Public state API, который приложение публикует на window для UI-пилота.
 * Пилот ЧИТАЕТ через это API (нужно чтобы знать чей ход, что в руке, какие
 * ходы возможны), но ДЕЙСТВИЯ выполняет через реальные PointerEvent-ы на DOM.
 *
 * Объект перезаписывается на каждый relevant render — пилот читает свежий
 * снимок (НЕ держит ссылку на старый).
 */
import type { Board, PieceInstance, RuleConfig } from "../../core";

export type PilotMode = "offline" | "online";

export interface PilotState {
  mode: PilotMode;
  /** Идёт ли сейчас активная партия (status="playing"). */
  playing: boolean;
  /** true когда ход за нашим UI-игроком (нижняя рука, interactive). */
  myTurn: boolean;
  /** Текущее состояние доски. */
  board: Board;
  /** Рука нашего игрока (та что снизу, interactive). */
  myHand: PieceInstance[];
  /** Правила (rotation/flip on/off и пр.) — для перебора ходов. */
  cfg: RuleConfig;
  /** Совместимый seed для воспроизводимости лога. */
  matchId: string;
}

declare global {
  interface Window {
    __BD_PILOT_API__?: PilotState;
  }
}

export function publishPilotState(s: PilotState): void {
  window.__BD_PILOT_API__ = s;
}

export function clearPilotState(): void {
  delete window.__BD_PILOT_API__;
}

export function readPilotState(): PilotState | null {
  return window.__BD_PILOT_API__ ?? null;
}
