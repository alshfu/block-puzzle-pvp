import { useMemo } from "react";
import { makeRng } from "../../core";
import type { ThemeId } from "../themes";

interface Props {
  theme: ThemeId;
}

export function ThemeBackdrop({ theme }: Props) {
  if (theme === "candy") return <CandyBackdrop />;
  if (theme === "night") return <NightBackdrop />;
  return <NeutralBackdrop />;
}

function NeutralBackdrop() {
  return (
    <div
      className="backdrop"
      style={{
        background:
          "radial-gradient(120% 80% at 85% -10%, rgba(255,157,66,0.10), transparent 55%)," +
          "radial-gradient(120% 80% at 15% 110%, rgba(54,214,231,0.10), transparent 55%)," +
          "linear-gradient(180deg,#0e1116,#0b0e13)",
      }}
    />
  );
}

interface CandyBit {
  kind: "heart" | "star" | "spark";
  left: string;
  size: number;
  dur: number;
  delay: number;
  hue: string;
  drift: string;
}

function CandyBackdrop() {
  const bits = useMemo<CandyBit[]>(() => {
    const kinds = ["heart", "star", "spark", "spark", "star"] as const;
    const palette = ["#ff9ecb", "#ffd166", "#b89cff", "#7fe7df", "#ff77b3"];
    const arr: CandyBit[] = [];
    const rng = makeRng(7);
    for (let i = 0; i < 22; i++) {
      arr.push({
        kind: kinds[i % kinds.length],
        left: (rng() * 100).toFixed(2) + "%",
        size: 10 + rng() * 22,
        dur: 9 + rng() * 10,
        delay: -rng() * 18,
        hue: palette[Math.floor(rng() * palette.length)],
        drift: (rng() * 40 - 20).toFixed(0) + "px",
      });
    }
    return arr;
  }, []);
  return (
    <div
      className="backdrop candy-bd"
      style={{
        background:
          "radial-gradient(130% 90% at 50% -20%, #fff6fb 0%, #ffe4f4 30%, #f6dcff 60%, #e7e6ff 100%)",
      }}
    >
      <div className="candy-rainbow" />
      <div className="candy-cloud" style={{ top: "12%", left: "-6%", transform: "scale(1.1)" }} />
      <div className="candy-cloud" style={{ top: "30%", right: "-8%", left: "auto" }} />
      <div className="candy-cloud" style={{ bottom: "10%", left: "8%" }} />
      <div className="candy-cloud" style={{ top: "60%", right: "4%", left: "auto", transform: "scale(.85)" }} />

      {/* Парящие пони в боковых зонах (видимы на широких экранах) */}
      <CandyPonySprite className="candy-pony-deco p1" hue="#ff9ecb" mane1="#ffd166" mane2="#7fe7df" />
      <CandyPonySprite className="candy-pony-deco p2" hue="#b89cff" mane1="#ff77b3" mane2="#ffd166" />
      <CandyPonySprite className="candy-pony-deco p3" hue="#7fe7df" mane1="#b89cff" mane2="#ff9ecb" />
      <CandyPonySprite className="candy-pony-deco p4" hue="#ffd166" mane1="#7fe7df" mane2="#ff77b3" />

      {bits.map((b, i) => (
        <span
          key={i}
          className={"candy-bit " + b.kind}
          style={{
            left: b.left,
            width: b.size,
            height: b.size,
            color: b.hue,
            animationDuration: b.dur + "s",
            animationDelay: b.delay + "s",
            ["--drift" as string]: b.drift,
          } as React.CSSProperties}
        />
      ))}
    </div>
  );
}

function CandyPonySprite({ className, hue, mane1, mane2 }: { className: string; hue: string; mane1: string; mane2: string }) {
  return (
    <svg className={className} viewBox="0 0 120 120" width="120" height="120">
      {/* копыта */}
      <rect x="36" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="50" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="64" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      <rect x="78" y="86" width="8" height="18" rx="3" fill="#7f5b9c" />
      {/* тело */}
      <ellipse cx="60" cy="72" rx="32" ry="20" fill={hue} />
      <path d="M 82 72 Q 96 58 90 38 Q 88 30 78 32 Q 72 40 78 50 Q 76 62 76 70 Z" fill={hue} />
      <ellipse cx="90" cy="42" rx="13" ry="13" fill={hue} />
      <polygon points="84,32 87,24 92,32" fill={hue} />
      <polygon points="88,28 90,10 92,28" fill="#ffd166" />
      <ellipse cx="93" cy="44" rx="2.6" ry="3" fill="#fff" />
      <circle cx="93.5" cy="44.5" r="1.5" fill="#6b3b78" />
      <circle cx="98" cy="50" r="2.5" fill="#ff6b8a" opacity="0.6" />
      {/* грива */}
      <path d="M 78 40 Q 66 32 72 22 Q 80 26 82 36 Z" fill={mane1} />
      <path d="M 74 46 Q 60 42 66 30 Q 76 32 76 44 Z" fill={mane2} />
      <path d="M 70 54 Q 56 54 60 42 Q 72 44 72 52 Z" fill={mane1} />
      {/* хвост */}
      <path d="M 28 72 Q 14 68 18 82 Q 22 88 30 84 Q 28 78 28 72 Z" fill={mane1} />
      <path d="M 28 78 Q 16 82 22 92 Q 28 92 32 86 Z" fill={mane2} />
    </svg>
  );
}

function NightBackdrop() {
  return (
    <div
      className="backdrop night-bd"
      style={{
        background:
          "radial-gradient(120% 70% at 50% 0%, #14213f 0%, #0a0f1f 45%, #05070d 100%)",
      }}
    >
      <div className="night-stars" />
      <div className="night-beam" />
      <svg className="night-emblem" viewBox="0 0 100 100" width="120" height="120">
        <polygon points="50,6 94,50 50,94 6,50" fill="none" stroke="currentColor" strokeWidth="5" />
        <polygon
          points="50,26 60,44 80,44 64,57 70,77 50,65 30,77 36,57 20,44 40,44"
          fill="currentColor"
        />
      </svg>
      <div className="night-skyline">
        {Array.from({ length: 22 }).map((_, i) => {
          const rng = makeRng(100 + i);
          const w = 22 + Math.floor(rng() * 26);
          const h = 30 + Math.floor(rng() * 130);
          return <span key={i} style={{ width: w, height: h }} />;
        })}
      </div>
      <div className="night-grid" />
    </div>
  );
}
