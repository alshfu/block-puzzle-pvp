import { useMemo } from "react";

interface Props {
  /** Перерисовываем при изменении tick — каждый новый «выстрел» — новый набор частиц. */
  tick: number;
}

export function Confetti({ tick }: Props) {
  const bits = useMemo(() => {
    const palette = ["var(--p0)", "var(--p1)", "var(--good)", "var(--p0)", "var(--p1)"];
    return Array.from({ length: 32 }).map((_, i) => ({
      left: Math.random() * 100,
      bg: palette[i % palette.length],
      delay: Math.random() * 0.2,
      duration: 1.2 + Math.random() * 0.8,
      drift: (Math.random() * 80 - 40).toFixed(0) + "px",
      rotate: Math.floor(Math.random() * 720),
    }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick]);

  return (
    <div className="confetti-burst" key={tick}>
      {bits.map((b, i) => (
        <span
          key={i}
          className="confetti-bit"
          style={{
            left: `${b.left}%`,
            background: b.bg,
            animationDelay: `${b.delay}s`,
            animationDuration: `${b.duration}s`,
            ["--drift" as string]: b.drift,
            ["--rot" as string]: `${b.rotate}deg`,
          } as React.CSSProperties}
        />
      ))}
    </div>
  );
}
