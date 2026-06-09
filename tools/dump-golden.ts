/**
 * dump-golden.ts — генератор golden-эталона детерминизма ядра для Dart-порта.
 *
 * За что отвечает файл:
 *   Одноразовый (повторяемый) скрипт, который прогоняет ТЕКУЩЕЕ TS-ядро
 *   (`src/core`) на фиксированных сидах и выгружает результат в JSON
 *   `flutter/test/golden/determinism_match.json`. Dart-порт ядра (Фаза 1)
 *   обязан воспроизвести этот JSON бит-в-бит — это gate Фазы 1
 *   (см. MIGRATION_FLUTTER.md §7).
 *
 * Почему послойно:
 *   Если Dart разойдётся с эталоном, послойные секции (rng → bag →
 *   orientations → scoring → clears → game) показывают, НА КАКОМ слое
 *   началось расхождение, а не просто «финальная доска не совпала».
 *
 * Секции дампа:
 *   meta         — версия, дата, описание формата.
 *   rng          — сырые выходы mulberry32 для набора сидов (фундамент).
 *   bag          — последовательности типов фигур из 7-bag (Bag.draw).
 *   orientations — все уникальные ориентации каждой фигуры (rotation+flip).
 *   scoring      — выходы scoreForMove и scoreMoveDetailed на наборе входов.
 *   clears       — findClears на сконструированных досках (строка/столбец/бокс).
 *   game         — полный пошаговый трейс детерминированной партии (харнесс
 *                  идентичен `tests/determinism.test.ts`): на каждом ходу
 *                  берётся moves[0], без участия rng в решениях.
 *
 * Запуск:
 *   npx tsx tools/dump-golden.ts
 *
 * Кодировка доски (`encodeBoard`):
 *   строка из 81 символа (9×9, row-major): '.' — пусто, '0'/'1' — владелец.
 *   Компактна и тривиально воспроизводится в Dart.
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  ALL_TYPES,
  applyClears,
  Bag,
  Board,
  DEFAULT_CONFIG,
  emptyBoard,
  enumerateMoves,
  findClears,
  hasAnyMove,
  isPerfectClear,
  makeRng,
  orientations,
  PieceInstance,
  place,
  PieceType,
  scoreForMove,
  scoreMoveDetailed,
  SIZE,
} from "../legacy-ts/core";

// ── Параметры эталона ───────────────────────────────────────────────────────

/** Сиды для проверки сырого PRNG. Граничные включены намеренно (0, 2^32-1). */
const rngSeeds = [1, 1337, 0, 4294967295, 123456789];
/** Сколько чисел снять с каждого rng. */
const rngCount = 16;

/** Сиды для проверки 7-bag. 21 = три полных мешка. */
const bagSeeds = [1, 11, 22, 1337];
const bagCount = 21;

/** Партии для game-трейса: (seedA, seedB, число полу-ходов). */
const gameRuns = [
  { seedA: 11, seedB: 22, turns: 40 },
  { seedA: 7, seedB: 99, turns: 60 },
  { seedA: 123, seedB: 456, turns: 80 },
];

// ── Кодирование доски ────────────────────────────────────────────────────────

/** Кодирует доску в строку из 81 символа: '.'=пусто, '0'/'1'=владелец. */
function encodeBoard(board: Board): string {
  let out = "";
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const cell = board[r][c];
      out += cell.filled ? String(cell.owner ?? 0) : ".";
    }
  }
  return out;
}

// ── Секция: rng ──────────────────────────────────────────────────────────────

/** Снимает первые rngCount значений mulberry32 для каждого сида. */
function dumpRng() {
  return rngSeeds.map((seed) => {
    const rng = makeRng(seed);
    const values: number[] = [];
    for (let i = 0; i < rngCount; i++) values.push(rng());
    return { seed, count: rngCount, values };
  });
}

// ── Секция: bag ──────────────────────────────────────────────────────────────

/** Тянет bagCount фигур из Bag(seed) и пишет их типы. */
function dumpBag() {
  return bagSeeds.map((seed) => {
    const bag = new Bag(seed);
    const types: PieceType[] = [];
    for (let i = 0; i < bagCount; i++) types.push(bag.draw().type);
    return { seed, count: bagCount, types };
  });
}

// ── Секция: orientations ─────────────────────────────────────────────────────

/** Все уникальные ориентации каждой фигуры при DEFAULT (rotation+flip on). */
function dumpOrientations() {
  const out: Record<string, number[][][]> = {};
  for (const type of ALL_TYPES) {
    out[type] = orientations(
      type,
      DEFAULT_CONFIG.rotationEnabled,
      DEFAULT_CONFIG.flipEnabled,
    );
  }
  return out;
}

// ── Секция: scoring ──────────────────────────────────────────────────────────

/** Набор входов, покрывающих combo, multi-clear, perfect, speed-бонус. */
function dumpScoring() {
  const cfg = DEFAULT_CONFIG;
  const cases = [
    { rows: 1, cols: 0, boxes: 0, pieceType: "I" as PieceType, combo: 0, perfect: false, timeRatio: 0 },
    { rows: 2, cols: 1, boxes: 0, pieceType: "L" as PieceType, combo: 2, perfect: false, timeRatio: 0.75 },
    { rows: 0, cols: 0, boxes: 1, pieceType: "O" as PieceType, combo: 5, perfect: false, timeRatio: 1 },
    { rows: 3, cols: 3, boxes: 3, pieceType: "T" as PieceType, combo: 8, perfect: true, timeRatio: 0.9 },
    { rows: 0, cols: 0, boxes: 0, pieceType: "S" as PieceType, combo: 0, perfect: false, timeRatio: 0.2 },
  ];
  return cases.map((input) => ({
    input,
    scoreForMove: scoreForMove(
      input.rows + input.cols + input.boxes,
      input.combo,
      input.perfect,
      cfg,
    ),
    detailed: scoreMoveDetailed({ ...input, cfg }),
  }));
}

// ── Секция: clears ───────────────────────────────────────────────────────────

/** findClears на сконструированных досках (полная строка / столбец / бокс). */
function dumpClears() {
  const out: Array<{
    name: string;
    board: string;
    count: number;
    rows: number[];
    cols: number[];
    boxes: number[];
    clearedCount: number;
  }> = [];

  const fillRow = (b: Board, r: number) => {
    for (let c = 0; c < SIZE; c++) place(b, [[0, 0]], r, c, 0);
  };
  const fillCol = (b: Board, c: number) => {
    for (let r = 0; r < SIZE; r++) place(b, [[0, 0]], r, c, 1);
  };
  const fillBox = (b: Board, box: number) => {
    const br = Math.floor(box / 3) * 3;
    const bc = (box % 3) * 3;
    for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) place(b, [[0, 0]], br + r, bc + c, 0);
  };

  const scenarios: Array<[string, (b: Board) => void]> = [
    ["row0", (b) => fillRow(b, 0)],
    ["col4", (b) => fillCol(b, 4)],
    ["box0", (b) => fillBox(b, 0)],
    ["box8", (b) => fillBox(b, 8)],
    ["row8+col0", (b) => { fillRow(b, 8); fillCol(b, 0); }],
  ];

  for (const [name, build] of scenarios) {
    const b = emptyBoard();
    build(b);
    const res = findClears(b);
    out.push({
      name,
      board: encodeBoard(b),
      count: res.count,
      rows: res.rows,
      cols: res.cols,
      boxes: res.boxes,
      clearedCount: res.cleared.length,
    });
  }
  return out;
}

// ── Секция: game ─────────────────────────────────────────────────────────────

/**
 * Детерминированный харнесс партии. ИДЕНТИЧЕН `tests/determinism.test.ts`:
 *   - у каждого игрока свой Bag(seed), рука из 3 фигур через draw();
 *   - на ходу t игрок = t%2; если нет ходов — стоп;
 *   - выбирается moves[0] (детерминированно, без rng);
 *   - place → findClears → applyClears → perfect;
 *   - очки: scoreForMove(count, combo[player], perfect, cfg);
 *   - combo[player] = count>0 ? combo+1 : 0;
 *   - фигура удаляется по pieceId, рука пополняется draw().
 * Dart-тест Фазы 1 повторяет этот харнесс ровно так же.
 */
function dumpGame(seedA: number, seedB: number, turns: number) {
  const cfg = DEFAULT_CONFIG;
  const bags = [new Bag(seedA), new Bag(seedB)];
  const board = emptyBoard();
  const hands: PieceInstance[][] = [
    [bags[0].draw(), bags[0].draw(), bags[0].draw()],
    [bags[1].draw(), bags[1].draw(), bags[1].draw()],
  ];
  const scores = [0, 0];
  const combos = [0, 0];
  const moves: unknown[] = [];

  for (let t = 0; t < turns; t++) {
    const player = t % 2;
    const hand = hands[player];
    if (!hasAnyMove(board, hand, cfg)) break;
    const m = enumerateMoves(board, hand, cfg)[0];
    place(board, m.cells, m.r, m.c, player);
    const clears = findClears(board);
    applyClears(board, clears.cleared);
    const perfect = clears.count > 0 && isPerfectClear(board);
    const gained = scoreForMove(clears.count, combos[player], perfect, cfg);
    scores[player] += gained;
    combos[player] = clears.count > 0 ? combos[player] + 1 : 0;

    moves.push({
      t,
      player,
      pieceId: m.pieceId,
      type: m.type,
      r: m.r,
      c: m.c,
      cells: m.cells,
      clearCount: clears.count,
      rows: clears.rows,
      cols: clears.cols,
      boxes: clears.boxes,
      perfect,
      gained,
      scoreAfter: scores[player],
      comboAfter: combos[player],
    });

    const idx = hand.findIndex((p) => p.id === m.pieceId);
    hand.splice(idx, 1);
    hand.push(bags[player].draw());
  }

  return {
    seedA,
    seedB,
    turns,
    movesPlayed: moves.length,
    moves,
    finalBoard: encodeBoard(board),
    scores,
    combos,
  };
}

// ── Сборка и запись ──────────────────────────────────────────────────────────

const golden = {
  meta: {
    description:
      "Golden determinism reference for the Dart core port. Produced by " +
      "tools/dump-golden.ts from the live TS core (src/core). The Dart port " +
      "must reproduce every section bit-for-bit. Board encoding: 81 chars, " +
      "row-major, '.'=empty, '0'/'1'=owner.",
    sourceVersion: "1.6.1",
    generatedFrom: "src/core",
  },
  rng: dumpRng(),
  bag: dumpBag(),
  orientations: dumpOrientations(),
  scoring: dumpScoring(),
  clears: dumpClears(),
  game: gameRuns.map((g) => dumpGame(g.seedA, g.seedB, g.turns)),
};

const scriptDir = dirname(fileURLToPath(import.meta.url));
const outPath = resolve(
  scriptDir,
  "../flutter/test/golden/determinism_match.json",
);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(golden, null, 2) + "\n", "utf8");

// eslint-disable-next-line no-console
console.log(
  `golden written → ${outPath}\n` +
    `  rng: ${golden.rng.length} seeds × ${rngCount}\n` +
    `  bag: ${golden.bag.length} seeds × ${bagCount}\n` +
    `  orientations: ${Object.keys(golden.orientations).length} pieces\n` +
    `  scoring: ${golden.scoring.length} cases\n` +
    `  clears: ${golden.clears.length} scenarios\n` +
    `  game: ${golden.game.map((g) => `${g.movesPlayed}/${g.turns}`).join(", ")} moves`,
);
