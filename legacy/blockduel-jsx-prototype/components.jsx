// ============================================================
// UI-атомы и игровые компоненты BlockDuel.
// ============================================================

function Button({ kind = "primary", owner = 0, disabled, onClick, children, className = "", style }) {
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

// --- мини-рендер фигуры (в руке / превью) ---
function MiniPiece({ cells, owner = 0, cellSize = 16, dead = false }) {
  const { rows, cols } = pieceDims(cells);
  const set = new Set(cells.map(([r, c]) => r + "," + c));
  const gap = 3;
  return (
    <div className="mini-piece" style={{
      display: "grid",
      gridTemplateColumns: `repeat(${cols}, ${cellSize}px)`,
      gridTemplateRows: `repeat(${rows}, ${cellSize}px)`,
      gap: gap,
      opacity: dead ? 0.32 : 1,
      filter: dead ? "grayscale(0.6)" : "none",
    }}>
      {Array.from({ length: rows * cols }).map((_, i) => {
        const r = Math.floor(i / cols), c = i % cols;
        const on = set.has(r + "," + c);
        return <span key={i} className={on ? `mini-cell filled owner${owner}` : "mini-cell"} />;
      })}
    </div>
  );
}

// --- кольцо-таймер ---
function TurnTimer({ remaining, total, owner, danger }) {
  const R = 26, C = 2 * Math.PI * R;
  const frac = Math.max(0, Math.min(1, remaining / total));
  return (
    <div className={"turn-timer " + (danger ? "danger" : "")}>
      <svg width="68" height="68" viewBox="0 0 68 68">
        <circle cx="34" cy="34" r={R} className="tt-track" />
        <circle cx="34" cy="34" r={R} className={"tt-fill owner" + owner}
          strokeDasharray={C}
          strokeDashoffset={C * (1 - frac)}
          transform="rotate(-90 34 34)" />
      </svg>
      <span className="tt-num">{Math.ceil(remaining)}</span>
    </div>
  );
}

// --- карточка игрока ---
function PlayerCard({ name, score, combo, owner, active, side }) {
  return (
    <div className={`pcard owner${owner} ${active ? "active" : ""} ${side}`}>
      <div className="pcard-label">
        {owner === 0
          ? <><span className="dot" /> {name}</>
          : <>{name} <span className="dot" /></>}
      </div>
      <div className="pcard-score">{score}</div>
      <div className="pcard-combo" style={{ visibility: combo > 1 ? "visible" : "hidden" }}>
        комбо ×{combo}
      </div>
    </div>
  );
}

function Scoreboard({ players, current, status, timer, names }) {
  let centerText = "игра окончена";
  if (status === "playing") centerText = current === 0 ? "твой ход" : "ход соперника";
  const danger = status === "playing" && timer.remaining <= 3;
  return (
    <div className="scoreboard">
      <PlayerCard name={names[0]} score={players[0].score} combo={players[0].combo}
        owner={0} active={status === "playing" && current === 0} side="left" />
      <div className="turn-center">
        <div className={"turn-pill " + (danger ? "danger" : "")}>{centerText}</div>
        <TurnTimer remaining={timer.remaining} total={timer.perTurn}
          owner={current} danger={danger} />
      </div>
      <PlayerCard name={names[1]} score={players[1].score} combo={players[1].combo}
        owner={1} active={status === "playing" && current === 1} side="right" />
    </div>
  );
}

// --- доска ---
const BoardView = React.memo(function BoardView({ board, ghost, flash, popups, onHover, onLeave, onPlace, interactive }) {
  return (
    <div className="board-wrap">
      <div className="board"
        onMouseLeave={onLeave}>
        {board.map((row, r) =>
          row.map((cell, c) => {
            const key = r + "," + c;
            const gh = ghost && ghost.map.get(key); // 'good' | 'bad' | undefined
            const isFlash = flash && flash.has(key);
            let cls = "cell";
            if (cell.filled) cls += " filled owner" + cell.owner;
            if (gh === "good") cls += " ghost-good";
            else if (gh === "bad") cls += " ghost-bad";
            if (isFlash) cls += " flash";
            // разделители боксов
            if (c === 2 || c === 5) cls += " sep-r";
            if (r === 2 || r === 5) cls += " sep-b";
            return (
              <div key={key} className={cls}
                onMouseEnter={interactive ? () => onHover(r, c) : undefined}
                onClick={interactive ? () => onPlace(r, c) : undefined} />
            );
          })
        )}
      </div>
      {/* разделители боксов 3×3 */}
      <div className="box-sep vert" style={{ left: "33.33%" }} />
      <div className="box-sep vert" style={{ left: "66.66%" }} />
      <div className="box-sep horz" style={{ top: "33.33%" }} />
      <div className="box-sep horz" style={{ top: "66.66%" }} />
      {popups.map(p => (
        <div key={p.id} className={"score-pop owner" + p.owner}
          style={{ left: `${(p.c + 0.5) / 9 * 100}%`, top: `${(p.r + 0.5) / 9 * 100}%` }}>
          {p.text}
        </div>
      ))}
    </div>
  );
}, (a, b) => a.board === b.board && a.ghost === b.ghost && a.flash === b.flash &&
   a.popups === b.popups && a.interactive === b.interactive);

// --- рука ---
const HandView = React.memo(function HandView({ title, hint, hand, owner, selId, onSelect, deadIds, interactive, tone }) {
  return (
    <div className={`hand owner${owner} ${tone}`}>
      <div className="hand-head">
        <span className="hand-title">{title}</span>
        <span className="hand-hint">{hint}</span>
      </div>
      <div className="hand-row">
        {hand.length === 0 && <span className="hand-empty">— пусто —</span>}
        {hand.map(piece => {
          const dead = deadIds && deadIds.has(piece.id);
          return (
            <div key={piece.id}
              className={`hand-slot ${selId === piece.id ? "sel" : ""} ${dead ? "dead" : ""}`}
              onClick={interactive && !dead ? () => onSelect(piece) : undefined}>
              <MiniPiece cells={piece.cells} owner={owner} cellSize={13} dead={dead} />
            </div>
          );
        })}
      </div>
    </div>
  );
}, (a, b) => a.hand === b.hand && a.selId === b.selId && a.deadIds === b.deadIds &&
   a.interactive === b.interactive && a.title === b.title && a.hint === b.hint &&
   a.tone === b.tone && a.owner === b.owner);

// --- контролы трансформации ---
function TransformControls({ sel, cfg, onRotate, onFlip, onClear }) {
  const has = !!sel;
  return (
    <div className="transform-controls">
      <button className="tc-btn" disabled={!has || !cfg.rotationEnabled} onClick={onRotate}>
        <span className="tc-ico">↻</span> Повернуть
      </button>
      <button className="tc-btn" disabled={!has || !cfg.flipEnabled} onClick={onFlip}>
        <span className="tc-ico">⇄</span> Отразить
      </button>
      <button className="tc-btn" disabled={!has} onClick={onClear}>
        <span className="tc-ico">✕</span> Снять
      </button>
    </div>
  );
}

Object.assign(window, {
  Button, MiniPiece, TurnTimer, PlayerCard, Scoreboard,
  BoardView, HandView, TransformControls,
});
