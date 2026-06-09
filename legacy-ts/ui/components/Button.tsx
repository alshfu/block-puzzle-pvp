import type { CSSProperties, ReactNode } from "react";

interface Props {
  kind?: "primary" | "ghost";
  owner?: 0 | 1;
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
}

export function Button({
  kind = "primary",
  owner = 0,
  disabled,
  onClick,
  className = "",
  style,
  children,
}: Props) {
  return (
    <button
      className={`btn btn-${kind} ${owner === 1 ? "owner1" : "owner0"} ${className}`}
      disabled={disabled}
      onClick={onClick}
      style={style}
    >
      {children}
    </button>
  );
}
