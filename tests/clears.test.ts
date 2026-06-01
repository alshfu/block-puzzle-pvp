import { describe, expect, it } from "vitest";
import {
  SIZE,
  emptyBoard,
  place,
  findClears,
  applyClears,
  isPerfectClear,
  type Board,
  type Coord,
} from "../src/core";

function fillRow(board: Board, r: number) {
  for (let c = 0; c < SIZE; c++) board[r][c] = { filled: true, owner: 0 };
}
function fillCol(board: Board, c: number) {
  for (let r = 0; r < SIZE; r++) board[r][c] = { filled: true, owner: 0 };
}
function fillBox(board: Board, b: number) {
  const br = Math.floor(b / 3) * 3, bc = (b % 3) * 3;
  for (let r = 0; r < 3; r++)
    for (let c = 0; c < 3; c++) board[br + r][bc + c] = { filled: true, owner: 0 };
}

describe("findClears", () => {
  it("пустая доска — ничего не очищается", () => {
    const b = emptyBoard();
    const res = findClears(b);
    expect(res.count).toBe(0);
    expect(res.cleared).toHaveLength(0);
  });

  it("одна полная строка → одна очистка, 9 клеток", () => {
    const b = emptyBoard();
    fillRow(b, 4);
    const res = findClears(b);
    expect(res.count).toBe(1);
    expect(res.rows).toEqual([4]);
    expect(res.cleared).toHaveLength(SIZE);
  });

  it("один полный столбец → одна очистка, 9 клеток", () => {
    const b = emptyBoard();
    fillCol(b, 0);
    const res = findClears(b);
    expect(res.count).toBe(1);
    expect(res.cols).toEqual([0]);
    expect(res.cleared).toHaveLength(SIZE);
  });

  it("один полный бокс 3×3 → одна очистка, 9 клеток", () => {
    const b = emptyBoard();
    fillBox(b, 4); // центральный бокс
    const res = findClears(b);
    expect(res.count).toBe(1);
    expect(res.boxes).toEqual([4]);
    expect(res.cleared).toHaveLength(9);
  });

  it("строка + столбец, пересекающиеся: count=2, клеток 17 (без дубля)", () => {
    const b = emptyBoard();
    fillRow(b, 3);
    fillCol(b, 5);
    const res = findClears(b);
    expect(res.count).toBe(2);
    expect(res.cleared.length).toBe(SIZE + SIZE - 1); // 17
  });

  it("строка + столбец + бокс на пересечении: count=3, клеток уникальны", () => {
    const b = emptyBoard();
    fillRow(b, 0);
    fillCol(b, 0);
    fillBox(b, 0); // верхний-левый бокс пересекается со строкой 0 и столбцом 0
    const res = findClears(b);
    expect(res.count).toBe(3);
    // |row(0)| + |col(0) \ {(0,0)}| + |box(0) \ row0 \ col0|
    // row(0)=9, col(0) уникальных 8, box(0) уникальных = 9 - 3(перес. со строкой) - 2 (доп. со столбцом) = 4 → 9+8+4=21
    expect(new Set(res.cleared.map(([r, c]: Coord) => `${r},${c}`)).size)
      .toBe(res.cleared.length);
    expect(res.cleared.length).toBe(21);
  });

  it("applyClears + isPerfectClear: после очистки полностью заполненной доски — пусто", () => {
    const b = emptyBoard();
    for (let r = 0; r < SIZE; r++) for (let c = 0; c < SIZE; c++) b[r][c] = { filled: true, owner: 0 };
    const res = findClears(b);
    applyClears(b, res.cleared);
    expect(isPerfectClear(b)).toBe(true);
  });

  it("place + findClears согласованы: ставим 4 клетки в почти полную строку", () => {
    const b = emptyBoard();
    // заполнили строку 5 кроме клеток (5,0..3)
    for (let c = 4; c < SIZE; c++) b[5][c] = { filled: true, owner: 0 };
    // ставим I (горизонталь) в (5,0)
    const I: Coord[] = [[0, 0], [0, 1], [0, 2], [0, 3]];
    place(b, I, 5, 0, 1);
    const res = findClears(b);
    expect(res.rows).toEqual([5]);
    expect(res.count).toBe(1);
  });
});
