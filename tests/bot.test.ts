import { describe, expect, it } from "vitest";
import {
  DEFAULT_CONFIG,
  Bag,
  BOT_WEIGHTS,
  chooseBotMove,
  emptyBoard,
  enumerateMoves,
  makeRng,
  opponentThreatGain,
  place,
  SIZE,
  type PieceInstance,
  type Board,
  type BotLevel,
} from "../legacy-ts/core";

function drawHand(seed: number, n: number): PieceInstance[] {
  const bag = new Bag(seed);
  const h: PieceInstance[] = [];
  for (let i = 0; i < n; i++) h.push(bag.draw());
  return h;
}

function fullBoard(): Board {
  const b = emptyBoard();
  for (let r = 0; r < 9; r++) for (let c = 0; c < 9; c++) b[r][c] = { filled: true, owner: 0 };
  return b;
}

describe("chooseBotMove", () => {
  const levels: BotLevel[] = ["easy", "medium", "hard"];

  for (const lvl of levels) {
    it(`${lvl}: на пустой доске возвращает валидный ход`, () => {
      const hand = drawHand(1, 3);
      const move = chooseBotMove(emptyBoard(), hand, lvl, DEFAULT_CONFIG, makeRng(1));
      expect(move).not.toBeNull();
      const legal = enumerateMoves(emptyBoard(), hand, DEFAULT_CONFIG);
      expect(legal.some((m) => m.r === move!.r && m.c === move!.c && m.pieceId === move!.pieceId))
        .toBe(true);
    });

    it(`${lvl}: полная доска → null (тупик)`, () => {
      const hand = drawHand(1, 3);
      const move = chooseBotMove(fullBoard(), hand, lvl, DEFAULT_CONFIG, makeRng(1));
      expect(move).toBeNull();
    });
  }

  it("medium/hard в среднем не слабее easy при равной случайности — sanity (не зависает)", () => {
    // мы не валидируем «силу» здесь (это для bot-vs-bot симуляций),
    // только что несколько подряд вызовов не падают и возвращают валидные ходы.
    const board = emptyBoard();
    const hand = drawHand(7, 3);
    for (const lvl of levels) {
      for (let i = 0; i < 5; i++) {
        const m = chooseBotMove(board, hand, lvl, DEFAULT_CONFIG, makeRng(i + 1));
        expect(m).not.toBeNull();
      }
    }
  });

  it("после применения хода доска валидна (нет выхода за границы и наложений)", () => {
    const board = emptyBoard();
    const hand = drawHand(3, 3);
    const move = chooseBotMove(board, hand, "medium", DEFAULT_CONFIG, makeRng(3))!;
    place(board, move.cells, move.r, move.c, 1);
    let filled = 0;
    for (const row of board) for (const cell of row) if (cell.filled) filled++;
    expect(filled).toBe(4); // тетромино = 4 клетки
  });

  it("BOT_WEIGHTS экспортирован и содержит все уровни", () => {
    expect(BOT_WEIGHTS.easy).toBeDefined();
    expect(BOT_WEIGHTS.medium).toBeDefined();
    expect(BOT_WEIGHTS.hard).toBeDefined();
  });

  it("hard не должен думать дольше ~300мс на любом разумном ходу (ТЗ § 5)", () => {
    // Доска с разной заполненностью — проверим несколько сценариев.
    const cases: Board[] = [emptyBoard(), emptyBoard()];
    // частично заполненная: заполним ~30 клеток
    for (let i = 0; i < 30; i++) {
      const r = i % SIZE, c = (i * 3) % SIZE;
      cases[1][r][c] = { filled: true, owner: 0 };
    }
    for (const board of cases) {
      const hand = drawHand(11, 3);
      const t0 = performance.now();
      chooseBotMove(board, hand, "hard", DEFAULT_CONFIG, makeRng(11));
      const dt = performance.now() - t0;
      expect(dt).toBeLessThan(300);
    }
  });
});

describe("opponentThreatGain", () => {
  it("пустая доска → 0 угроз", () => {
    expect(opponentThreatGain(emptyBoard())).toBe(0);
  });

  it("одна строка без последней клетки → 1 угроза", () => {
    const b = emptyBoard();
    for (let c = 0; c < SIZE - 1; c++) b[3][c] = { filled: true, owner: 0 };
    expect(opponentThreatGain(b)).toBe(1);
  });

  it("столбец и бокс с missing=1 пересекаются: учитываем оба раза", () => {
    const b = emptyBoard();
    // столбец 0 заполнен кроме (0,0)
    for (let r = 1; r < SIZE; r++) b[r][0] = { filled: true, owner: 0 };
    // бокс 0 (верхний-левый 3×3) заполнен кроме (0,0)
    for (let r = 0; r < 3; r++)
      for (let c = 0; c < 3; c++)
        if (!(r === 0 && c === 0)) b[r][c] = { filled: true, owner: 0 };
    const threat = opponentThreatGain(b);
    // в строке 0 две filled-клетки (1,0)(2,0) — не missing=1.
    // столбец 0: missing=1 → +1. бокс 0: missing=1 → +1.
    expect(threat).toBe(2);
  });
});
