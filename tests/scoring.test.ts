import { describe, expect, it } from "vitest";
import { DEFAULT_CONFIG, scoreForMove, type RuleConfig } from "../src/core";

const cfg = (over: Partial<RuleConfig> = {}): RuleConfig => ({ ...DEFAULT_CONFIG, ...over });

describe("scoreForMove", () => {
  it("0 очищенных единиц → 0 очков", () => {
    expect(scoreForMove(0, 0, false, cfg())).toBe(0);
    expect(scoreForMove(0, 5, true, cfg())).toBe(0);
  });

  it("триангулярная база: 1→1, 2→3, 3→6, 4→10, 5→15", () => {
    const noCombo = cfg({ comboEnabled: false, perfectClearBonus: 0 });
    expect(scoreForMove(1, 0, false, noCombo)).toBe(1);
    expect(scoreForMove(2, 0, false, noCombo)).toBe(3);
    expect(scoreForMove(3, 0, false, noCombo)).toBe(6);
    expect(scoreForMove(4, 0, false, noCombo)).toBe(10);
    expect(scoreForMove(5, 0, false, noCombo)).toBe(15);
  });

  it("комбо: множитель 1 + 0.1·min(combo, cap)", () => {
    // N=2 → base=3; combo=3 → mult=1.3 → 3.9 → round = 4
    expect(scoreForMove(2, 3, false, cfg())).toBe(4);
    // combo=10 (cap) → mult=2 → 6
    expect(scoreForMove(2, 10, false, cfg())).toBe(6);
    // combo=999 (выше cap) → также mult=2 → 6
    expect(scoreForMove(2, 999, false, cfg())).toBe(6);
  });

  it("perfect clear: +15 поверх базы", () => {
    // N=1 + perfect: round(1 · 1.0) + 15 = 16
    expect(scoreForMove(1, 0, true, cfg())).toBe(16);
  });

  it("comboEnabled=false отключает множитель, бонус остаётся", () => {
    const noCombo = cfg({ comboEnabled: false });
    expect(scoreForMove(3, 5, false, noCombo)).toBe(6);
    expect(scoreForMove(3, 5, true, noCombo)).toBe(6 + 15);
  });
});
