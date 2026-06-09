import { useMemo } from "react";
import { makeRng } from "../../core";
import { CartoonPony } from "./CartoonPony";
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
      <div className="candy-pony-deco p1">
        <CartoonPony body="#ff9ecb" mane={["#ffd166", "#7fe7df", "#b89cff"]} accent="#ff77b3" size={150} />
      </div>
      <div className="candy-pony-deco p2">
        <CartoonPony body="#b89cff" mane={["#ff77b3", "#ffd166", "#7fe7df"]} accent="#ff9ecb" size={150} />
      </div>
      <div className="candy-pony-deco p3">
        <CartoonPony body="#7fe7df" mane={["#b89cff", "#ff9ecb", "#ffd166"]} accent="#ff77b3" size={150} />
      </div>
      <div className="candy-pony-deco p4">
        <CartoonPony body="#ffd166" mane={["#7fe7df", "#ff77b3", "#b89cff"]} accent="#ff9ecb" size={150} />
      </div>

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
