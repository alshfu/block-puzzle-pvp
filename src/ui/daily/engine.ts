import type { BotLevel } from "../../core";
import type { GameMode } from "../screens/MenuScreen";
import type { DailyState } from "../storage/daily";
import { QUEST_BY_ID, type QuestDef } from "./definitions";

export interface DailyMatchContext {
  mode: GameMode;
  winner: 0 | 1 | -1;
  myScore: number;
  totalClearsThisMatch: number;
  hadPerfectClear: boolean;
  bestComboThisMatch: number;
  botLevel?: BotLevel;
}

interface ApplyResult {
  next: DailyState;
  /** Квесты, которые **только что** были выполнены (для тоста). */
  newlyCompleted: QuestDef[];
}

export function applyMatchToDaily(prev: DailyState, ctx: DailyMatchContext): ApplyResult {
  const next: DailyState = { ...prev, quests: prev.quests.map((q) => ({ ...q })) };
  const newlyCompleted: QuestDef[] = [];
  for (const q of next.quests) {
    if (q.completed) continue;
    const def = QUEST_BY_ID[q.defId];
    if (!def) continue;
    let inc = 0;
    switch (def.kind) {
      case "clear_lines":
        inc = ctx.totalClearsThisMatch;
        break;
      case "perfect_clears":
        inc = ctx.hadPerfectClear ? 1 : 0;
        break;
      case "win_mode":
        if (ctx.winner === 0 && (!def.mode || def.mode === ctx.mode)) inc = 1;
        break;
      case "beat_bot":
        if (ctx.winner === 0 && ctx.mode === "bot" && (!def.botLevel || def.botLevel === ctx.botLevel)) inc = 1;
        break;
      case "combo_at_least":
        if (ctx.bestComboThisMatch >= (def.comboMin ?? def.target)) inc = 1;
        break;
      case "arcade_score":
        if (ctx.mode === "arcade" && ctx.myScore >= def.target) {
          q.current = def.target; // одним выстрелом
        }
        break;
    }
    if (def.kind !== "arcade_score") q.current = Math.min(def.target, q.current + inc);
    if (q.current >= def.target && !q.completed) {
      q.completed = true;
      newlyCompleted.push(def);
    }
  }
  return { next, newlyCompleted };
}

export function claimQuest(prev: DailyState, defId: string): {
  next: DailyState;
  coinsAwarded: number;
} {
  const next: DailyState = { ...prev, quests: prev.quests.map((q) => ({ ...q })) };
  let coinsAwarded = 0;
  for (const q of next.quests) {
    if (q.defId === defId && q.completed && !q.claimed) {
      const def = QUEST_BY_ID[defId];
      q.claimed = true;
      coinsAwarded = def?.reward ?? 0;
    }
  }
  return { next, coinsAwarded };
}
