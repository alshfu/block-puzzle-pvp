/**
 * UI-пилот: главный цикл. Раз в N мс смотрит на window.__BD_PILOT_API__,
 * и когда myTurn — выбирает ход через core.chooseBotMove + ВЫПОЛНЯЕТ его
 * через настоящие PointerEvent-ы (нет прямых setSel/sendMove).
 *
 * Журналирует каждый шаг (selectPiece/rotate/flip/drag/moveSent).
 */
import {
  BASE_SHAPES,
  chooseBotMove,
  flipH,
  makeRng,
  normalize,
  rotate90,
  type CandidateMove,
  type Coord,
  type PieceInstance,
} from "../../core";
import { readPilotState } from "./api";
import {
  boardCellRect,
  clickEl,
  drag,
  findFlipBtn,
  findMyHandSlot,
  findRotateBtn,
  sleep,
  tap,
} from "./dom";
import { record, resetJournal } from "./journal";

interface PilotOpts {
  /** Период опроса состояния, мс. */
  tickMs?: number;
  /** Уровень бота для выбора хода. */
  level?: "easy" | "medium" | "hard";
  /** Стартовый seed для воспроизводимости решений пилота. */
  seed?: number;
}

let running = false;
let paused = false;

function key(cells: Coord[]): string {
  return normalize(cells)
    .map(([r, c]) => `${r},${c}`)
    .join("|");
}

/** Сколько раз нажать «Отразить» (0/1) и «Повернуть» (0–3), чтобы из нормализованной BASE_SHAPES получить move.cells. */
function transformPath(type: keyof typeof BASE_SHAPES, target: Coord[]): { flips: 0 | 1; rots: 0 | 1 | 2 | 3 } | null {
  const tgt = key(target);
  for (const flips of [0, 1] as const) {
    let cur = normalize(BASE_SHAPES[type]);
    if (flips === 1) cur = flipH(cur);
    for (const rots of [0, 1, 2, 3] as const) {
      if (key(cur) === tgt) return { flips, rots };
      cur = rotate90(cur);
    }
  }
  return null;
}

function targetCellInsideMove(move: CandidateMove): { r: number; c: number } {
  // Тащим к центру bounding box фигуры в её позиции на доске.
  let maxR = 0;
  let maxC = 0;
  for (const [dr, dc] of move.cells) {
    if (dr > maxR) maxR = dr;
    if (dc > maxC) maxC = dc;
  }
  return { r: move.r + Math.floor(maxR / 2), c: move.c + Math.floor(maxC / 2) };
}

async function playOneTurn(opts: Required<PilotOpts>, rng: () => number): Promise<boolean> {
  const s = readPilotState();
  if (!s || !s.playing || !s.myTurn) return false;

  const move = chooseBotMove(s.board, s.myHand, opts.level, s.cfg, rng);
  if (!move) {
    record("noMove", { handLen: s.myHand.length });
    return false;
  }

  // 1) Tap на slot нужной фигуры.
  const handIdx = s.myHand.findIndex((p: PieceInstance) => p.id === move.pieceId);
  if (handIdx < 0) {
    record("error", { msg: "piece not in hand", move });
    return false;
  }
  const slot = findMyHandSlot(handIdx);
  if (!slot) {
    record("error", { msg: "hand slot not found", handIdx });
    return false;
  }
  record("selectPiece", { handIdx, type: move.type });
  await tap(slot);

  // 2) Применить flip/rotate, чтобы sel соответствовала move.cells.
  const path = transformPath(move.type, move.cells);
  if (!path) {
    record("error", { msg: "no transform path", type: move.type });
    return false;
  }
  if (path.flips === 1 && s.cfg.flipEnabled) {
    const btn = findFlipBtn();
    if (btn) {
      record("flip");
      await clickEl(btn);
    }
  }
  for (let i = 0; i < path.rots && s.cfg.rotationEnabled; i++) {
    const btn = findRotateBtn();
    if (btn) {
      record("rotate", { i: i + 1, of: path.rots });
      await clickEl(btn);
    }
  }

  // 3) Drag из hand-slot в целевую клетку доски.
  const tgt = targetCellInsideMove(move);
  const rect = boardCellRect(tgt.r, tgt.c);
  if (!rect) {
    record("error", { msg: "board cell not found", r: tgt.r, c: tgt.c });
    return false;
  }
  const slotAgain = findMyHandSlot(handIdx);
  if (!slotAgain) {
    record("error", { msg: "hand slot vanished pre-drag", handIdx });
    return false;
  }
  // dummy DOM element для drag target — нам нужен только bounding rect, поэтому используем сам cell.
  const cells = document.querySelectorAll<HTMLElement>(".board .cell");
  const cellEl = cells[tgt.r * 9 + tgt.c];
  if (!cellEl) {
    record("error", { msg: "cell element absent" });
    return false;
  }
  record("drag", { from: { handIdx }, to: { r: tgt.r, c: tgt.c }, move: { pieceId: move.pieceId, r: move.r, c: move.c } });
  await drag(slotAgain, cellEl, 10);
  record("moveSent", { pieceId: move.pieceId, r: move.r, c: move.c });
  return true;
}

export async function startPilot(opts: PilotOpts = {}): Promise<void> {
  if (running) return;
  running = true;
  paused = false;
  resetJournal();
  const tickMs = opts.tickMs ?? 600;
  const level = opts.level ?? "medium";
  const seed = opts.seed ?? (Math.floor(Math.random() * 0xffff) || 1234);
  const rng = makeRng(seed);
  record("start", { level, seed, tickMs });

  while (running) {
    if (!paused) {
      try {
        const acted = await playOneTurn({ tickMs, level, seed }, rng);
        if (!acted) await sleep(tickMs);
        else await sleep(400); // cooldown между ходами
      } catch (e) {
        record("error", { msg: String(e) });
        await sleep(tickMs);
      }
    } else {
      await sleep(200);
    }
  }
  record("stop");
}

export function pausePilot(): void {
  paused = true;
}

export function resumePilot(): void {
  paused = false;
}

export function stopPilot(): void {
  running = false;
}

export function isPilotRunning(): boolean {
  return running && !paused;
}
