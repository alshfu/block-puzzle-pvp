import { describe, expect, it } from "vitest";
import { DEFAULT_CONFIG, turnTimeForRound, type RuleConfig } from "../src/core";

describe("turnTimeForRound", () => {
  it("без таймера → Infinity", () => {
    const cfg: RuleConfig = { ...DEFAULT_CONFIG, turnTimerEnabled: false };
    expect(turnTimeForRound(0, cfg)).toBe(Infinity);
    expect(turnTimeForRound(100, cfg)).toBe(Infinity);
  });

  it("раунд 0: turnTimeStart", () => {
    expect(turnTimeForRound(0, DEFAULT_CONFIG)).toBeCloseTo(DEFAULT_CONFIG.turnTimeStart, 6);
  });

  it("уменьшается на decay каждый раунд", () => {
    const t1 = turnTimeForRound(1, DEFAULT_CONFIG);
    expect(t1).toBeCloseTo(DEFAULT_CONFIG.turnTimeStart - DEFAULT_CONFIG.turnTimeDecay, 6);
  });

  it("не опускается ниже turnTimeMin", () => {
    expect(turnTimeForRound(10_000, DEFAULT_CONFIG)).toBe(DEFAULT_CONFIG.turnTimeMin);
  });
});
