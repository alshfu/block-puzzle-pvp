// ============================================================
// Главное приложение: навигация, игровой экран, состояние.
// ============================================================
const { useState, useEffect, useRef, useMemo, useCallback } = React;

const BLITZ_PRESETS = {
  hard: { start: 8, min: 2 },
  norm: { start: 12, min: 3 },
  casual: { start: 20, min: 6 },
};
function computePerTurn(blitz, turnCount) {
  const p = BLITZ_PRESETS[blitz] || BLITZ_PRESETS.norm;
  return Math.max(p.min, p.start - Math.floor(turnCount / 2));
}
function countFilled(board) {
  let n = 0;
  for (const row of board) for (const c of row) if (c.filled) n++;
  return n;
}
let POP_ID = 1;

// ---------- Игровой экран ----------
function GameScreen({ theme, setTheme, mode, cfg, botLevel, blitz, onExit }) {
  const [g, setG] = useState(() => initGame(mode, cfg, botLevel, blitz));
  const gRef = useRef(g);
  gRef.current = g;
  const [paused, setPaused] = useState(false);
  const [shake, setShake] = useState(false);
  const botTimer = useRef(null);

  const names = [THEMES[theme].p0name, mode === "hotseat" ? "Игрок 2" : THEMES[theme].p1name];

  function initGame(mode, cfg, botLevel, blitz) {
    const seedBase = (Date.now() & 0xffff) || 1234;
    const bags = [makeBag(seedBase + 11), makeBag(seedBase + 99)];
    const players = [0, 1].map(i => ({
      score: 0, combo: 0,
      hand: Array.from({ length: cfg.handSize }, () => bags[i].draw()),
      isBot: mode === "bot" && i === 1,
    }));
    const perTurn = computePerTurn(blitz, 0);
    return {
      cfg, mode, botLevel, blitz,
      board: emptyBoard(),
      bags, botRng: makeRng(seedBase + 7),
      players, current: 0, status: "playing",
      sel: null, hover: null,
      flash: null, popups: [],
      timer: { remaining: perTurn, perTurn, round: 0 },
      turnCount: 0,
      statusMsg: "Выбери фигуру → кликни по полю",
      result: null,
    };
  }

  // ---- ход (общий для человека и бота) ----
  const makeMove = useCallback((move, owner) => {
    const s = gRef.current;
    const board = cloneBoard(s.board);
    place(board, move.cells, move.r, move.c, owner);
    const clr = findClears(board);
    const players = s.players.map(p => ({ ...p, hand: [...p.hand] }));
    players[owner].hand = players[owner].hand.filter(p => p.id !== move.pieceId);

    let flash = null;
    const popups = [...s.popups];
    let statusMsg;
    if (clr.count > 0) {
      const afterCount = countFilled(board) - clr.cleared.length;
      const perfect = afterCount === 0;
      const pts = scoreForMove(clr.count, players[owner].combo, perfect, s.cfg);
      players[owner].score += pts;
      players[owner].combo += 1;
      flash = new Set(clr.cleared.map(([r, c]) => r + "," + c));
      const pid = POP_ID++;
      popups.push({ id: pid, r: move.r, c: move.c, owner, text: `+${pts}` + (perfect ? " PERFECT!" : (clr.count > 1 ? ` ×${clr.count}` : "")) });
      setTimeout(() => {
        setG(p => ({ ...p, popups: p.popups.filter(x => x.id !== pid) }));
      }, 950);
      statusMsg = `${owner === 0 ? "Ты очистил" : names[1] + " очистил"} ${clr.count} ${clr.count === 1 ? "линию" : "линии"} (+${pts})`;
    } else {
      players[owner].combo = 0;
      statusMsg = owner === 0 ? "Ход сделан" : names[1] + " походил";
    }
    // дотянуть руку
    while (players[owner].hand.length < s.cfg.handSize) players[owner].hand.push(s.bags[owner].draw());

    setG({ ...s, board, players, sel: null, hover: null, flash, popups, animating: true, statusMsg });

    const delay = clr.count > 0 ? 430 : 150;
    setTimeout(() => finalizeTurn(clr), delay);
  }, [names]);

  const finalizeTurn = useCallback((clr) => {
    const s = gRef.current;
    const board = cloneBoard(s.board);
    if (clr && clr.count > 0) applyClears(board, clr.cleared);
    const next = 1 - s.current;
    const turnCount = s.turnCount + 1;
    const perTurn = computePerTurn(s.blitz, turnCount);
    const over = !hasAnyMove(board, s.players[next].hand, s.cfg);
    let status = "playing", result = null, statusMsg, current = next;
    if (over) {
      status = "over";
      const sc = [s.players[0].score, s.players[1].score];
      const winner = sc[0] > sc[1] ? 0 : sc[1] > sc[0] ? 1 : -1;
      result = { winner, scores: sc };
      statusMsg = "Игра окончена";
      current = s.current;
    } else {
      statusMsg = next === 0 ? "Твой ход" : (s.mode === "bot" ? names[1] + " думает…" : names[1] + ", твой ход");
    }
    setG({ ...s, board, current, turnCount, flash: null, animating: false, status, result, statusMsg,
      timer: { remaining: perTurn, perTurn, round: Math.floor(turnCount / 2) } });

    if (!over && s.mode === "bot" && next === 1) {
      clearTimeout(botTimer.current);
      botTimer.current = setTimeout(() => doBotMove(), 600 + Math.random() * 500);
    }
  }, [names]);

  const doBotMove = useCallback(() => {
    const s = gRef.current;
    if (s.status !== "playing" || s.current !== 1) return;
    const move = chooseBotMove(s.board, s.players[1].hand, s.botLevel, s.cfg, s.botRng);
    if (!move) { finalizeTurn(null); return; }
    makeMove(move, 1);
  }, [makeMove, finalizeTurn]);

  // ---- таймер ----
  useEffect(() => {
    if (g.status !== "playing" || g.animating || paused) return;
    const iv = setInterval(() => {
      const s = gRef.current;
      if (s.status !== "playing" || s.animating) return;
      const rem = s.timer.remaining - 0.1;
      if (rem <= 0) {
        // таймаут — авто-ход случайной валидной фигурой
        const moves = enumerateMoves(s.board, s.players[s.current].hand, s.cfg);
        if (moves.length > 0) {
          const m = moves[Math.floor(Math.random() * moves.length)];
          setG(p => ({ ...p, statusMsg: "Время вышло — авто-ход" }));
          makeMove(m, s.current);
        } else {
          finalizeTurn(null);
        }
      } else {
        setG(p => ({ ...p, timer: { ...p.timer, remaining: Math.max(0, rem) } }));
      }
    }, 100);
    return () => clearInterval(iv);
  }, [g.status, g.animating, g.current, paused, makeMove, finalizeTurn]);

  // ---- клавиатура ----
  useEffect(() => {
    const onKey = (e) => {
      const s = gRef.current;
      if (e.key === "r" || e.key === "R" || e.key === "к" || e.key === "К") { if (s.sel && s.cfg.rotationEnabled) rotateSel(); }
      else if (e.key === "f" || e.key === "F" || e.key === "а" || e.key === "А") { if (s.sel && s.cfg.flipEnabled) flipSel(); }
      else if (e.key === "Escape") clearSel();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  // ---- интеракции ----
  const pausedRef = useRef(false);
  pausedRef.current = paused;
  function localTurnNow() {
    const s = gRef.current;
    return s.status === "playing" && !s.animating && !pausedRef.current &&
      (s.mode === "bot" ? s.current === 0 : true);
  }
  const isLocalTurn = g.status === "playing" && !g.animating && !paused &&
    (g.mode === "bot" ? g.current === 0 : true);

  function selectPiece(piece) {
    if (!localTurnNow()) return;
    setG(p => ({ ...p, sel: { pieceId: piece.id, cells: normalize(piece.cells) }, statusMsg: "Наведи на поле и кликни" }));
  }
  function rotateSel() { setG(p => p.sel ? { ...p, sel: { ...p.sel, cells: rotate90(p.sel.cells) } } : p); }
  function flipSel() { setG(p => p.sel ? { ...p, sel: { ...p.sel, cells: flipH(p.sel.cells) } } : p); }
  function clearSel() { setG(p => ({ ...p, sel: null, hover: null })); }
  function onHover(r, c) { const s = gRef.current; if (s.sel && localTurnNow()) setG(p => ({ ...p, hover: { r, c } })); }
  function onLeave() { setG(p => (p.hover ? { ...p, hover: null } : p)); }
  function onPlace(r, c) {
    const s = gRef.current;
    if (!localTurnNow() || !s.sel) return;
    if (canPlace(s.board, s.sel.cells, r, c)) {
      makeMove({ pieceId: s.sel.pieceId, cells: s.sel.cells, r, c }, s.current);
    } else {
      setG(p => ({ ...p, statusMsg: "Сюда не помещается" }));
      setShake(true); setTimeout(() => setShake(false), 320);
    }
  }

  // ---- ghost ----
  const ghost = useMemo(() => {
    if (!g.sel || !g.hover) return null;
    const { r, c } = g.hover;
    const ok = canPlace(g.board, g.sel.cells, r, c);
    const map = new Map();
    for (const [dr, dc] of g.sel.cells) {
      const rr = r + dr, cc = c + dc;
      if (rr >= 0 && rr < SIZE && cc >= 0 && cc < SIZE && !g.board[rr][cc].filled) {
        map.set(rr + "," + cc, ok ? "good" : "bad");
      }
    }
    return { map };
  }, [g.sel, g.hover, g.board]);

  // мёртвые фигуры активного игрока (некуда поставить)
  const deadIds = useMemo(() => {
    const s = new Set();
    const owner = g.mode === "bot" ? 0 : g.current;
    for (const piece of g.players[owner].hand) {
      if (!pieceHasMove(g.board, piece, g.cfg)) s.add(piece.id);
    }
    return s;
  }, [g.board, g.players, g.current, g.cfg, g.mode]);

  const bottomOwner = g.mode === "bot" ? 0 : g.current;
  const topOwner = 1 - bottomOwner;
  const selPiece = g.sel ? { id: g.sel.pieceId, cells: g.sel.cells } : null;

  function restart() { clearTimeout(botTimer.current); setG(initGame(mode, cfg, botLevel, blitz)); setPaused(false); }

  return (
    <div className={"screen game-screen " + (shake ? "shake" : "")}>
      {/* header */}
      <div className="game-head">
        <Logo size="mini" />
        <span className="mode-badge">{mode === "bot" ? "vs bot · " + botLevel : "hot-seat"}</span>
        <button className="pause-btn" onClick={() => setPaused(true)}>⏸</button>
      </div>

      <Scoreboard players={g.players} current={g.current} status={g.status}
        timer={g.timer} names={names} />

      {/* верхняя рука-наблюдение */}
      <HandView
        title={g.mode === "bot" ? "Рука соперника" : "Игрок " + (topOwner + 1)}
        hint={g.mode === "bot" ? "наблюдай" : (g.current === topOwner ? "ждёт" : "ждёт")}
        hand={g.players[topOwner].hand} owner={topOwner}
        selId={null} interactive={false} tone="watch" />

      <BoardView board={g.board} ghost={ghost} flash={g.flash} popups={g.popups}
        onHover={onHover} onLeave={onLeave} onPlace={onPlace}
        interactive={isLocalTurn} />

      <div className="status-bar">{g.statusMsg}</div>

      {/* нижняя рука — активная */}
      <HandView
        title={g.mode === "bot" ? "Твоя рука" : "Ходит: Игрок " + (bottomOwner + 1)}
        hint={isLocalTurn && bottomOwner === g.current ? "выбери фигуру" : "ждёт хода"}
        hand={g.players[bottomOwner].hand} owner={bottomOwner}
        selId={g.sel && g.sel.pieceId} onSelect={selectPiece}
        deadIds={bottomOwner === (g.mode === "bot" ? 0 : g.current) ? deadIds : null}
        interactive={isLocalTurn && bottomOwner === g.current} tone="play" />

      <TransformControls sel={selPiece} cfg={g.cfg}
        onRotate={rotateSel} onFlip={flipSel} onClear={clearSel} />

      <ResultOverlay result={g.result} names={names} xp={Math.round((g.players[0].score) / 3) + 20}
        onRematch={restart} onMenu={onExit} />

      {paused && (
        <div className="overlay">
          <div className="pause-card">
            <div className="pause-title">Пауза</div>
            <Button kind="primary" onClick={() => setPaused(false)}>▶ Продолжить</Button>
            <Button kind="ghost" onClick={restart}>⟳ Новая игра</Button>
            <Button kind="ghost" onClick={onExit}>← В меню</Button>
          </div>
        </div>
      )}

      <FloatingTheme theme={theme} setTheme={setTheme} />
    </div>
  );
}

// ---------- Корневое приложение ----------
function App() {
  const [theme, setTheme] = useState(() => localStorage.getItem("bd_theme") || "neutral");
  const [screen, setScreen] = useState("menu");
  const [mode, setMode] = useState("bot");
  const [cfg, setCfg] = useState({
    handSize: 3, rotationEnabled: true, flipEnabled: true,
    comboStep: 0.25, comboCap: 3, perfectClearBonus: 120,
  });
  const [botLevel, setBotLevel] = useState("medium");
  const [blitz, setBlitz] = useState("norm");
  const profile = { nick: "Игрок", avatar: "🙂", level: 3 };

  useEffect(() => { localStorage.setItem("bd_theme", theme); }, [theme]);

  const t = THEMES[theme];

  function goSetup(m) { setMode(m); setScreen("setup"); }

  return (
    <div className="app-root" data-theme={theme} data-kind={t.kind} style={t.vars}>
      <ThemeBackdrop theme={theme} />
      <div className="phone">
        {screen === "menu" && (
          <MenuScreen theme={theme} setTheme={setTheme} onStart={goSetup} profile={profile} />
        )}
        {screen === "setup" && (
          <SetupScreen theme={theme} setTheme={setTheme} mode={mode}
            cfg={cfg} setCfg={setCfg} botLevel={botLevel} setBotLevel={setBotLevel}
            blitz={blitz} setBlitz={setBlitz}
            onBack={() => setScreen("menu")} onStart={() => setScreen("game")} />
        )}
        {screen === "game" && (
          <GameScreen theme={theme} setTheme={setTheme} mode={mode} cfg={cfg}
            botLevel={botLevel} blitz={blitz} onExit={() => setScreen("menu")} />
        )}
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
