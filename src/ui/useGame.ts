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
  scoreMoveDetailed,
  SIZE,
  type Board,
  type BotLevel,
  type CandidateMove,
  type Coord,
  type PieceInstance,
  type RuleConfig,
} from "../core";
import {
  playClear,
  playInvalid,
  playLose,
  playPerfect,
  playPlace,
  playWin,
  playDraw,
  vibrateClear,
  vibrateInvalid,
  vibrateLose,
  vibratePerfect,
  vibratePlace,
  vibrateWin,
} from "./audio";
import type { ScorePopup } from "./components/Board";
import type { MatchResult } from "./screens/ResultOverlay";
import type { GameMode } from "./screens/MenuScreen";
import { BLITZ_PRESETS, type BlitzPreset } from "./screens/SetupScreen";
import {
  clearSavedGame,
  loadSavedGame,
  saveGame,
  type SavedGame,
} from "./storage/saveGame";
import type { MatchOutcome } from "./storage/stats";

interface Selection {
  pieceId: string;
  cells: Coord[];
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
  shake: number;
  totalClears: number;
  maxMultiClear: number;
  bestCombo: number;        // максимум combo, достигнутый игроком 0 в этой партии
  hadPerfectClear: boolean; // был ли хоть один perfect (любым игроком)
  baseScoreP0: number;      // breakdown очков игрока 0
  comboBonusP0: number;
  perfectBonusP0: number;
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
      clearedCount: number;
      statusMsg: string;
      perfect: boolean;
      baseAddP0: number;     // вклад в base score игрока 0 (0 если ход бота)
      comboAddP0: number;
      perfectAddP0: number;
    }
  | {
      type: "FINALIZE";
      perTurn: number;
      next: 0 | 1;
      over: boolean;
      statusMsg: string;
      result: MatchResult | null;
      boardAfter: Board;
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
      const ownerComboNow = ownerP.combo; // обновлённое значение после ход выше
      const newBestCombo =
        a.owner === 0 ? Math.max(s.bestCombo, ownerComboNow) : s.bestCombo;
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
        totalClears: s.totalClears + a.clearedCount,
        maxMultiClear: Math.max(s.maxMultiClear, a.clearedCount),
        bestCombo: newBestCombo,
        hadPerfectClear: s.hadPerfectClear || a.perfect,
        baseScoreP0: s.baseScoreP0 + a.baseAddP0,
        comboBonusP0: s.comboBonusP0 + a.comboAddP0,
        perfectBonusP0: s.perfectBonusP0 + a.perfectAddP0,
      };
    }
    case "FINALIZE":
      return {
        ...s,
        board: a.boardAfter,
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
  /**
   * Уровень бота для каждого игрока. null = живой игрок.
   *   bot:     [null, level]
   *   hotseat: [null, null]
   *   botvbot: [levelA, levelB]
   */
  botLevels: [BotLevel | null, BotLevel | null];
  blitz: BlitzPreset;
  names: [string, string];
  /** Задержка хода бота (мс). По умолчанию 800. */
  botDelayMs?: number;
  /** Длительность анимации очистки (мс). По умолчанию 430. */
  clearAnimMs?: number;
}

interface InitPack {
  state: State;
  bags: [Bag, Bag];
  botRng: () => number;
  drawCounts: [number, number];
  seed: number;
}

/**
 * Заполняет руку из мешка `size` уникальными по типу фигурами, насколько
 * позволяет состояние bag. Опирается на 7-bag (Bag.drawAvoiding).
 */
function fillHand(bag: Bag, size: number, startWith: PieceInstance[] = []): PieceInstance[] {
  const out = [...startWith];
  while (out.length < size) {
    const avoid = new Set(out.map((p) => p.type));
    out.push(bag.drawAvoiding(avoid));
  }
  return out;
}

function freshInit(session: GameSession, seed: number): InitPack {
  const bags: [Bag, Bag] = [new Bag(seed + 11), new Bag(seed + 99)];
  const handSize = session.cfg.handSize;
  const players: [Player, Player] = [
    {
      score: 0,
      combo: 0,
      isBot: session.botLevels[0] !== null,
      hand: fillHand(bags[0], handSize),
    },
    {
      score: 0,
      combo: 0,
      isBot: session.botLevels[1] !== null,
      hand: fillHand(bags[1], handSize),
    },
  ];
  const perTurn = perTurnForRound(session.blitz, session.cfg, 0);
  return {
    state: {
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
      totalClears: 0,
      maxMultiClear: 0,
      bestCombo: 0,
      hadPerfectClear: false,
      baseScoreP0: 0,
      comboBonusP0: 0,
      perfectBonusP0: 0,
    },
    bags,
    botRng: makeRng(seed + 7),
    drawCounts: [handSize, handSize],
    seed,
  };
}

function restoreInit(session: GameSession, saved: SavedGame): InitPack {
  // Перематываем мешки на сохранённое количество дёрганий.
  const bags: [Bag, Bag] = [new Bag(saved.seed + 11), new Bag(saved.seed + 99)];
  for (let i = 0; i < saved.drawCounts[0]; i++) bags[0].draw();
  for (let i = 0; i < saved.drawCounts[1]; i++) bags[1].draw();
  // А botRng — детерминирован от seed, но мы не считали его вызовы.
  // Это слегка нарушает детерминизм бота при load (вызовы между сохранениями не повторяются).
  // Для UX автосохранения такого допущения достаточно.
  const botRng = makeRng(saved.seed + 7);
  return {
    state: {
      board: saved.board,
      players: [
        { ...saved.players[0], isBot: session.botLevels[0] !== null },
        { ...saved.players[1], isBot: session.botLevels[1] !== null },
      ] as [Player, Player],
      current: saved.current,
      status: "playing",
      sel: null,
      hover: null,
      flash: null,
      popups: [],
      timer: {
        remaining: saved.remaining,
        perTurn: saved.perTurn,
        round: Math.floor(saved.turnCount / 2),
      },
      turnCount: saved.turnCount,
      statusMsg: session.mode === "bot" ? "Партия восстановлена" : `Ходит: ${session.names[saved.current]}`,
      animating: false,
      result: null,
      shake: 0,
      totalClears: saved.totalClears,
      maxMultiClear: saved.maxMultiClear,
      bestCombo: 0,
      hadPerfectClear: false,
      baseScoreP0: 0,
      comboBonusP0: 0,
      perfectBonusP0: 0,
    },
    bags,
    botRng,
    drawCounts: [...saved.drawCounts] as [number, number],
    seed: saved.seed,
  };
}

function perTurnForRound(blitz: BlitzPreset, cfg: RuleConfig, round: number): number {
  if (!cfg.turnTimerEnabled) return Infinity;
  const preset = BLITZ_PRESETS[blitz];
  return Math.max(preset.min, preset.start - cfg.turnTimeDecay * Math.max(0, round));
}

let POPUP_ID = 1;

export interface UseGameOptions {
  session: GameSession;
  savedGame: SavedGame | null;
  onMatchOver?: (outcome: MatchOutcome) => void;
  onPerfect?: () => void;
  /** Зовётся когда combo живого игрока пересекает порог 3/5/10. */
  onComboMilestone?: (level: 1 | 2 | 3, combo: number) => void;
}

export function useGame({ session, savedGame, onMatchOver, onPerfect, onComboMilestone }: UseGameOptions) {
  const bagsRef = useRef<[Bag, Bag] | null>(null);
  const botRngRef = useRef<(() => number) | null>(null);
  const drawCountsRef = useRef<[number, number]>([0, 0]);
  const seedRef = useRef<number>(0);
  const popupTimersRef = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());
  const finalizeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pausedRef = useRef<boolean>(false);
  const matchOverFiredRef = useRef<boolean>(false);

  const initialPack = useMemo(() => {
    const seed = savedGame?.seed ?? (Math.floor(Math.random() * 0xffff) || 1234);
    return savedGame ? restoreInit(session, savedGame) : freshInit(session, seed);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  if (!bagsRef.current) {
    bagsRef.current = initialPack.bags;
    botRngRef.current = initialPack.botRng;
    drawCountsRef.current = initialPack.drawCounts;
    seedRef.current = initialPack.seed;
  }

  const [state, dispatch] = useReducer(reducer, initialPack.state);
  const stateRef = useRef(state);
  stateRef.current = state;

  const sessionRef = useRef(session);
  sessionRef.current = session;

  const onMatchOverRef = useRef(onMatchOver);
  onMatchOverRef.current = onMatchOver;
  const onPerfectRef = useRef(onPerfect);
  onPerfectRef.current = onPerfect;
  const onComboMilestoneRef = useRef(onComboMilestone);
  onComboMilestoneRef.current = onComboMilestone;

  const clearAllTimers = useCallback(() => {
    popupTimersRef.current.forEach(clearTimeout);
    popupTimersRef.current.clear();
    if (finalizeTimerRef.current) {
      clearTimeout(finalizeTimerRef.current);
      finalizeTimerRef.current = null;
    }
  }, []);

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
    let baseAddP0 = 0;
    let comboAddP0 = 0;
    let perfectAddP0 = 0;
    if (clears.count > 0) {
      const filledAfter = countFilled(newBoard) - clears.cleared.length;
      perfect = filledAfter === 0;
      // Доля оставшегося времени (для speed-bonus). 0..1.
      const timeRatio = cfg.turnTimerEnabled && s.timer.perTurn > 0
        ? Math.max(0, Math.min(1, s.timer.remaining / s.timer.perTurn))
        : undefined;
      const breakdown = scoreMoveDetailed({
        rows: clears.rows.length,
        cols: clears.cols.length,
        boxes: clears.boxes.length,
        pieceType: move.type,
        combo: s.players[owner].combo,
        perfect,
        timeRatio,
        cfg,
      });
      gained = breakdown.total;
      if (owner === 0) {
        baseAddP0 = breakdown.base + breakdown.placement;
        comboAddP0 = breakdown.total - breakdown.base - breakdown.placement - breakdown.perfectBonus;
        perfectAddP0 = breakdown.perfectBonus;
      }
      cleared = new Set(clears.cleared.map(([r, c]) => `${r},${c}`));
      const id = POPUP_ID++;
      // Информативный popup: показываем доп. ярлык для multi-clear / combo / speed / perfect.
      let suffix = "";
      if (perfect) suffix = " PERFECT!";
      else if (clears.boxes.length > 0 && clears.count > 1) suffix = ` ×${clears.count} box`;
      else if (clears.count > 1) suffix = ` ×${clears.count}`;
      else if (breakdown.comboMult > 1.5) suffix = " combo";
      else if (breakdown.speedMult > 1.15) suffix = " fast";
      const text = `+${gained}${suffix}`;
      popup = { id, r: move.r, c: move.c, owner, text };
      const t = setTimeout(() => {
        popupTimersRef.current.delete(t);
        dispatch({ type: "DISMISS_POPUP", id });
      }, 950);
      popupTimersRef.current.add(t);
      const actor = owner === 0 ? "Ты очистил" : `${sess.names[owner]} очистил`;
      const w = clears.count === 1 ? "линию" : "линии";
      statusMsg = `${actor} ${clears.count} ${w} (+${gained})`;
      if (perfect) {
        playPerfect();
        vibratePerfect();
        onPerfectRef.current?.();
      } else {
        playClear(clears.count);
        vibrateClear(clears.count);
      }
      // Combo milestone (только для живого игрока). До хода combo было s.players[owner].combo;
      // после успешной очистки оно станет +1 (см. reducer APPLY_MOVE).
      const isHuman = sess.botLevels[owner] === null;
      if (isHuman) {
        const oldC = s.players[owner].combo;
        const newC = oldC + 1;
        let level: 1 | 2 | 3 | 0 = 0;
        if (oldC < 3 && newC >= 3) level = 1;
        if (oldC < 5 && newC >= 5) level = 2;
        if (oldC < 10 && newC >= 10) level = 3;
        if (level !== 0) onComboMilestoneRef.current?.(level, newC);
      }
    } else {
      // Очисток нет, но placement-бонус (за тип фигуры) всё равно начисляется.
      const placement = cfg.placementBonus[move.type] ?? 0;
      gained = placement;
      if (placement > 0 && owner === 0) baseAddP0 = placement;
      if (placement > 0) {
        const id = POPUP_ID++;
        popup = { id, r: move.r, c: move.c, owner, text: `+${placement}` };
        const t = setTimeout(() => {
          popupTimersRef.current.delete(t);
          dispatch({ type: "DISMISS_POPUP", id });
        }, 700);
        popupTimersRef.current.add(t);
      }
      statusMsg = owner === 0 ? `Ход сделан${placement ? ` (+${placement})` : ""}` : `${sess.names[owner]} походил`;
      playPlace();
      vibratePlace();
    }
    void scoreForMove; // legacy импорт сохранён для бота, не используется здесь напрямую

    const bag = bagsRef.current![owner];
    const remainingHand = s.players[owner].hand.filter((p) => p.id !== move.pieceId);
    let newPiece: PieceInstance | null = null;
    if (remainingHand.length < cfg.handSize) {
      const avoid = new Set(remainingHand.map((p) => p.type));
      newPiece = bag.drawAvoiding(avoid);
      drawCountsRef.current[owner]++;
    }

    dispatch({
      type: "APPLY_MOVE",
      owner,
      newBoard,
      cleared,
      pieceIdRemoved: move.pieceId,
      newPiece,
      gained,
      popup,
      clearedCount: clears.count,
      statusMsg,
      perfect,
      baseAddP0,
      comboAddP0,
      perfectAddP0,
    });

    const clearMs = sessionRef.current.clearAnimMs ?? 430;
    const delay = clears.count > 0 ? clearMs : Math.max(80, Math.floor(clearMs * 0.35));
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

    // В аркаде ходит только player 0; ход не передаём, дедлок считаем сам себе.
    const next: 0 | 1 = sess.mode === "arcade" ? 0 : ((1 - s.current) as 0 | 1);
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
        boardAfter,
      });
      clearSavedGame();
      // Финальные fx
      if (winner === 0) { playWin(); vibrateWin(); }
      else if (winner === 1) { playLose(); vibrateLose(); }
      else { playDraw(); }
      if (!matchOverFiredRef.current) {
        matchOverFiredRef.current = true;
        onMatchOverRef.current?.({
          winner,
          scores,
          myScore: s.players[0].score,
          totalClearsThisMatch: s.totalClears,
          maxMultiClearThisMatch: s.maxMultiClear,
          bestComboThisMatch: s.bestCombo,
          hadPerfectClear: s.hadPerfectClear,
          baseScore: s.baseScoreP0,
          comboBonus: s.comboBonusP0,
          perfectBonus: s.perfectBonusP0,
        });
      }
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
      boardAfter,
    });

    // Автосохранение текущего состояния после хода.
    const finalState = stateRef.current;
    saveGame({
      version: 2,
      seed: seedRef.current,
      cfg: sess.cfg,
      mode: sess.mode,
      botLevel: sess.botLevels[1] ?? sess.botLevels[0] ?? "medium",
      botLevels: sess.botLevels,
      blitz: sess.blitz,
      board: boardAfter,
      players: [
        { ...finalState.players[0] },
        { ...finalState.players[1] },
      ],
      drawCounts: [...drawCountsRef.current] as [number, number],
      current: next,
      turnCount: s.turnCount + 1,
      perTurn,
      remaining: perTurn,
      totalClears: finalState.totalClears,
      maxMultiClear: finalState.maxMultiClear,
      savedAt: Date.now(),
    });
  }, []);

  useEffect(() => {
    if (state.status !== "playing") return;
    if (state.animating) return;
    const isBotsTurn = state.players[state.current].isBot;
    if (!isBotsTurn) return;
    // base = настройка пользователя, ±20% случайного джиттера для «живости»
    const base = sessionRef.current.botDelayMs ?? 800;
    const jitter = (botRngRef.current?.() ?? 0.5) * 0.4 - 0.2; // -0.2..+0.2
    const delay = Math.max(0, Math.floor(base * (1 + jitter)));
    const t = setTimeout(() => {
      const s = stateRef.current;
      if (s.status !== "playing" || !s.players[s.current].isBot) return;
      const sess = sessionRef.current;
      const lvl = sess.botLevels[s.current];
      if (!lvl) return;
      const move = chooseBotMove(
        s.board,
        s.players[s.current].hand,
        lvl,
        sess.cfg,
        botRngRef.current!,
      );
      if (!move) {
        finalizeMove([]);
        return;
      }
      performMove(move, s.current);
    }, delay);
    return () => clearTimeout(t);
  }, [state.current, state.status, state.animating, state.players, performMove, finalizeMove]);

  useEffect(() => {
    if (state.status !== "playing") return;
    if (state.animating) return;
    if (pausedRef.current) return;
    if (!Number.isFinite(state.timer.remaining)) return;
    const iv = setInterval(() => {
      const s = stateRef.current;
      if (s.status !== "playing" || s.animating || pausedRef.current) return;
      if (s.timer.remaining - 0.1 <= 0) {
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

  useEffect(() => clearAllTimers, [clearAllTimers]);

  const selectPiece = useCallback((piece: PieceInstance) => {
    const s = stateRef.current;
    if (s.status !== "playing" || s.animating || pausedRef.current) return;
    // Pre-select: разрешаем выбрать фигуру из руки ЛЮБОГО игрока-человека,
    // даже когда сейчас ходит бот. Это даёт возможность подготовить фигуру
    // к следующему ходу. Финальный place всё равно проверит s.current и
    // s.players[s.current].isBot, поэтому пользователь не сможет сходить
    // вне очереди.
    const isHumanPiece = s.players.some((p) => !p.isBot && p.hand.some((hp) => hp.id === piece.id));
    if (!isHumanPiece) return;
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
      playInvalid();
      vibrateInvalid();
    }
  }, [performMove]);

  const setPaused = useCallback((v: boolean) => {
    pausedRef.current = v;
  }, []);

  const restart = useCallback(() => {
    clearAllTimers();
    clearSavedGame();
    matchOverFiredRef.current = false;
    const seed = Math.floor(Math.random() * 0xffff) || 1234;
    const fresh = freshInit(sessionRef.current, seed);
    bagsRef.current = fresh.bags;
    botRngRef.current = fresh.botRng;
    drawCountsRef.current = fresh.drawCounts;
    seedRef.current = fresh.seed;
    dispatch({ type: "RESTART", initial: fresh.state });
  }, [clearAllTimers]);

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

  // ─── Power-ups ─────────────────────────────────────────────────────────
  /** Очистить произвольные клетки + начислить очки игроку 0 как обычную очистку. */
  const applyArbitraryClear = useCallback((targets: Coord[], reason: string): boolean => {
    const s = stateRef.current;
    const sess = sessionRef.current;
    if (s.status !== "playing" || s.animating) return false;
    // Считаем только filled клетки.
    const cleared: Coord[] = [];
    for (const [r, c] of targets) {
      if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) continue;
      if (s.board[r][c].filled) cleared.push([r, c]);
    }
    if (cleared.length === 0) return false;
    const newBoard = cloneBoard(s.board);
    applyClears(newBoard, cleared);
    // приближённое начисление: считаем как N=1 очистку с реальным числом клеток
    const N = 1;
    const gained = scoreForMove(N, 0, false, sess.cfg);
    const cellsKey = new Set(cleared.map(([r, c]) => `${r},${c}`));
    dispatch({
      type: "APPLY_MOVE",
      owner: 0,
      newBoard,
      cleared: cellsKey,
      pieceIdRemoved: "",
      newPiece: null,
      gained,
      popup: {
        id: POPUP_ID++,
        r: cleared[0][0],
        c: cleared[0][1],
        owner: 0,
        text: `+${gained} ${reason}`,
      },
      clearedCount: 0, // не считаем как «полная очистка линии», чтобы не сбить ачивки
      statusMsg: reason,
      perfect: false,
      baseAddP0: gained,
      comboAddP0: 0,
      perfectAddP0: 0,
    });
    // Через delay снимаем flash и не передаём ход.
    finalizeTimerRef.current = setTimeout(() => {
      finalizeTimerRef.current = null;
      // FINALIZE без смены current — переиспользуем finalizeMove с current=0 sentinel
      const board2 = cloneBoard(stateRef.current.board);
      dispatch({
        type: "FINALIZE",
        perTurn: stateRef.current.timer.perTurn,
        next: stateRef.current.current,
        over: false,
        statusMsg: stateRef.current.statusMsg,
        result: null,
        boardAfter: board2,
      });
    }, 320);
    return true;
  }, []);

  /** Очистить целую строку. */
  const powerClearRow = useCallback((row: number): boolean => {
    const coords: Coord[] = [];
    for (let c = 0; c < SIZE; c++) coords.push([row, c]);
    return applyArbitraryClear(coords, "⚡ строка");
  }, [applyArbitraryClear]);

  /** Очистить целый столбец. */
  const powerClearCol = useCallback((col: number): boolean => {
    const coords: Coord[] = [];
    for (let r = 0; r < SIZE; r++) coords.push([r, col]);
    return applyArbitraryClear(coords, "⚡ столбец");
  }, [applyArbitraryClear]);

  /** Бомба 3×3. */
  const powerBomb = useCallback((centerR: number, centerC: number): boolean => {
    const coords: Coord[] = [];
    for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
      coords.push([centerR + dr, centerC + dc]);
    }
    return applyArbitraryClear(coords, "💣 бомба");
  }, [applyArbitraryClear]);

  /** Обмен всех фигур в руке игрока 0 на новые из мешка. */
  const powerSwapHand = useCallback((): boolean => {
    const s = stateRef.current;
    if (s.status !== "playing" || s.animating) return false;
    const bag = bagsRef.current?.[0];
    if (!bag) return false;
    const newHand = fillHand(bag, sessionRef.current.cfg.handSize);
    drawCountsRef.current[0] += newHand.length;
    // Заменяем hand игрока 0 через mini-redaktor.
    const players = s.players.map((p, i) => i === 0 ? { ...p, hand: newHand } : p) as [Player, Player];
    dispatch({
      type: "RESTART",
      initial: { ...s, players, sel: null, hover: null, statusMsg: "🔄 рука обновлена" },
    });
    return true;
  }, []);

  /** Найти лучший ход (best evaluation) для игрока 0. */
  const findBestMove = useCallback((): CandidateMove | null => {
    const s = stateRef.current;
    const sess = sessionRef.current;
    return chooseBotMove(s.board, s.players[0].hand, "hard", sess.cfg, botRngRef.current!);
  }, []);

  /** Подсветка лучшего хода (через ghost): селектим фигуру и hover на её позицию. Возвращаем cells для UI. */
  const powerHint = useCallback((): { pieceId: string; cells: Coord[]; r: number; c: number } | null => {
    const m = findBestMove();
    if (!m) return null;
    dispatch({ type: "SELECT", piece: { id: m.pieceId, type: m.type, cells: m.cells } });
    dispatch({ type: "HOVER", r: m.r, c: m.c });
    return { pieceId: m.pieceId, cells: m.cells, r: m.r, c: m.c };
  }, [findBestMove]);

  /** Умный ход — найти и сразу применить лучший. */
  const powerAutoPlay = useCallback((): boolean => {
    const s = stateRef.current;
    if (s.status !== "playing" || s.animating) return false;
    if (s.players[s.current].isBot) return false;
    const m = findBestMove();
    if (!m) return false;
    performMove(m, 0);
    return true;
  }, [findBestMove, performMove]);

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
    // Power-ups
    powerClearRow,
    powerClearCol,
    powerBomb,
    powerSwapHand,
    powerHint,
    powerAutoPlay,
  };
}

function countFilled(board: Board): number {
  let n = 0;
  for (const row of board) for (const c of row) if (c.filled) n++;
  return n;
}

export { loadSavedGame };
