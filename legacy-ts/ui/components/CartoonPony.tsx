/**
 * Мультяшный chibi-пони. Большая голова, выразительные глаза с бликами,
 * пышная многоцветная грива, длинный волнистый хвост. Полностью оригинальный
 * силуэт — никаких имён, cutie marks или цветов конкретных персонажей.
 *
 * Параметризован цветами для вариативности: тело + 3 пряди гривы + акцент
 * (рог / щёчки).
 */
import type { CSSProperties } from "react";

export interface CartoonPonyProps {
  /** Основной цвет тела. */
  body: string;
  /** Цвет тела чуть темнее — для теней. Если не задан — затемним body. */
  bodyShade?: string;
  /** Цвета прядей гривы и хвоста (3 пряди — основная + две акцентные). */
  mane: [string, string, string];
  /** Цвет рога / звезды (по умолчанию мягкий золотой). */
  accent?: string;
  /** Размер в px. */
  size?: number;
  className?: string;
  style?: CSSProperties;
}

export function CartoonPony({
  body,
  bodyShade,
  mane,
  accent = "#ffd166",
  size = 140,
  className = "",
  style,
}: CartoonPonyProps) {
  const shade = bodyShade ?? darken(body, 0.1);
  return (
    <svg
      viewBox="0 0 160 160"
      width={size}
      height={size}
      className={className}
      style={style}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Хвост — длинный, волнистый, две пряди */}
      <path
        d="M 36 96
           Q 12 90 14 116
           Q 18 132 30 128
           Q 24 118 30 108
           Q 36 102 36 96 Z"
        fill={mane[0]}
      />
      <path
        d="M 34 110
           Q 18 122 26 138
           Q 36 138 40 122
           Q 36 116 34 110 Z"
        fill={mane[1]}
      />
      <path
        d="M 36 122
           Q 28 134 38 144
           Q 44 138 42 126 Z"
        fill={mane[2]}
      />

      {/* Тело — округлое, чуть приплюснутое */}
      <ellipse cx="78" cy="100" rx="38" ry="26" fill={body} />
      <ellipse cx="78" cy="106" rx="38" ry="20" fill={shade} opacity="0.35" />

      {/* Копытца с тёмными "бубликами" внизу */}
      <g>
        <rect x="50" y="118" width="10" height="22" rx="4" fill={body} />
        <ellipse cx="55" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
        <rect x="68" y="118" width="10" height="22" rx="4" fill={shade} />
        <ellipse cx="73" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
        <rect x="86" y="118" width="10" height="22" rx="4" fill={body} />
        <ellipse cx="91" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
        <rect x="104" y="118" width="10" height="22" rx="4" fill={shade} />
        <ellipse cx="109" cy="138" rx="6" ry="2.5" fill="#7f5b9c" />
      </g>

      {/* Шея */}
      <path d="M 96 88 Q 104 76 112 70 L 122 82 L 110 102 Z" fill={body} />

      {/* Голова — большая chibi с округлой мордой */}
      <ellipse cx="118" cy="60" rx="26" ry="24" fill={body} />
      {/* Мордочка-выпуклость */}
      <ellipse cx="132" cy="68" rx="14" ry="10" fill={body} />
      <ellipse cx="132" cy="71" rx="12" ry="7" fill={shade} opacity="0.4" />

      {/* Ушки */}
      <path d="M 102 42 Q 108 30 116 44 Z" fill={body} />
      <path d="M 104 42 Q 108 36 113 44 Z" fill={shade} opacity="0.5" />

      {/* Рог */}
      <path d="M 116 18 L 121 42 L 109 42 Z" fill={accent} stroke="#fff" strokeWidth="0.5" />

      {/* Грива — пышная, в 4 пряди, спадает на лоб и шею */}
      {/* верхняя челка */}
      <path
        d="M 108 38
           Q 96 24 106 16
           Q 116 22 118 36
           Q 122 28 132 24
           Q 134 38 124 46
           Q 116 44 108 50 Z"
        fill={mane[0]}
      />
      <path
        d="M 110 46
           Q 100 38 104 28
           Q 112 32 116 44 Z"
        fill={mane[1]}
      />
      <path
        d="M 124 30
           Q 132 22 138 32
           Q 136 42 128 46 Z"
        fill={mane[2]}
      />
      {/* грива на шее */}
      <path
        d="M 100 60
           Q 86 70 94 90
           Q 104 86 108 72 Z"
        fill={mane[0]}
      />
      <path
        d="M 96 70
           Q 84 80 90 92
           Q 98 90 102 80 Z"
        fill={mane[1]}
      />
      <path
        d="M 96 84
           Q 88 92 92 100
           Q 100 96 100 88 Z"
        fill={mane[2]}
      />

      {/* Глаз — большой, миндалевидный, с яркими бликами */}
      <ellipse cx="125" cy="60" rx="7" ry="9" fill="#fff" />
      <ellipse cx="125" cy="60" rx="6" ry="8" fill="#5a2a78" />
      <ellipse cx="125" cy="62" rx="4" ry="6" fill={accent === "#ffd166" ? "#3a1858" : accent} />
      {/* Бликов два — большой и маленький */}
      <ellipse cx="123" cy="56" rx="2" ry="2.5" fill="#fff" />
      <ellipse cx="127" cy="64" rx="1" ry="1.2" fill="#fff" opacity="0.85" />

      {/* Длинные ресницы */}
      <path d="M 119 53 q -2 -2 -4 -1" stroke="#3a1858" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      <path d="M 119 56 q -3 -1 -5 1" stroke="#3a1858" strokeWidth="1.2" fill="none" strokeLinecap="round" />
      <path d="M 119 60 q -3 0 -5 2" stroke="#3a1858" strokeWidth="1.2" fill="none" strokeLinecap="round" />

      {/* Щёчки-румянец */}
      <ellipse cx="138" cy="72" rx="4" ry="2.5" fill="#ff8fb8" opacity="0.65" />

      {/* Мордочка: ноздря + улыбающийся рот */}
      <ellipse cx="138" cy="65" rx="1" ry="1.4" fill="#7a3464" opacity="0.6" />
      <path d="M 134 74 q 4 4 9 0" stroke="#5a2a78" strokeWidth="1.5" fill="none" strokeLinecap="round" />

      {/* Маленькая звёздочка-cutie mark на боку (нейтральный значок) */}
      <g transform="translate(76 96)" opacity="0.75">
        <polygon
          points="0,-7 2,-2 7,-2 3,1 5,6 0,3 -5,6 -3,1 -7,-2 -2,-2"
          fill={accent}
          stroke="#fff"
          strokeWidth="0.5"
        />
      </g>

      {/* Искорка у рога */}
      <g transform="translate(135 18)" opacity="0.9">
        <polygon points="0,-4 1,-1 4,0 1,1 0,4 -1,1 -4,0 -1,-1" fill="#fff" />
      </g>
    </svg>
  );
}

/**
 * Затемняет hex-цвет на заданную долю (0..1) в сторону чёрного.
 * Простая интерполяция RGB, не цветово-точная — для теней достаточно.
 */
function darken(hex: string, amount: number): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const rgb = parseInt(m[1], 16);
  const r = (rgb >> 16) & 0xff;
  const g = (rgb >> 8) & 0xff;
  const b = rgb & 0xff;
  const k = 1 - amount;
  const dr = Math.max(0, Math.round(r * k));
  const dg = Math.max(0, Math.round(g * k));
  const db = Math.max(0, Math.round(b * k));
  return `#${[dr, dg, db].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
}
