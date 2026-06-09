interface Option<V> {
  v: V;
  label: string;
  sub?: string;
}

interface Props<V> {
  options: Option<V>[];
  value: V;
  onChange: (v: V) => void;
}

export function Segment<V extends string | number>({ options, value, onChange }: Props<V>) {
  return (
    <div className="segment">
      {options.map((o) => (
        <button
          key={String(o.v)}
          className={`seg-item ${value === o.v ? "on" : ""}`}
          onClick={() => onChange(o.v)}
        >
          <b>{o.label}</b>
          {o.sub && <i>{o.sub}</i>}
        </button>
      ))}
    </div>
  );
}
