export type AchievementCategory = "single" | "progressive" | "series" | "hidden";

export interface AchievementDef {
  id: string;
  title: string;
  description: string;
  icon: string;
  total: number;          // прогресс target
  hidden?: boolean;       // скрыто пока не разблокировано
  category: AchievementCategory;
  rewardXp: number;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  // ─── Single-event ───────────────────────────────────────────────────────
  {
    id: "first_blood",
    title: "Первая кровь",
    description: "Выиграй свою первую партию",
    icon: "🩸",
    total: 1,
    category: "single",
    rewardXp: 50,
  },
  {
    id: "flawless",
    title: "Безупречно",
    description: "Сделай perfect clear (опустоши доску одним ходом)",
    icon: "💎",
    total: 1,
    category: "single",
    rewardXp: 75,
  },
  {
    id: "combinator",
    title: "Комбинатор",
    description: "Очисти 4 линии/бокса одним ходом",
    icon: "💥",
    total: 1,
    category: "single",
    rewardXp: 50,
  },
  {
    id: "ai_tamer",
    title: "Укротитель ИИ",
    description: "Победи бота уровня Сложный",
    icon: "🤖",
    total: 1,
    category: "single",
    rewardXp: 100,
  },
  {
    id: "strategist",
    title: "Стратег",
    description: "Достигни комбо ×5 в одной партии",
    icon: "🧠",
    total: 5,
    category: "single",
    rewardXp: 75,
  },

  // ─── Progressive ────────────────────────────────────────────────────────
  {
    id: "cleaner_100",
    title: "Чистильщик",
    description: "Очисти 100 линий/боксов суммарно",
    icon: "🧹",
    total: 100,
    category: "progressive",
    rewardXp: 50,
  },
  {
    id: "cleaner_1k",
    title: "Опытный чистильщик",
    description: "Очисти 1 000 линий/боксов суммарно",
    icon: "🧽",
    total: 1000,
    category: "progressive",
    rewardXp: 200,
  },
  {
    id: "cleaner_10k",
    title: "Мастер очистки",
    description: "Очисти 10 000 линий/боксов суммарно",
    icon: "✨",
    total: 10000,
    category: "progressive",
    rewardXp: 1000,
  },
  {
    id: "veteran_10",
    title: "Ветеран",
    description: "Сыграй 10 партий",
    icon: "🎮",
    total: 10,
    category: "progressive",
    rewardXp: 50,
  },
  {
    id: "veteran_100",
    title: "Старожил",
    description: "Сыграй 100 партий",
    icon: "🏆",
    total: 100,
    category: "progressive",
    rewardXp: 250,
  },

  // ─── Series ─────────────────────────────────────────────────────────────
  {
    id: "streak_3",
    title: "В ударе",
    description: "Выиграй 3 партии подряд",
    icon: "🔥",
    total: 3,
    category: "series",
    rewardXp: 50,
  },
  {
    id: "streak_5",
    title: "Доминатор",
    description: "Выиграй 5 партий подряд",
    icon: "💪",
    total: 5,
    category: "series",
    rewardXp: 100,
  },
  {
    id: "streak_10",
    title: "Чемпион",
    description: "Выиграй 10 партий подряд",
    icon: "👑",
    total: 10,
    category: "series",
    rewardXp: 250,
  },

  // ─── Hidden ─────────────────────────────────────────────────────────────
  {
    id: "king_five",
    title: "Король пятёрки",
    description: "Очисти 5+ линий/боксов одним ходом",
    icon: "🕵",
    total: 1,
    category: "hidden",
    hidden: true,
    rewardXp: 150,
  },
  {
    id: "persistence",
    title: "Упорство",
    description: "Сыграй 3 партии подряд через «Реванш»",
    icon: "🔁",
    total: 3,
    category: "hidden",
    hidden: true,
    rewardXp: 50,
  },
];

export const ACHIEVEMENTS_BY_ID: Record<string, AchievementDef> = Object.fromEntries(
  ACHIEVEMENTS.map((a) => [a.id, a]),
);
