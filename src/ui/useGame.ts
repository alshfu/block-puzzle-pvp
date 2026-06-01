import { useCallback, useEffect, useMemo, useReducer, useRef } from "react";
import {
  Bag,
  applyClears,
  canPlace,
  chooseBotMove,
  cloneBoard,
  emptyBoard,
  findClears,
  flipH,
  forcePlace,
  hasAnyMove,
  makeRng,
  normalize,
  pieceHasMove,
  place,
  rotate90,
  scoreForMove,
  SIZE,
  type Board,
  type BotLevel,
  type CandidateMove,
  type Coord,
  type PieceInstance,
  type RuleConfig,
} from "../core";
import type { ScorePopup } from "./components/Board";
import type { MatchResult } from "./screens/ResultOverlay";
import type { GameMode } from "./screens/MenuScreen";
import { BLITZ_PRESETS, type BlitzPreset } from "./screens/SetupScreen";

interface Selection {
  pieceId: string;
  cells: Coord[]; // нормализованные текущей ориентации
}

interface Player {
  score: number;
  combo: number;
  hand: PieceInstance[];
  isBot: boolean;
}

interface Timer {
  remaining: number;
  perTurn: number;
  round: number;
}

type Status = "playing" | "over";

interface State {
  board: Board;
  players: [Player, Player];
  current: 0 | 1;
  status: Status;
  sel: Selection | null;
  hover: { r: number; c: number } | null;
  flash: Set<string> | null;
  popups: ScorePopup[];
  timer: Timer;
  turnCount: number;
  statusMsg: string;
  animating: boolean;
  result: MatchResult | null;
  shake: number; // tick для триггера shake-анимации в UI
}

type Action =
  | { type: "SELECT"; piece: PieceInstance }
  | { type: "ROTATE" }
  | { type: "FLIP" }
  | { type: "CLEAR_SEL" }
  | { type: "HOVER"; r: number; c: number }
  | { type: "LEAVE" }
  | {
      type: "APPLY_MOVE";
      owner: 0 | 1;
      newBoard: Board;
      cleared: Set<string> | null;
      pieceIdRemoved: string;
      newPiece: PieceInstance | null;
      gained: number;
      popup: ScorePopup | null;
      perfect: boolean;
      clearedCount: number;
      statusMsg: string;
    }
  | {
      type: "FINALIZE";
      perTurn: number;
      next: 0 | 1;
      over: boolean;
      statusMsg: string;
      result: MatchResult | null;
    }
  | { type: "TIMER_TICK"; dec: number }
  | { type: "DISMISS_POPUP"; id: number }
  | { type: "SHAKE"; msg: string }
  | { type: "SET_STATUS_MSG"; msg: string }
  | { type: "RESTART"; initial: State };

function reducer(s: State, a: Action): State {
  switch (a.type) {
    case "SELECT":
      return {
        ...s,
        sel: { pieceId: a.piece.id, cells: normalize(a.piece.cells) },
        statusMsg: "Наведи на поле и кликни",
      };
    case "ROTATE":
      return s.sel ? { ...s, sel: { ...s.sel, cells: rotate90(s.sel.cells) } } : s;
    case "FLIP":
      return s.sel ? { ...s, sel: { ...s.sel, cells: flipH(s.sel.cells) } } : s;
    case "CLEAR_SEL":
      return { ...s, sel: null, hover: null };
    case "HOVER":
      if (!s.sel) return s;
      if (s.hover && s.hover.r === a.r && s.hover.c === a.c) return s;
      return { ...s, hover: { r: a.r, c: a.c } };
    case "LEAVE":
      return s.hover ? { ...s, hover: null } : s;
    case "APPLY_MOVE": {
      const players = s.players.map((p) => ({ ...p, hand: [...p.hand] })) as [Player, Player];
      const ownerP = players[a.owner];
      ownerP.hand = ownerP.hand.filter((p) => p.id !== a.pieceIdRemoved);
      if (a.newPiece) ownerP.hand.push(a.newPiece);
      if (a.clearedCount > 0) {
        ownerP.score += a.gained;
        ownerP.combo += 1;
      } else {
        ownerP.combo = 0;
      }
      return {
        ...s,
        board: a.newBoard,
        players,
        sel: null,
        hover: null,
        flash: a.cleared,
        popups: a.popup ? [...s.popups, a.popup] : s.popups,
        animating: true,
        statusMsg: a.statusMsg,
      };
    }
    case "FINALIZE":
      return {
        ...s,
        flash: null,
        animating: false,
        current: a.over ? s.current : a.next,
        status: a.over ? "over" : "playing",
        result: a.result,
        statusMsg: a.statusMsg,
        timer: { remaining: a.perTurn, perTurn: a.perTurn, round: Math.floor((s.turnCount + 1) / 2) },
        turnCount: s.turnCount + 1,
      };
    case "TIMER_TICK":
      if (!Number.isFinite(s.timer.remaining)) return s;
      return {
        ...s,
        timer: { ...s.timer, remaining: Math.max(0, s.timer.remaining - a.dec) },
      };
    case "DISMISS_POPUP":
      return { ...s, popups: s.popups.filter((p) => p.id !== a.id) };
    case "SHAKE":
      return { ...s, shake: s.shake + 1, statusMsg: a.msg };
    case "SET_STATUS_MSG":
      return { ...s, statusMsg: a.msg };
    case "RESTART":
      return a.initial;
    default:
      return s;
  }
}

export interface GameSession {
  cfg: RuleConfig;
  mode: GameMode;
  botLevel: BotLevel;
  blitz: BlitzPreset;
  names: [string, string];
}

function makeInitialState(session: GameSession, seed: number): {
  state: State;
  bags: [Bag, Bag];
  botRng: () => number;
} {
  const bags: [Bag, Bag] = [new Bag(seed + 11), new Bag(seed + 99)];
  const handSize = session.cfg.handSize;
  const players: [Player, Player] = [
    {
      score: 0,
      combo: 0,
      isBot: false,
      hand: Array.from({ length: handSize }, () => bags[0].draw()),
    },
    {
      score: 0,
      combo: 0,
      isBot: session.mode === "bot",
      hand: Array.from({ length: handSize }, () => bags[1].draw()),
    },
  ];
  const perTurn = perTurnForRound(session.blitz, session.cfg, 0);
  const state: State = {
    board: emptyBoard(),
    players,
    current: 0,
    status: "playing",
    sel: null,
    hover: null,
    flash: null,
    popups: [],
    timer: { remaining: perTurn, perTurn, round: 0 },
    turnCount: 0,
    statusMsg:
      session.mode === "bot"
        ? "Выбери фигуру → кликни по полю"
        : "Игрок 1: твой ход",
    animating: false,
    result: null,
    shake: 0,
  };
  const botRng = makeRng(seed + 7);
  return { state, bags, botRng };
}

function perTurnForRound(blitz: BlitzPreset, cfg: RuleConfig, round: number): number {
  if (!cfg.turnTimerEnabled) return Infinity;
  const preset = BLITZ_PRESETS[blitz];
  // Из ТЗ: уменьшение turnTimeDecay/раунд, не ниже turnTimeMin. Прототип использовал
  // целые секунды и уменьшение на 1с каждые 2 хода — оставляем плавное по ТЗ.
  return Math.max(preset.min, preset.start - cfg.turnTimeDecay * Math.max(0, round));
}

let POPUP_ID = 1;

export function useGame(session: GameSession) {
  const seedRef = useRef<number>(Math.floor(Math.random() * 0xffff) || 1234);
  const bagsRef = useRef<[Bag, Bag] | null>(null);
  const botRngRef = useRef<(() => number) | null>(null);
  const popupTimersRef = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());
  const finalizeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const botTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pausedRef = useRef<boolean>(false);

  const initialPack = useMemo(() => makeInitialState(session, seedRef.current), []);
  if (!bagsRef.current) {
    bagsRef.current = initialPack.bags;
    botRngRef.current = initialPack.botRng;
  }

  const [state, dispatch] = useReducer(reducer, initialPack.state);
  const stateRef = useRef(state);
  stateRef.current = state;

  const sessionRef = useRef(session);
  sessionRef.current = session;

  const clearAllTimers = useCallback(() => {
    popupTimersRef.current.forEach(clearTimeout);
    popupTimersRef.current.clear();
    if (finalizeTimerRef.current) {
      clearTimeout(finalizeTimerRef.current);
      finalizeTimerRef.current = null;
    }
    if (botTimerRef.current) {
      clearTimeout(botTimerRef.current);
      botTimerRef.current = null;
    }
  }, []);

  // Координированный «ход»: считаем результат, диспатчим APPLY_MOVE, ставим
  // таймер на FINALIZE (за время отыгрыша анимации очистки).
  const performMove = useCallback((move: CandidateMove, owner: 0 | 1) => {
    const s = stateRef.current;
    const sess = sessionRef.current;
    const cfg = sess.cfg;
    const newBoard = cloneBoard(s.board);
    place(newBoard, move.cells, move.r, move.c, owner);
    const clears = findClears(newBoard);
    let cleared: Set<string> | null = null;
    let popup: ScorePopup | null = null;
    let gained = 0;
    let perfect = false;
    let statusMsg: string;
    if (clears.count > 0) {
      const filledAfter = countFilled(newBoard) - clears.cleared.length;
      perfect = filledAfter === 0;
      gained = scoreForMove(clears.count, s.players[owner].combo, perfect, cfg);
      cleared = new Set(clears.cleared.map(([r, c]) => `${r},${c}`));
      const id = POPUP_ID++;
      const text =
        `+${gained}` +
        (perfect ? " PERFECT!" : clears.count > 1 ? ` ×${clears.count}` : "");
      popup = { id, r: move.r, c: move.c, owner, text };
      const t = setTimeout(() => {
        popupTimersRef.current.delete(t);
        dispatch({ type: "DISMISS_POPUP", id });
      }, 950);
      popupTimersRef.current.add(t);
      const actor = owner === 0 ? "Ты очистил" : `${sess.names[owner]} очистил`;
      const w = clears.count === 1 ? "линию" : "линии";
      statusMsg = `${actor} ${clears.count} ${w} (+${gained})`;
    } else {
      statusMsg = owner === 0 ? "Ход сделан" : `${sess.names[owner]} походил`;
    }

    // дотягиваем руку до cfg.handSize (берём из своего мешка)
    const bag = bagsRef.current![owner];
    const handAfterRemoval =
      s.players[owner].hand.filter((p) => p.id !== move.pieceId).length;
    const newPiece = handAfterRemoval < cfg.handSize ? bag.draw() : null;

    dispatch({
      type: "APPLY_MOVE",
      owner,
      newBoard,
      cleared,
      pieceIdRemoved: move.pieceId,
      newPiece,
      gained,
      popup,
      perfect,
      clearedCount: clears.count,
      statusMsg,
    });

    const delay = clears.count > 0 ? 430 : 150;
    finalizeTimerRef.current = setTimeout(() => {
      finalizeTimerRef.current = null;
      finalizeMove(clears.cleared);
    }, delay);
  }, []);

  const finalizeMove = useCallback((clearedCells: Coord[]) => {
    const s = stateRef.current;
    const sess = sessionRef.current;
    const cfg = sess.cfg;
    const boardAfter = cloneBoard(s.board);
    if (clearedCells.length > 0) applyClears(boardAfter, clearedCells);

    const next: 0 | 1 = (1 - s.current) as 0 | 1;
    const nextRound = Math.floor((s.turnCount + 1) / 2);
    const perTurn = perTurnForRound(sess.blitz, cfg, nextRound);
    const opponentHasMove = hasAnyMove(boardAfter, s.players[next].hand, cfg);

    if (!opponentHasMove) {
      const scores: [number, number] = [s.players[0].score, s.players[1].score];
      const winner: 0 | 1 | -1 = scores[0] > scores[1] ? 0 : scores[1] > scores[0] ? 1 : -1;
      dispatch({
        type: "FINALIZE",
        perTurn,
        next,
        over: true,
        statusMsg: "Игра окончена",
        result: { winner, scores },
      });
      return;
    }

    const nextStatus =
      sess.mode === "bot"
        ? next === 0
          ? "Твой ход"
          : `${sess.names[1]} думает…`
        : `Ходит: ${sess.names[next]}`;

    dispatch({
      type: "FINALIZE",
      perTurn,
      next,
      over: false,
      statusMsg: nextStatus,
      result: null,
    });
  }, []);

  // Бот делает ход, когда наступила его очередь
  useEffect(() => {
    if (state.status !== "playing") return;
    if (state.animating) return;
    const isBotsTurn = state.players[state.current].isBot;
    if (!isBotsTurn) return;
    if (botTimerRef.current) return;
    const delay = 400 + Math.floor((botRngRef.current?.() ?? 0.5) * 800);
    botTimerRef.current = setTimeout(() => {
      botTimerRef.current = null;
      const s = stateRef.current;
      if (s.status !== "playing" || !s.players[s.current].isBot) return;
      const sess = sessionRef.current;
      const move = chooseBotMove(
        s.board,
        s.players[s.current].hand,
        sess.botLevel,
        sess.cfg,
        botRngRef.current!,
      );
      if (!move) {
        finalizeMove([]);
        return;
      }
      performMove(move, s.current);
    }, delay);
  }, [state.current, state.status, state.animating, state.players, performMove, finalizeMove]);

  // Tick таймера
  useEffect(() => {
    if (state.status !== "playing") return;
    if (state.animating) return;
    if (pausedRef.current) return;
    if (!Number.isFinite(state.timer.remaining)) return;
    const iv = setInterval(() => {
      const s = stateRef.current;
      if (s.status !== "playing" || s.animating || pausedRef.current) return;
      if (s.timer.remaining - 0.1 <= 0) {
        // таймаут
        const sess = sessionRef.current;
        const preferred = s.sel?.pieceId;
        const fp = forcePlace(s.board, s.players[s.current].hand, sess.cfg, botRngRef.current!, preferred);
        if (fp) {
          dispatch({ type: "SET_STATUS_MSG", msg: "Время вышло — авто-ход" });
          performMove(fp, s.current);
        } else {
          finalizeMove([]);
        }
      } else {
        dispatch({ type: "TIMER_TICK", dec: 0.1 });
      }
    }, 100);
    return () => clearInterval(iv);
  }, [state.status, state.animating, state.current, state.timer.remaining, performMove, finalizeMove]);

  // size-effects clean-up при размонтировании
  useEffect(() => clearAllTimers, [clearAllTimers]);

  // --- user actions ---
  const selectPiece = useCallback((piece: PieceInstance) => {
    const s = stateRef.current;
    if (s.status !== "playing" || s.animating || pausedRef.current) return;
    if (s.players[s.current].isBot) return;
    if (!s.players[s.current].hand.some((p) => p.id === piece.id)) return;
    dispatch({ type: "SELECT", piece });
  }, []);

  const rotateSel = useCallback(() => dispatch({ type: "ROTATE" }), []);
  const flipSel = useCallback(() => dispatch({ type: "FLIP" }), []);
  const clearSel = useCallback(() => dispatch({ type: "CLEAR_SEL" }), []);
  const onHover = useCallback((r: number, c: number) => {
    const s = stateRef.current;
    if (!s.sel || s.animating || pausedRef.current) return;
    dispatch({ type: "HOVER", r, c });
  }, []);
  const onLeave = useCallback(() => dispatch({ type: "LEAVE" }), []);

  const onPlace = useCallback((r: number, c: number) => {
    const s = stateRef.current;
    if (s.status !== "playing" || s.animating || pausedRef.current) return;
    if (s.players[s.current].isBot) return;
    if (!s.sel) return;
    if (canPlace(s.board, s.sel.cells, r, c)) {
      const piece = s.players[s.current].hand.find((p) => p.id === s.sel!.pieceId);
      if (!piece) return;
      performMove({ pieceId: s.sel.pieceId, type: piece.type, cells: s.sel.cells, r, c }, s.current);
    } else {
      dispatch({ type: "SHAKE", msg: "Сюда не помещается" });
    }
  }, [performMove]);

  const setPaused = useCallback((v: boolean) => {
    pausedRef.current = v;
  }, []);

  const restart = useCallback(() => {
    clearAllTimers();
    seedRef.current = Math.floor(Math.random() * 0xffff) || 1234;
    const fresh = makeInitialState(sessionRef.current, seedRef.current);
    bagsRef.current = fresh.bags;
    botRngRef.current = fresh.botRng;
    dispatch({ type: "RESTART", initial: fresh.state });
  }, [clearAllTimers]);

  // --- derived ---
  const ghost = useMemo(() => {
    if (!state.sel || !state.hover) return null;
    const { r, c } = state.hover;
    const ok = canPlace(state.board, state.sel.cells, r, c);
    const map = new Map<string, "good" | "bad">();
    for (const [dr, dc] of state.sel.cells) {
      const rr = r + dr;
      const cc = c + dc;
      if (rr >= 0 && rr < SIZE && cc >= 0 && cc < SIZE && !state.board[rr][cc].filled) {
        map.set(`${rr},${cc}`, ok ? "good" : "bad");
      }
    }
    return { map };
  }, [state.sel, state.hover, state.board]);

  const deadIds = useMemo(() => {
    const owner = state.current;
    const s = new Set<string>();
    for (const piece of state.players[owner].hand) {
      if (!pieceHasMove(state.board, piece, sessionRef.current.cfg)) s.add(piece.id);
    }
    return s;
  }, [state.board, state.players, state.current]);

  return {
    state,
    ghost,
    deadIds,
    selectPiece,
    rotateSel,
    flipSel,
    clearSel,
    onHover,
    onLeave,
    onPlace,
    setPaused,
    restart,
  };
}

function countFilled(board: Board): number {
  let n = 0;
  for (const row of board) for (const c of row) if (c.filled) n++;
  return n;
}
