/**
 * Bot-vs-bot симулятор для калибровки баланса (ТЗ § 10).
 *
 * Запуск:
 *   npx tsx tools/bot-sim.ts                     # дефолтный прогон (10000 партий, все пары уровней)
 *   npx tsx tools/bot-sim.ts --games 2000        # меньше партий
 *   npx tsx tools/bot-sim.ts --pair medium,hard  # только одна пара
 *   npx tsx tools/bot-sim.ts --weights           # сравнение разных весов hard
 *
 * Метрики (на пару p0 vs p1):
 *   - winrate p0 / p1 / draw
 *   - avg turns per match
 *   - avg score (median, p90)
 *   - avg max combo
 *   - max multi-clear ever
 *   - avg ms per move (sanity по ТЗ — hard < 300мс)
 */

import {
  Bag,
  BOT_WEIGHTS,
  chooseBotMove,
  cloneBoard,
  DEFAULT_CONFIG,
  emptyBoard,
  findClears,
  applyClears,
  hasAnyMove,
  isPerfectClear,
  makeRng,
  place,
  scoreForMove,
  forcePlace,
  type Board,
  type BotLevel,
  type BotWeights,
  type PieceInstance,
  type RuleConfig,
} from "../src/core";

interface SimResult {
  p0Wins: number;
  p1Wins: number;
  draws: number;
  scores0: number[];
  scores1: number[];
  turns: number[];
  maxClearEver: number;
  msPerMove: number;
  totalMoves: number;
  forcePlaces: number;
}

interface Player {
  score: number;
  combo: number;
  hand: PieceInstance[];
}

function playMatch(
  level0: BotLevel,
  level1: BotLevel,
  cfg: RuleConfig,
  seed: number,
  weights0?: BotWeights,
  weights1?: BotWeights,
  maxTurns = 120,
): {
  score0: number;
  score1: number;
  turns: number;
  maxClear: number;
  totalMs: number;
  moves: number;
  forced: number;
} {
  const bags: [Bag, Bag] = [new Bag(seed + 11), new Bag(seed + 99)];
  const rngs = [makeRng(seed + 100), makeRng(seed + 200)] as const;
  const ws: [BotWeights | undefined, BotWeights | undefined] = [weights0, weights1];
  const levels: [BotLevel, BotLevel] = [level0, level1];
  const handSize = cfg.handSize;
  const board: Board = emptyBoard();
  const players: [Player, Player] = [
    {
      score: 0,
      combo: 0,
      hand: Array.from({ length: handSize }, () => bags[0].draw()),
    },
    {
      score: 0,
      combo: 0,
      hand: Array.from({ length: handSize }, () => bags[1].draw()),
    },
  ];

  let turns = 0;
  let maxClear = 0;
  let totalMs = 0;
  let moves = 0;
  let forced = 0;
  let current: 0 | 1 = 0;

  while (turns < maxTurns) {
    if (!hasAnyMove(board, players[current].hand, cfg)) break;
    const t0 = performance.now();
    let move = chooseBotMove(
      board,
      players[current].hand,
      levels[current],
      cfg,
      rngs[current],
      ws[current],
    );
    if (!move) {
      // safety: force-place — на практике не должно срабатывать после hasAnyMove,
      // но оставляем для корректности
      move = forcePlace(board, players[current].hand, cfg, rngs[current]);
      forced++;
    }
    if (!move) break;
    totalMs += performance.now() - t0;
    moves++;

    const newBoard = cloneBoard(board);
    place(newBoard, move.cells, move.r, move.c, current);
    const cl = findClears(newBoard);
    let perfect = false;
    if (cl.count > 0) {
      maxClear = Math.max(maxClear, cl.count);
      // perfect: после applyClears доска пуста
      const probe = cloneBoard(newBoard);
      applyClears(probe, cl.cleared);
      perfect = isPerfectClear(probe);
      const gained = scoreForMove(cl.count, players[current].combo, perfect, cfg);
      players[current].score += gained;
      players[current].combo += 1;
    } else {
      players[current].combo = 0;
    }
    // mutate board in-place
    for (let r = 0; r < 9; r++) for (let c = 0; c < 9; c++) board[r][c] = newBoard[r][c];
    if (cl.count > 0) applyClears(board, cl.cleared);

    // refill hand
    players[current].hand = players[current].hand.filter((p) => p.id !== move!.pieceId);
    while (players[current].hand.length < handSize) players[current].hand.push(bags[current].draw());

    current = (1 - current) as 0 | 1;
    turns++;
  }

  return {
    score0: players[0].score,
    score1: players[1].score,
    turns,
    maxClear,
    totalMs,
    moves,
    forced,
  };
}

function runPair(
  level0: BotLevel,
  level1: BotLevel,
  games: number,
  cfg: RuleConfig,
  w0?: BotWeights,
  w1?: BotWeights,
): SimResult {
  const r: SimResult = {
    p0Wins: 0,
    p1Wins: 0,
    draws: 0,
    scores0: [],
    scores1: [],
    turns: [],
    maxClearEver: 0,
    msPerMove: 0,
    totalMoves: 0,
    forcePlaces: 0,
  };
  let totalMs = 0;
  for (let i = 0; i < games; i++) {
    const seed = 1000 + i * 7;
    const m = playMatch(level0, level1, cfg, seed, w0, w1);
    if (m.score0 > m.score1) r.p0Wins++;
    else if (m.score1 > m.score0) r.p1Wins++;
    else r.draws++;
    r.scores0.push(m.score0);
    r.scores1.push(m.score1);
    r.turns.push(m.turns);
    if (m.maxClear > r.maxClearEver) r.maxClearEver = m.maxClear;
    totalMs += m.totalMs;
    r.totalMoves += m.moves;
    r.forcePlaces += m.forced;
  }
  r.msPerMove = r.totalMoves > 0 ? totalMs / r.totalMoves : 0;
  return r;
}

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  const n = s.length;
  if (n === 0) return 0;
  return n % 2 ? s[(n - 1) >> 1] : (s[n / 2 - 1] + s[n / 2]) / 2;
}

function pct(xs: number[], p: number): number {
  const s = [...xs].sort((a, b) => a - b);
  if (s.length === 0) return 0;
  const idx = Math.min(s.length - 1, Math.floor(s.length * p));
  return s[idx];
}

function avg(xs: number[]): number {
  if (xs.length === 0) return 0;
  let s = 0;
  for (const x of xs) s += x;
  return s / xs.length;
}

function report(label: string, r: SimResult): void {
  const total = r.p0Wins + r.p1Wins + r.draws;
  const wr0 = ((r.p0Wins / total) * 100).toFixed(1);
  const wr1 = ((r.p1Wins / total) * 100).toFixed(1);
  const wrD = ((r.draws / total) * 100).toFixed(1);
  console.log(`\n=== ${label} (${total} games) ===`);
  console.log(`  winrate:   p0 ${wr0}%   p1 ${wr1}%   draw ${wrD}%`);
  console.log(`  turns:     avg ${avg(r.turns).toFixed(1)}   median ${median(r.turns).toFixed(0)}   p90 ${pct(r.turns, 0.9)}`);
  console.log(`  score p0:  avg ${avg(r.scores0).toFixed(1)}   median ${median(r.scores0)}   p90 ${pct(r.scores0, 0.9)}`);
  console.log(`  score p1:  avg ${avg(r.scores1).toFixed(1)}   median ${median(r.scores1)}   p90 ${pct(r.scores1, 0.9)}`);
  console.log(`  max clear (best move ever): ${r.maxClearEver}`);
  console.log(`  ms / move: ${r.msPerMove.toFixed(2)}   (ТЗ: hard < 300ms)`);
  console.log(`  forcePlaces: ${r.forcePlaces}`);
}

// ──────────────────────────────────────────────────────────────────────────
// CLI
// ──────────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const getOpt = (k: string, def: string): string => {
  const i = args.indexOf(k);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : def;
};

const games = parseInt(getOpt("--games", "10000"), 10);
const pairArg = getOpt("--pair", "");
const cfg: RuleConfig = { ...DEFAULT_CONFIG, turnTimerEnabled: false };

const levels: BotLevel[] = ["easy", "medium", "hard"];
const pairs: [BotLevel, BotLevel][] = pairArg
  ? [pairArg.split(",") as [BotLevel, BotLevel]]
  : [
      ["easy", "medium"],
      ["medium", "hard"],
      ["easy", "hard"],
      ["medium", "medium"],
      ["hard", "hard"],
    ];

console.log(`BlockDuel bot-vs-bot calibration · games=${games} · timer=off`);
console.log(`weights:`);
for (const lvl of levels) console.log(`  ${lvl}:`, JSON.stringify(BOT_WEIGHTS[lvl]));

for (const [a, b] of pairs) {
  const r = runPair(a, b, games, cfg);
  report(`${a} (p0) vs ${b} (p1)`, r);
}

console.log(`\nDone.`);
