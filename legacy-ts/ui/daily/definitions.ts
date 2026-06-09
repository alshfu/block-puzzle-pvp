import type { BotLevel } from "../../core";
import type { GameMode } from "../screens/MenuScreen";

export type QuestKind =
  | "clear_lines"           // очисти N линий/боксов суммарно за день
  | "perfect_clears"        // perfect clear за день
  | "win_mode"              // выиграй N матчей в указанном режиме
  | "beat_bot"              // победи бота указанного уровня N раз
  | "combo_at_least"        // достигни комбо ≥X
  | "arcade_score";         // набери X очков в одной аркадной партии

export interface QuestDef {
  id: string;
  kind: QuestKind;
  title: string;
  description: string;
  icon: string;
  target: number;
  reward: number;           // монеты
  // фильтры
  mode?: GameMode;
  botLevel?: BotLevel;
  comboMin?: number;
}

export const QUEST_POOL: QuestDef[] = [
  {
    id: "clear_20",
    kind: "clear_lines",
    title: "Чистильщик дня",
    description: "Очисти 20 линий/боксов за день",
    icon: "🧹",
    target: 20,
    reward: 30,
  },
  {
    id: "clear_50",
    kind: "clear_lines",
    title: "Большая уборка",
    description: "Очисти 50 линий/боксов за день",
    icon: "🧽",
    target: 50,
    reward: 75,
  },
  {
    id: "perfect_1",
    kind: "perfect_clears",
    title: "Безупречный день",
    description: "Сделай 1 perfect clear",
    icon: "💎",
    target: 1,
    reward: 50,
  },
  {
    id: "win_bot_3",
    kind: "beat_bot",
    title: "Охотник на ботов",
    description: "Выиграй у бота 3 раза",
    icon: "🤖",
    target: 3,
    reward: 40,
  },
  {
    id: "win_hard_1",
    kind: "beat_bot",
    title: "Удар по Сложному",
    description: "Победи Hard-бота",
    icon: "👹",
    target: 1,
    reward: 60,
    botLevel: "hard",
  },
  {
    id: "combo_4",
    kind: "combo_at_least",
    title: "Цепная реакция",
    description: "Достигни комбо ×4 в одной партии",
    icon: "🔥",
    target: 1,
    reward: 35,
    comboMin: 4,
  },
  {
    id: "arcade_150",
    kind: "arcade_score",
    title: "Соло-чемпион",
    description: "Набери 150 очков в Аркаде за одну партию",
    icon: "🏆",
    target: 150,
    reward: 60,
    mode: "arcade",
  },
];

export const QUEST_BY_ID: Record<string, QuestDef> = Object.fromEntries(
  QUEST_POOL.map((q) => [q.id, q]),
);
