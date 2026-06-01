import { describe, expect, it } from "vitest";
import {
  DEFAULT_CONFIG,
  Bag,
  emptyBoard,
  enumerateMoves,
  place,
  findClears,
  applyClears,
  scoreForMove,
  isPerfectClear,
  hasAnyMove,
  type Board,
  type PieceInstance,
} from "../src/core";

/**
 * Golden test: один и тот же matchSeed + один и тот же набор детерминированных
 * решений (используем фиксированный выбор «первый возможный ход») приводят
 * к идентичному состоянию доски и счёту. Это закрепляет требование ТЗ § 2.9.
 */
function runDeterministicGame(seedA: number, seedB: number, turns: number) {
  const bagA = new Bag(seedA);
  const bagB = new Bag(seedB);
  const board: Board = emptyBoard();
  const handA: PieceInstance[] = [bagA.draw(), bagA.draw(), bagA.draw()];
  const handB: PieceInstance[] = [bagB.draw(), bagB.draw(), bagB.draw()];
  const hands = [handA, handB];
  const bags = [bagA, bagB];
  const scores = [0, 0];
  const combos = [0, 0];

  for (let t = 0; t < turns; t++) {
    const player = t % 2;
    const hand = hands[player];
    if (!hasAnyMove(board, hand, DEFAULT_CONFIG)) break;
    const moves = enumerateMoves(board, hand, DEFAULT_CONFIG);
    const m = moves[0]; // детерминированный выбор
    place(board, m.cells, m.r, m.c, player);
    const clears = findClears(board);
    applyClears(board, clears.cleared);
    const perfect = clears.count > 0 && isPerfectClear(board);
    const gained = scoreForMove(clears.count, combos[player], perfect, DEFAULT_CONFIG);
    scores[player] += gained;
    combos[player] = clears.count > 0 ? combos[player] + 1 : 0;
    // refill hand
    const idx = hand.findIndex((p) => p.id === m.pieceId);
    hand.splice(idx, 1);
    hand.push(bags[player].draw());
  }
  return { board, scores, combos };
}

describe("Детерминизм ядра", () => {
  it("одинаковый seed → одинаковое состояние и счёт", () => {
    const a = runDeterministicGame(11, 22, 40);
    const b = runDeterministicGame(11, 22, 40);
    expect(b.scores).toEqual(a.scores);
    expect(b.combos).toEqual(a.combos);
    expect(JSON.stringify(b.board)).toBe(JSON.stringify(a.board));
  });

  it("разные seed → как правило, разные состояния", () => {
    const a = runDeterministicGame(11, 22, 40);
    const c = runDeterministicGame(99, 100, 40);
    // допускаем мизерную вероятность совпадения; на 40 ходах фактически 0
    expect(JSON.stringify(c.board)).not.toBe(JSON.stringify(a.board));
  });
});
