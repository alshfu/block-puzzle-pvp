import { describe, expect, it } from "vitest";
import { DEFAULT_CONFIG, scoreForMove, scoreMoveDetailed, type RuleConfig } from "../src/core";

const cfg = (over: Partial<RuleConfig> = {}): RuleConfig => ({ ...DEFAULT_CONFIG, ...over });

describe("scoreForMove (legacy API)", () => {
  it("0 очищенных единиц без perfect → 0 очков", () => {
    expect(scoreForMove(0, 0, false, cfg())).toBe(0);
    // 0 очисток с perfect → даёт только perfect bonus
    expect(scoreForMove(0, 5, true, cfg())).toBe(cfg().perfectClearBonus);
  });

  it("базовая формула (v1.5+): N*scoreRowPts с multi-clear-mult", () => {
    const c = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    // N=1 → 1*10 * (1 + 0 * 0.15) = 10
    expect(scoreForMove(1, 0, false, c)).toBe(10);
    // N=2 → 2*10 * (1 + 1*0.15) = 23
    expect(scoreForMove(2, 0, false, c)).toBe(23);
    // N=3 → 3*10 * (1 + 2*0.15) = 39
    expect(scoreForMove(3, 0, false, c)).toBe(39);
    // N=4 → 4*10 * (1 + 3*0.15) = 58
    expect(scoreForMove(4, 0, false, c)).toBe(58);
  });

  it("комбо: linear до 3, экспоненциально дальше", () => {
    const c = cfg({ perfectClearBonus: 0 });
    // N=2, combo=3 → mult = 1 + 0.3 + 0 = 1.3, multiClear=1.15 → 23 * 1.3 ≈ 29.9 → 30
    expect(scoreForMove(2, 3, false, c)).toBe(30);
    // N=2, combo=10 (cap) → mult = 1 + 1.0 + 0.02*7² = 2 + 0.98 = 2.98, multiClear=1.15
    //   → round(20 * 1.15 * 2.98) = round(68.54) = 69
    expect(scoreForMove(2, 10, false, c)).toBe(69);
    // combo=999 — выше cap, но экспонента продолжает расти на основе фактического combo
    expect(scoreForMove(2, 999, false, c)).toBeGreaterThan(69);
  });

  it("perfect clear bonus", () => {
    // N=1, perfect: round(10 * 1) + 25 = 35
    expect(scoreForMove(1, 0, true, cfg())).toBe(35);
  });

  it("comboEnabled=false отключает множитель", () => {
    const noCombo = cfg({ comboEnabled: false });
    // N=3 → base=30, multiClear=1.3 → 39, +perfect=25 если perfect
    expect(scoreForMove(3, 5, false, noCombo)).toBe(39);
    expect(scoreForMove(3, 5, true, noCombo)).toBe(39 + 25);
  });
});

describe("scoreMoveDetailed (v1.5+)", () => {
  it("boxes дают больше очков чем rows/cols", () => {
    const c = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    const rowOnly = scoreMoveDetailed({ rows: 1, cols: 0, boxes: 0, pieceType: "O", combo: 0, perfect: false, cfg: c });
    const boxOnly = scoreMoveDetailed({ rows: 0, cols: 0, boxes: 1, pieceType: "O", combo: 0, perfect: false, cfg: c });
    expect(boxOnly.base).toBeGreaterThan(rowOnly.base);
  });

  it("placement-бонус начисляется даже без очисток", () => {
    const c = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    const iPiece = scoreMoveDetailed({ rows: 0, cols: 0, boxes: 0, pieceType: "I", combo: 0, perfect: false, cfg: c });
    expect(iPiece.total).toBe(5); // I bonus = 5
    const oPiece = scoreMoveDetailed({ rows: 0, cols: 0, boxes: 0, pieceType: "O", combo: 0, perfect: false, cfg: c });
    expect(oPiece.total).toBe(0); // O bonus = 0
  });

  it("multi-clear-mult растёт с N", () => {
    const c = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    const single = scoreMoveDetailed({ rows: 1, cols: 0, boxes: 0, pieceType: "O", combo: 0, perfect: false, cfg: c });
    const triple = scoreMoveDetailed({ rows: 1, cols: 1, boxes: 1, pieceType: "O", combo: 0, perfect: false, cfg: c });
    expect(triple.multiClearMult).toBeCloseTo(1.3, 5);
    expect(single.multiClearMult).toBe(1);
  });

  it("speed-бонус при оставшемся времени > 50%", () => {
    const c = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    const slow = scoreMoveDetailed({ rows: 1, cols: 0, boxes: 0, pieceType: "O", combo: 0, perfect: false, timeRatio: 0.3, cfg: c });
    const fast = scoreMoveDetailed({ rows: 1, cols: 0, boxes: 0, pieceType: "O", combo: 0, perfect: false, timeRatio: 1.0, cfg: c });
    expect(slow.speedMult).toBe(1);
    expect(fast.speedMult).toBeCloseTo(1 + c.speedBonusMax, 5);
  });

  it("комбо экспоненциальная часть включается после combo>3", () => {
    const c = cfg({ perfectClearBonus: 0 });
    const c3 = scoreMoveDetailed({ rows: 2, cols: 0, boxes: 0, pieceType: "O", combo: 3, perfect: false, cfg: c });
    const c4 = scoreMoveDetailed({ rows: 2, cols: 0, boxes: 0, pieceType: "O", combo: 4, perfect: false, cfg: c });
    // combo=3: только линейная (1 + 0.3 + 0)
    expect(c3.comboMult).toBeCloseTo(1.3, 5);
    // combo=4: линейная + экспоненциальная (1 + 0.4 + 0.02)
    expect(c4.comboMult).toBeCloseTo(1.42, 5);
  });

  it("breakdown суммируется корректно", () => {
    const c = cfg();
    const b = scoreMoveDetailed({ rows: 1, cols: 1, boxes: 1, pieceType: "I", combo: 5, perfect: true, timeRatio: 1.0, cfg: c });
    const expected = Math.round(b.base * b.multiClearMult * b.comboMult * b.speedMult) + b.placement + b.perfectBonus;
    expect(b.total).toBe(expected);
  });
});
