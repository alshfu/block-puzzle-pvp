import { describe, expect, it } from "vitest";
import {
  DEFAULT_CONFIG,
  Bag,
  chooseBotMove,
  emptyBoard,
  enumerateMoves,
  makeRng,
  place,
  type PieceInstance,
  type Board,
  type BotLevel,
} from "../src/core";

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
});
