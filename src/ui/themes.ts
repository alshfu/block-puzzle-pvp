import type { CSSProperties } from "react";

export type ThemeId = "neutral" | "candy" | "night";
export type ThemeKind = "dark" | "light";

export interface Theme {
  id: ThemeId;
  label: string;
  sub: string;
  kind: ThemeKind;
  p0name: string;
  p1name: string;
  vars: CSSProperties;
}

export const THEMES: Record<ThemeId, Theme> = {
  neutral: {
    id: "neutral",
    label: "Нейтральная",
    sub: "тёмная база · янтарь / циан",
    kind: "dark",
    p0name: "Ты",
    p1name: "Бот",
    vars: {
      "--bg": "#0e1116", "--bg2": "#0b0e13",
      "--panel": "#161b22", "--panel2": "#1c232d", "--line": "#2a323d",
      "--ink": "#e7edf3", "--muted": "#8b97a6",
      "--p0": "#ff9d42", "--p0d": "#b3661f",
      "--p1": "#36d6e7", "--p1d": "#1c8794",
      "--good": "#37d67a", "--bad": "#ef5e6b",
      "--cell": "#10151c", "--cellline": "#222c37",
      "--board-r": "18px", "--card-r": "14px", "--btn-r": "10px",
      "--cell-r": "5px", "--mini-r": "4px",
      "--font-display": "'Bricolage Grotesque', sans-serif",
      "--font-mono": "'DM Mono', monospace",
      "--display-weight": "800", "--display-spacing": "-0.01em",
    } as CSSProperties,
  },
  candy: {
    id: "candy",
    label: "Магия & Карамель",
    sub: "для самых волшебных · пастель, блёстки",
    kind: "light",
    p0name: "Ты",
    p1name: "Пони-бот",
    vars: {
      "--bg": "#ffeaf6", "--bg2": "#f4e6ff",
      "--panel": "rgba(255,255,255,0.80)", "--panel2": "#ffe1f1", "--line": "#ffc7e6",
      "--ink": "#6b3b78", "--muted": "#b07fc4",
      "--p0": "#ff77b3", "--p0d": "#ff3d92",
      "--p1": "#3fd5d0", "--p1d": "#16b3ac",
      "--good": "#5fd38a", "--bad": "#ff6b8a",
      "--cell": "#fff6fb", "--cellline": "#ffd9ec",
      "--board-r": "26px", "--card-r": "22px", "--btn-r": "18px",
      "--cell-r": "9px", "--mini-r": "6px",
      "--font-display": "'Fredoka', sans-serif",
      "--font-mono": "'Baloo 2', cursive",
      "--display-weight": "600", "--display-spacing": "0em",
    } as CSSProperties,
  },
  night: {
    id: "night",
    label: "Ночной Страж",
    sub: "для отважных · неон-нуар, готика",
    kind: "dark",
    p0name: "Ты",
    p1name: "Тень",
    vars: {
      "--bg": "#070a12", "--bg2": "#04060b",
      "--panel": "#0e1422", "--panel2": "#141c2e", "--line": "#243049",
      "--ink": "#eaf0ff", "--muted": "#6f80a3",
      "--p0": "#ffd23f", "--p0d": "#c79410",
      "--p1": "#3aa6ff", "--p1d": "#1c6fd0",
      "--good": "#39e88a", "--bad": "#ff3b5c",
      "--cell": "#0b1120", "--cellline": "#1c2840",
      "--board-r": "6px", "--card-r": "6px", "--btn-r": "4px",
      "--cell-r": "2px", "--mini-r": "2px",
      "--font-display": "'Oswald', sans-serif",
      "--font-mono": "'Share Tech Mono', monospace",
      "--display-weight": "700", "--display-spacing": "0.02em",
    } as CSSProperties,
  },
};

export const THEME_ORDER: ThemeId[] = ["neutral", "candy", "night"];

export const THEME_STORAGE_KEY = "bd_theme";

export function isThemeId(v: unknown): v is ThemeId {
  return v === "neutral" || v === "candy" || v === "night";
}
