import { describe, it, expect } from "vitest";
import {
  ALL_TYPES,
  BASE_SHAPES,
  DEFAULT_CONFIG,
  flipH,
  normalize,
  orientations,
  rotate90,
  type Coord,
} from "../src/core";
import { transformPath } from "../src/ui/pilot/pilot";

function key(cells: Coord[]): string {
  return normalize(cells)
    .map(([r, c]) => `${r},${c}`)
    .join("|");
}

describe("pilot transformPath", () => {
  it("returns identity (0/0) for the base orientation of every piece", () => {
    for (const t of ALL_TYPES) {
      const path = transformPath(t, normalize(BASE_SHAPES[t]));
      expect(path).toEqual({ flips: 0, rots: 0 });
    }
  });

  it("finds a valid path for every reachable orientation under DEFAULT_CONFIG", () => {
    for (const t of ALL_TYPES) {
      const all = orientations(t, DEFAULT_CONFIG.rotationEnabled, DEFAULT_CONFIG.flipEnabled);
      for (const target of all) {
        const path = transformPath(t, target);
        expect(path).not.toBeNull();
        if (!path) continue;

        // Воспроизводим путь и сравниваем с target.
        let cur = normalize(BASE_SHAPES[t]);
        if (path.flips === 1) cur = flipH(cur);
        for (let i = 0; i < path.rots; i++) cur = rotate90(cur);
        expect(key(cur)).toBe(key(target));
      }
    }
  });

  it("orientations count matches expected per piece (sanity)", () => {
    const counts: Record<string, number> = {};
    for (const t of ALL_TYPES) {
      counts[t] = orientations(t, true, true).length;
    }
    expect(counts).toEqual({ I: 2, O: 1, T: 4, S: 4, Z: 4, J: 8, L: 8 });
  });
});
