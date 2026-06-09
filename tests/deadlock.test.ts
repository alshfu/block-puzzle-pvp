import { describe, expect, it } from "vitest";
import {
  SIZE,
  DEFAULT_CONFIG,
  emptyBoard,
  hasAnyMove,
  enumerateMoves,
  forcePlace,
  makeRng,
  type PieceInstance,
  type Board,
} from "../legacy-ts/core";

function makePiece(id: string, type: PieceInstance["type"]): PieceInstance {
  // cells здесь не используются enumerateMoves (он берёт ориентации от type),
  // но поле обязательно по типу — заполним пустышкой.
  return { id, type, cells: [[0, 0]] };
}

function fullBoard(): Board {
  const b = emptyBoard();
  for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) b[r][c] = { filled: true, owner: 0 };
  return b;
}

describe("hasAnyMove / тупик", () => {
  it("на пустой доске любая рука даёт ход", () => {
    expect(hasAnyMove(emptyBoard(), [makePiece("p0", "I")], DEFAULT_CONFIG)).toBe(true);
  });

  it("полная доска → тупик для любой руки", () => {
    expect(hasAnyMove(fullBoard(), [makePiece("p0", "I"), makePiece("p1", "T")], DEFAULT_CONFIG))
      .toBe(false);
  });

  it("пустая рука → тупик", () => {
    expect(hasAnyMove(emptyBoard(), [], DEFAULT_CONFIG)).toBe(false);
  });

  it("enumerateMoves возвращает >0 ходов на пустой доске с одной I", () => {
    const moves = enumerateMoves(emptyBoard(), [makePiece("p0", "I")], DEFAULT_CONFIG);
    expect(moves.length).toBeGreaterThan(0);
  });
});

describe("forcePlace", () => {
  it("на тупике возвращает null", () => {
    const move = forcePlace(fullBoard(), [makePiece("p0", "I")], DEFAULT_CONFIG, makeRng(1));
    expect(move).toBeNull();
  });

  it("на пустой доске возвращает валидный ход", () => {
    const piece = makePiece("p0", "T");
    const move = forcePlace(emptyBoard(), [piece], DEFAULT_CONFIG, makeRng(1));
    expect(move).not.toBeNull();
    expect(move!.pieceId).toBe("p0");
  });

  it("preferredPieceId: если фигура ставится — выбирает её", () => {
    const hand = [makePiece("p0", "I"), makePiece("p1", "O")];
    const move = forcePlace(emptyBoard(), hand, DEFAULT_CONFIG, makeRng(5), "p1");
    expect(move).not.toBeNull();
    expect(move!.pieceId).toBe("p1");
  });

  it("preferredPieceId недоступна → fallback на любую другую", () => {
    // Доска полностью заполнена кроме квадрата 2×2 в углу: O помещается, I — нет.
    const b = fullBoard();
    b[0][0] = { filled: false, owner: null };
    b[0][1] = { filled: false, owner: null };
    b[1][0] = { filled: false, owner: null };
    b[1][1] = { filled: false, owner: null };
    const hand = [makePiece("p0", "I"), makePiece("p1", "O")];
    const move = forcePlace(b, hand, DEFAULT_CONFIG, makeRng(3), "p0");
    expect(move).not.toBeNull();
    expect(move!.pieceId).toBe("p1"); // I не встаёт, остался только O
  });
});
