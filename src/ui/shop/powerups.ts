/**
 * Power-ups, расходуемые в одиночных режимах (vs Bot, hot-seat, arcade).
 * Покупаются за кристаллы в магазине, копятся в `Inventory`.
 *
 * В онлайне не используются (server-authoritative).
 */

export type PowerupId =
  | "stick_row"
  | "stick_col"
  | "bomb_3x3"
  | "swap_hand"
  | "hint"
  | "auto_play";

export interface PowerupDef {
  id: PowerupId;
  name: string;
  description: string;
  icon: string;
  /** Цена 1 штуки в кристаллах. */
  price: number;
  /** Краткая инструкция как использовать. */
  hint: string;
}

export const POWERUPS: PowerupDef[] = [
  {
    id: "hint",
    name: "Подсказка",
    description: "Подсветит лучший ход на 3 секунды",
    icon: "💡",
    price: 1,
    hint: "тапни и посмотри подсветку",
  },
  {
    id: "swap_hand",
    name: "Обмен руки",
    description: "Заменит все фигуры в руке на новые",
    icon: "🔄",
    price: 2,
    hint: "одно нажатие — новая рука",
  },
  {
    id: "stick_row",
    name: "Палочка-молния (строка)",
    description: "Очищает выбранную строку. Очки идут тебе.",
    icon: "↔️",
    price: 3,
    hint: "тапни → клетка → строка чистится",
  },
  {
    id: "stick_col",
    name: "Палочка-молния (столбец)",
    description: "Очищает выбранный столбец. Очки идут тебе.",
    icon: "↕️",
    price: 3,
    hint: "тапни → клетка → столбец чистится",
  },
  {
    id: "bomb_3x3",
    name: "Бомба 3×3",
    description: "Очищает квадрат 3×3 вокруг выбранной клетки",
    icon: "💣",
    price: 4,
    hint: "тапни → центр взрыва → бах",
  },
  {
    id: "auto_play",
    name: "Умный ход",
    description: "ИИ сам поставит фигуру в лучшее место",
    icon: "🧠",
    price: 5,
    hint: "одно нажатие — ход за тебя",
  },
];

export const POWERUPS_BY_ID: Record<PowerupId, PowerupDef> = Object.fromEntries(
  POWERUPS.map((p) => [p.id, p]),
) as Record<PowerupId, PowerupDef>;
