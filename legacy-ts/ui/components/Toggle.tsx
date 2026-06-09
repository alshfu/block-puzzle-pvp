interface Props {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}

export function Toggle({ label, checked, onChange }: Props) {
  return (
    <button className={`toggle ${checked ? "on" : ""}`} onClick={() => onChange(!checked)}>
      <span className="tg-track">
        <span className="tg-knob" />
      </span>
      <span className="tg-label">{label}</span>
    </button>
  );
}
