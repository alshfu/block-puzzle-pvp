/**
 * BlockDuel 9x9 — игровое ядро (чистое, детерминированное, без зависимостей от UI).
 * Демоверсия. Тот же модуль предназначен к переиспользованию на клиенте и сервере.
 */

// ─────────────────────────────────────────────────────────────
// Типы
// ─────────────────────────────────────────────────────────────
export const SIZE = 9;

export type PieceType = "I" | "O" | "T" | "S" | "Z" | "J" | "L";
export type Coord = [number, number]; // [row, col]

export interface Cell {
  filled: boolean;
  owner: number | null; // 0 | 1 — только для подсветки
}

export type Board = Cell[][];

export type TimeoutPolicy = "forcePlace" | "skip";

export interface RuleConfig {
  handSize: number;        // K
  rotationEnabled: boolean;
  flipEnabled: boolean;
  sharedBag: boolean;      // false => у каждого свой мешок
  comboEnabled: boolean;
  comboCap: number;
  comboStep: number;
  perfectClearBonus: number;

  // Blitz-таймер (ТЗ § 2.7.1). Само тиканье — на UI; ядро только хранит параметры
  // и предоставляет forcePlace для постановки на таймауте.
  turnTimerEnabled: boolean;
  turnTimeStart: number;   // секунд на первый ход
  turnTimeDecay: number;   // вычитаем за каждый полный раунд
  turnTimeMin: number;     // нижняя граница
  onTimeout: TimeoutPolicy;
}

export const DEFAULT_CONFIG: RuleConfig = {
  handSize: 3,
  rotationEnabled: true,
  flipEnabled: true,
  sharedBag: false,
  comboEnabled: true,
  comboCap: 10,
  comboStep: 0.1,
  perfectClearBonus: 15,
  turnTimerEnabled: true,
  turnTimeStart: 12.0,
  turnTimeDecay: 0.4,
  turnTimeMin: 3.0,
  onTimeout: "forcePlace",
};

/** Время на ход для заданного номера раунда (раунд = пара ходов обоих игроков). */
export function turnTimeForRound(round: number, cfg: RuleConfig): number {
  if (!cfg.turnTimerEnabled) return Infinity;
  const t = cfg.turnTimeStart - cfg.turnTimeDecay * Math.max(0, round);
  return Math.max(cfg.turnTimeMin, t);
}

export interface PieceInstance {
  id: string;       // уникальный id экземпляра в руке
  type: PieceType;
  cells: Coord[];   // нормализованные клетки в текущей ориентации
}

// ─────────────────────────────────────────────────────────────
// PRNG (детерминированный) — mulberry32
// ─────────────────────────────────────────────────────────────
export function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle<T>(arr: T[], rng: () => number): T[] {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// ─────────────────────────────────────────────────────────────
// Фигуры (тетромино) — базовые офсеты
// ─────────────────────────────────────────────────────────────
export const BASE_SHAPES: Record<PieceType, Coord[]> = {
  I: [[0, 0], [0, 1], [0, 2], [0, 3]],
  O: [[0, 0], [0, 1], [1, 0], [1, 1]],
  T: [[0, 0], [0, 1], [0, 2], [1, 1]],
  S: [[0, 1], [0, 2], [1, 0], [1, 1]],
  Z: [[0, 0], [0, 1], [1, 1], [1, 2]],
  J: [[0, 0], [1, 0], [1, 1], [1, 2]],
  L: [[0, 2], [1, 0], [1, 1], [1, 2]],
};

export const ALL_TYPES: PieceType[] = ["I", "O", "T", "S", "Z", "J", "L"];

export function normalize(cells: Coord[]): Coord[] {
  const minR = Math.min(...cells.map((c) => c[0]));
  const minC = Math.min(...cells.map((c) => c[1]));
  return cells
    .map(([r, c]) => [r - minR, c - minC] as Coord)
    .sort((a, b) => a[0] - b[0] || a[1] - b[1]);
}

export function rotate90(cells: Coord[]): Coord[] {
  // (r,c) -> (c, -r)
  return normalize(cells.map(([r, c]) => [c, -r] as Coord));
}

export function flipH(cells: Coord[]): Coord[] {
  return normalize(cells.map(([r, c]) => [r, -c] as Coord));
}

function key(cells: Coord[]): string {
  return cells.map(([r, c]) => `${r},${c}`).join("|");
}

/** Все уникальные ориентации фигуры при заданных настройках. */
export function orientations(
  type: PieceType,
  rotationEnabled: boolean,
  flipEnabled: boolean
): Coord[][] {
  const seen = new Set<string>();
  const result: Coord[][] = [];
  let bases = [normalize(BASE_SHAPES[type])];
  if (flipEnabled) bases.push(flipH(BASE_SHAPES[type]));

  for (const base of bases) {
    let cur = base;
    const rots = rotationEnabled ? 4 : 1;
    for (let i = 0; i < rots; i++) {
      const k = key(cur);
      if (!seen.has(k)) {
        seen.add(k);
        result.push(cur);
      }
      cur = rotate90(cur);
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────────
// Мешок (7-bag)
// ─────────────────────────────────────────────────────────────
export class Bag {
  private queue: PieceType[] = [];
  private rng: () => number;
  private counter = 0;

  constructor(seed: number) {
    this.rng = makeRng(seed);
  }

  next(): PieceType {
    if (this.queue.length === 0) {
      this.queue = shuffle(ALL_TYPES, this.rng);
    }
    return this.queue.shift()!;
  }

  draw(): PieceInstance {
    const type = this.next();
    return {
      id: `p${this.counter++}`,
      type,
      cells: normalize(BASE_SHAPES[type]),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// Доска
// ─────────────────────────────────────────────────────────────
export function emptyBoard(): Board {
  return Array.from({ length: SIZE }, () =>
    Array.from({ length: SIZE }, () => ({ filled: false, owner: null }))
  );
}

export function cloneBoard(b: Board): Board {
  return b.map((row) => row.map((c) => ({ ...c })));
}

export function canPlace(board: Board, cells: Coord[], r: number, c: number): boolean {
  for (const [dr, dc] of cells) {
    const rr = r + dr, cc = c + dc;
    if (rr < 0 || rr >= SIZE || cc < 0 || cc >= SIZE) return false;
    if (board[rr][cc].filled) return false;
  }
  return true;
}

export function place(board: Board, cells: Coord[], r: number, c: number, owner: number): void {
  for (const [dr, dc] of cells) {
    board[r + dr][c + dc] = { filled: true, owner };
  }
}

export interface ClearResult {
  count: number;     // число очищенных единиц (строк+столбцов+боксов)
  cleared: Coord[];  // уникальные клетки к очистке
  rows: number[];
  cols: number[];
  boxes: number[];
}

export function findClears(board: Board): ClearResult {
  const rows: number[] = [];
  const cols: number[] = [];
  const boxes: number[] = [];

  for (let r = 0; r < SIZE; r++) {
    if (board[r].every((c) => c.filled)) rows.push(r);
  }
  for (let c = 0; c < SIZE; c++) {
    let full = true;
    for (let r = 0; r < SIZE; r++) if (!board[r][c].filled) { full = false; break; }
    if (full) cols.push(c);
  }
  for (let b = 0; b < SIZE; b++) {
    const br = Math.floor(b / 3) * 3, bc = (b % 3) * 3;
    let full = true;
    for (let r = 0; r < 3 && full; r++)
      for (let c = 0; c < 3; c++)
        if (!board[br + r][bc + c].filled) { full = false; break; }
    if (full) boxes.push(b);
  }

  const set = new Set<string>();
  const add = (r: number, c: number) => set.add(`${r},${c}`);
  for (const r of rows) for (let c = 0; c < SIZE; c++) add(r, c);
  for (const c of cols) for (let r = 0; r < SIZE; r++) add(r, c);
  for (const b of boxes) {
    const br = Math.floor(b / 3) * 3, bc = (b % 3) * 3;
    for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) add(br + r, bc + c);
  }
  const cleared = [...set].map((s) => s.split(",").map(Number) as Coord);
  return { count: rows.length + cols.length + boxes.length, cleared, rows, cols, boxes };
}

export function applyClears(board: Board, cleared: Coord[]): void {
  for (const [r, c] of cleared) board[r][c] = { filled: false, owner: null };
}

export function isPerfectClear(board: Board): boolean {
  for (let r = 0; r < SIZE; r++)
    for (let c = 0; c < SIZE; c++)
      if (board[r][c].filled) return false;
  return true;
}

// ─────────────────────────────────────────────────────────────
// Очки
// ─────────────────────────────────────────────────────────────
export function scoreForMove(
  N: number,
  comboCounter: number,
  perfect: boolean,
  cfg: RuleConfig
): number {
  if (N === 0) return 0;
  const base = (N * (N + 1)) / 2;
  const mult = cfg.comboEnabled
    ? 1 + cfg.comboStep * Math.min(comboCounter, cfg.comboCap)
    : 1;
  const bonus = perfect ? cfg.perfectClearBonus : 0;
  return Math.round(base * mult) + bonus;
}

// ─────────────────────────────────────────────────────────────
// Перебор допустимых ходов / проверка тупика
// ─────────────────────────────────────────────────────────────
export interface CandidateMove {
  pieceId: string;
  type: PieceType;
  cells: Coord[];
  r: number;
  c: number;
}

export function enumerateMoves(
  board: Board,
  hand: PieceInstance[],
  cfg: RuleConfig
): CandidateMove[] {
  const moves: CandidateMove[] = [];
  for (const piece of hand) {
    for (const oriented of orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled)) {
      const maxR = Math.max(...oriented.map((x) => x[0]));
      const maxC = Math.max(...oriented.map((x) => x[1]));
      for (let r = 0; r + maxR < SIZE; r++) {
        for (let c = 0; c + maxC < SIZE; c++) {
          if (canPlace(board, oriented, r, c)) {
            moves.push({ pieceId: piece.id, type: piece.type, cells: oriented, r, c });
          }
        }
      }
    }
  }
  return moves;
}

export function pieceHasMove(board: Board, piece: PieceInstance, cfg: RuleConfig): boolean {
  return hasAnyMove(board, [piece], cfg);
}

export function hasAnyMove(board: Board, hand: PieceInstance[], cfg: RuleConfig): boolean {
  for (const piece of hand) {
    for (const oriented of orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled)) {
      const maxR = Math.max(...oriented.map((x) => x[0]));
      const maxC = Math.max(...oriented.map((x) => x[1]));
      for (let r = 0; r + maxR < SIZE; r++)
        for (let c = 0; c + maxC < SIZE; c++)
          if (canPlace(board, oriented, r, c)) return true;
    }
  }
  return false;
}

// ─────────────────────────────────────────────────────────────
// Бот (3 уровня)
// ─────────────────────────────────────────────────────────────
export type BotLevel = "easy" | "medium" | "hard";

function countHoles(board: Board): number {
  // пустая клетка считается «дырой», если со всех 4 сторон заблокирована (край или filled)
  let holes = 0;
  for (let r = 0; r < SIZE; r++)
    for (let c = 0; c < SIZE; c++) {
      if (board[r][c].filled) continue;
      const blocked =
        (r === 0 || board[r - 1][c].filled) &&
        (r === SIZE - 1 || board[r + 1][c].filled) &&
        (c === 0 || board[r][c - 1].filled) &&
        (c === SIZE - 1 || board[r][c + 1].filled);
      if (blocked) holes++;
    }
  return holes;
}

function nearLines(board: Board): number {
  // строки/столбцы/боксы, которым не хватает 1–2 клеток => заготовки
  let score = 0;
  const credit = (missing: number) => (missing === 1 ? 3 : missing === 2 ? 1 : 0);
  for (let r = 0; r < SIZE; r++) {
    let filled = 0;
    for (let c = 0; c < SIZE; c++) if (board[r][c].filled) filled++;
    score += credit(SIZE - filled);
  }
  for (let c = 0; c < SIZE; c++) {
    let filled = 0;
    for (let r = 0; r < SIZE; r++) if (board[r][c].filled) filled++;
    score += credit(SIZE - filled);
  }
  for (let b = 0; b < SIZE; b++) {
    const br = Math.floor(b / 3) * 3, bc = (b % 3) * 3;
    let filled = 0;
    for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) if (board[br + r][bc + c].filled) filled++;
    score += credit(9 - filled);
  }
  return score;
}

function evaluate(board: Board): number {
  return 1.0 * nearLines(board) - 4.0 * countHoles(board);
}

/** Симулирует ход и возвращает {board, clears, perfect}. */
export function simulate(board: Board, move: CandidateMove, owner: number) {
  const b = cloneBoard(board);
  place(b, move.cells, move.r, move.c, owner);
  const clears = findClears(b);
  applyClears(b, clears.cleared);
  return { board: b, clears, perfect: isPerfectClear(b) };
}

export function chooseBotMove(
  board: Board,
  hand: PieceInstance[],
  level: BotLevel,
  cfg: RuleConfig,
  rng: () => number
): CandidateMove | null {
  const moves = enumerateMoves(board, hand, cfg);
  if (moves.length === 0) return null;

  if (level === "easy") {
    // в 30% случаев берёт очевидную очистку, иначе случайный ход
    if (rng() < 0.3) {
      const scoring = moves.filter((m) => simulate(board, m, 1).clears.count > 0);
      if (scoring.length) return scoring[Math.floor(rng() * scoring.length)];
    }
    return moves[Math.floor(rng() * moves.length)];
  }

  // medium / hard — оценка позиции
  let best: CandidateMove | null = null;
  let bestScore = -Infinity;
  for (const m of moves) {
    const sim = simulate(board, m, 1);
    const gain = scoreForMove(sim.clears.count, 0, sim.perfect, cfg);
    let s = gain * 10 + evaluate(sim.board);
    if (level === "hard") {
      // штраф за «дырки» сильнее + лёгкий учёт того, что мы дарим сопернику почти-готовые линии
      s = gain * 12 + evaluate(sim.board) - 0.5 * nearLines(sim.board) * 0; // hook под денай
      s = gain * 12 + 1.2 * nearLines(sim.board) - 5.0 * countHoles(sim.board);
    }
    s += (rng() - 0.5) * 0.01; // микрошум для разнообразия
    if (s > bestScore) { bestScore = s; best = m; }
  }
  return best;
}

// ─────────────────────────────────────────────────────────────
// Force-place на таймауте (ТЗ § 2.7.1)
// ─────────────────────────────────────────────────────────────
/**
 * Возвращает случайный валидный ход из руки. Если preferredPieceId задан и эта
 * фигура ещё может встать — выбирается её случайная валидная позиция; иначе —
 * случайная валидная пара (фигура, позиция) из всей руки. `null` => тупик.
 */
export function forcePlace(
  board: Board,
  hand: PieceInstance[],
  cfg: RuleConfig,
  rng: () => number,
  preferredPieceId?: string
): CandidateMove | null {
  const all = enumerateMoves(board, hand, cfg);
  if (all.length === 0) return null;
  if (preferredPieceId) {
    const subset = all.filter((m) => m.pieceId === preferredPieceId);
    if (subset.length > 0) return subset[Math.floor(rng() * subset.length)];
  }
  return all[Math.floor(rng() * all.length)];
}
