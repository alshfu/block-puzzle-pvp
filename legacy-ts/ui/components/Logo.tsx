interface Props {
  size?: "big" | "mini";
}

export function Logo({ size = "big" }: Props) {
  return (
    <div className={`logo ${size}`}>
      <span className="logo-block">BLOCK</span>
      <span className="logo-dot">·</span>
      <span className="logo-duel">DUEL</span>
      <span className="logo-9">9×9</span>
    </div>
  );
}
