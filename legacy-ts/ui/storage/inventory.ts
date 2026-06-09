import type { PowerupId } from "../shop/powerups";
import { readJSON, writeJSON } from "./storage";

const KEY = "bd_inventory";

export type Inventory = Record<PowerupId, number>;

export const DEFAULT_INVENTORY: Inventory = {
  stick_row: 0,
  stick_col: 0,
  bomb_3x3: 0,
  swap_hand: 0,
  hint: 0,
  auto_play: 0,
};

export function loadInventory(): Inventory {
  const raw = readJSON<Partial<Inventory>>(KEY, {});
  return {
    stick_row: Math.max(0, raw.stick_row ?? 0),
    stick_col: Math.max(0, raw.stick_col ?? 0),
    bomb_3x3: Math.max(0, raw.bomb_3x3 ?? 0),
    swap_hand: Math.max(0, raw.swap_hand ?? 0),
    hint: Math.max(0, raw.hint ?? 0),
    auto_play: Math.max(0, raw.auto_play ?? 0),
  };
}

export function saveInventory(i: Inventory): void {
  writeJSON(KEY, i);
}
