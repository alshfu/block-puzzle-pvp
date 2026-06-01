import type { ThemeId } from "../themes";

interface Props {
  theme: ThemeId;
  size?: number;
}

export function Mascot({ theme, size = 140 }: Props) {
  switch (theme) {
    case "candy":
      return <CandyPony size={size} />;
    case "night":
      return <NightShade size={size} />;
    default:
      return <NeutralRobot size={size} />;
  }
}

// ─── Candy: пони с радужной гривой и рогом ───────────────────────────────
function CandyPony({ size }: { size: number }) {
  return (
    <svg viewBox="0 0 120 120" width={size} height={size} className="mascot mascot-pony">
      {/* копыта */}
      <rect x="36" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="50" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="64" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="78" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      {/* тело */}
      <ellipse cx="60" cy="72" rx="32" ry="20" fill="#ff9ecb" />
      {/* шея + голова */}
      <path d="M 82 72 Q 96 58 90 38 Q 88 30 78 32 Q 72 40 78 50 Q 76 62 76 70 Z" fill="#ff9ecb" />
      <ellipse cx="90" cy="42" rx="13" ry="13" fill="#ff9ecb" />
      {/* ушко */}
      <polygon points="84,32 87,24 92,32" fill="#ff9ecb" />
      {/* рог */}
      <polygon points="88,28 90,10 92,28" fill="#ffd166" stroke="#fff" strokeWidth="0.5" />
      {/* глаз */}
      <ellipse cx="93" cy="44" rx="2.6" ry="3" fill="#fff" />
      <circle cx="93.5" cy="44.5" r="1.5" fill="#6b3b78" />
      {/* щёчка */}
      <circle cx="98" cy="50" r="2.5" fill="#ff6b8a" opacity="0.6" />
      {/* грива — радуга */}
      <path d="M 78 40 Q 66 32 72 22 Q 80 26 82 36 Z" fill="#ff6b8a" />
      <path d="M 74 46 Q 60 42 66 30 Q 76 32 76 44 Z" fill="#ffd166" />
      <path d="M 70 54 Q 56 54 60 42 Q 72 44 72 52 Z" fill="#7fe7df" />
      <path d="M 66 62 Q 52 64 58 54 Q 68 56 68 62 Z" fill="#b89cff" />
      {/* хвост */}
      <path d="M 28 72 Q 14 68 18 82 Q 22 88 30 84 Q 28 78 28 72 Z" fill="#ff6b8a" />
      <path d="M 28 78 Q 16 82 22 92 Q 28 92 32 86 Z" fill="#7fe7df" />
      {/* искра рядом с рогом */}
      <polygon points="100,18 102,22 106,24 102,26 100,30 98,26 94,24 98,22" fill="#fff" opacity="0.85" />
    </svg>
  );
}

// ─── Neutral: киберробот с янтарным сканером ─────────────────────────────
function NeutralRobot({ size }: { size: number }) {
  return (
    <svg viewBox="0 0 120 120" width={size} height={size} className="mascot mascot-robot">
      {/* антенна */}
      <line x1="60" y1="14" x2="60" y2="4" stroke="#36d6e7" strokeWidth="2" />
      <circle cx="60" cy="3" r="3" fill="#ff9d42" />
      {/* голова */}
      <rect x="38" y="14" width="44" height="38" rx="6" fill="#1c232d" stroke="#36d6e7" strokeWidth="2" />
      {/* визор */}
      <rect x="44" y="26" width="32" height="10" rx="2" fill="#0e1116" />
      <rect x="46" y="29" width="28" height="4" rx="1" fill="#ff9d42" />
      {/* «уши» */}
      <rect x="34" y="24" width="4" height="18" fill="#36d6e7" />
      <rect x="82" y="24" width="4" height="18" fill="#36d6e7" />
      {/* рот / решётка */}
      <rect x="50" y="42" width="20" height="3" rx="1" fill="#36d6e7" />
      {/* шея */}
      <rect x="54" y="52" width="12" height="6" fill="#1c232d" />
      {/* тело */}
      <rect x="34" y="58" width="52" height="44" rx="6" fill="#1c232d" stroke="#36d6e7" strokeWidth="2" />
      {/* лампа */}
      <circle cx="60" cy="80" r="7" fill="#ff9d42" opacity="0.85" />
      <circle cx="60" cy="80" r="3" fill="#fff" />
      {/* кнопки */}
      <circle cx="44" cy="68" r="2" fill="#36d6e7" />
      <circle cx="76" cy="68" r="2" fill="#36d6e7" />
      <circle cx="44" cy="92" r="2" fill="#37d67a" />
      <circle cx="76" cy="92" r="2" fill="#ef5e6b" />
      {/* руки */}
      <rect x="22" y="62" width="10" height="30" rx="3" fill="#1c232d" stroke="#36d6e7" />
      <rect x="88" y="62" width="10" height="30" rx="3" fill="#1c232d" stroke="#36d6e7" />
    </svg>
  );
}

// ─── Night: тень в капюшоне с горящими янтарными глазами ────────────────
function NightShade({ size }: { size: number }) {
  return (
    <svg viewBox="0 0 120 120" width={size} height={size} className="mascot mascot-shade">
      {/* лучи прожектора за плечами */}
      <path d="M 30 110 L 60 8 L 90 110 Z" fill="url(#nightBeam)" opacity="0.35" />
      <defs>
        <linearGradient id="nightBeam" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#ffd23f" stopOpacity="0.7" />
          <stop offset="1" stopColor="#ffd23f" stopOpacity="0" />
        </linearGradient>
      </defs>
      {/* плащ */}
      <path d="M 22 110 Q 22 60 60 20 Q 98 60 98 110 Z" fill="#04060b" stroke="#3aa6ff" strokeWidth="2" />
      {/* внутренняя тень капюшона */}
      <path d="M 32 100 Q 40 56 60 30 Q 80 56 88 100 Z" fill="#070a12" />
      {/* глаза */}
      <ellipse cx="48" cy="62" rx="4" ry="5" fill="#ffd23f" />
      <ellipse cx="72" cy="62" rx="4" ry="5" fill="#ffd23f" />
      {/* свечение глаз */}
      <ellipse cx="48" cy="62" rx="8" ry="9" fill="#ffd23f" opacity="0.25" />
      <ellipse cx="72" cy="62" rx="8" ry="9" fill="#ffd23f" opacity="0.25" />
      {/* зрачки */}
      <ellipse cx="48" cy="62" rx="1.5" ry="2" fill="#04060b" />
      <ellipse cx="72" cy="62" rx="1.5" ry="2" fill="#04060b" />
      {/* острые края плаща */}
      <polygon points="22,110 30,98 38,110" fill="#04060b" />
      <polygon points="40,110 48,100 56,110" fill="#04060b" />
      <polygon points="58,110 66,102 74,110" fill="#04060b" />
      <polygon points="78,110 86,98 94,110" fill="#04060b" />
    </svg>
  );
}
