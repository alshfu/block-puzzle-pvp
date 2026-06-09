export type SkinId = "default" | "gem" | "bullet" | "neon" | "pixel" | "candy";

export interface SkinDef {
  id: SkinId;
  name: string;
  description: string;
  icon: string;       // эмодзи для preview
  price: number;      // 0 = бесплатно (по умолчанию разблокирован)
  /** Дополнительный CSS-класс на `.cell.filled` (применяется к доске). */
  cssClass: string;
}

export const SKINS: SkinDef[] = [
  {
    id: "default",
    name: "Базовый",
    description: "Глянцевый градиент в фирменных цветах темы",
    icon: "🧱",
    price: 0,
    cssClass: "skin-default",
  },
  {
    id: "gem",
    name: "Самоцветы",
    description: "Гранёные камни с бликом",
    icon: "💎",
    price: 80,
    cssClass: "skin-gem",
  },
  {
    id: "bullet",
    name: "Пули",
    description: "Холодный металл, лёгкая текстура",
    icon: "🔫",
    price: 120,
    cssClass: "skin-bullet",
  },
  {
    id: "neon",
    name: "Неон",
    description: "Подсвеченные неоновые блоки с послесвечением",
    icon: "💡",
    price: 150,
    cssClass: "skin-neon",
  },
  {
    id: "pixel",
    name: "Пиксели",
    description: "Угловатые ретро-блоки с пиксельной обводкой",
    icon: "🟧",
    price: 100,
    cssClass: "skin-pixel",
  },
  {
    id: "candy",
    name: "Карамель",
    description: "Глянцевые конфеты-леденцы",
    icon: "🍬",
    price: 90,
    cssClass: "skin-candy",
  },
];

export const SKINS_BY_ID: Record<SkinId, SkinDef> = Object.fromEntries(
  SKINS.map((s) => [s.id, s]),
) as Record<SkinId, SkinDef>;
