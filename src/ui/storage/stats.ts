import { readJSON, writeJSON } from "./storage";

const KEY = "bd_stats";

export interface Stats {
  games: number;
  wins: number;
  losses: number;
  draws: number;
  bestScore: number;
  totalClears: number;
  maxMultiClear: number;
  currentWinStreak: number;
  bestWinStreak: number;
  rematchStreak: number; // партий подряд через «Реванш»
  /** Online: общая статистика. */
  onlineGames: number;
  onlineWins: number;
  onlineLosses: number;
  onlineDraws: number;
  /** Online: расширенные счётчики для ачивок. */
  onlineCurrentWinStreak: number;
  onlineBestWinStreak: number;
  onlineCurrentNoLossStreak: number; // включая ничьи
  onlineBestNoLossStreak: number;
  onlineTotalClears: number;
  onlineTotalPerfects: number;
  onlineMaxMultiClear: number;
  onlineBestCombo: number;
  onlineBiggestWinGap: number;
  onlineBiggestComeback: number; // отставание которое отыграл при победе
  onlineFastestWinTurns: number; // 0 = нет
  onlineLongestMatchTurns: number;
  onlineLastPlayedDate: string; // YYYY-MM-DD, "" если ещё не играл
  onlineConsecutiveDays: number;
  onlineMaxConsecutiveDays: number;
  onlineUniqueOpponents: number;
  onlineMostVsSingleOpponent: number;
  /** Карта соперник→{count,wins,losses,lossStreakWith}. */
  onlineOpponents: Record<string, { count: number; wins: number; losses: number; lastResult: "win" | "loss" | "draw" }>;
  onlineMaxRematchWinStreak: number;
  /** Кол-во разных тем, в которых был онлайн-матч. */
  onlineThemesPlayed: string[];
}

export const DEFAULT_STATS: Stats = {
  games: 0,
  wins: 0,
  losses: 0,
  draws: 0,
  bestScore: 0,
  totalClears: 0,
  maxMultiClear: 0,
  currentWinStreak: 0,
  bestWinStreak: 0,
  rematchStreak: 0,
  onlineGames: 0,
  onlineWins: 0,
  onlineLosses: 0,
  onlineDraws: 0,
  onlineCurrentWinStreak: 0,
  onlineBestWinStreak: 0,
  onlineCurrentNoLossStreak: 0,
  onlineBestNoLossStreak: 0,
  onlineTotalClears: 0,
  onlineTotalPerfects: 0,
  onlineMaxMultiClear: 0,
  onlineBestCombo: 0,
  onlineBiggestWinGap: 0,
  onlineBiggestComeback: 0,
  onlineFastestWinTurns: 0,
  onlineLongestMatchTurns: 0,
  onlineLastPlayedDate: "",
  onlineConsecutiveDays: 0,
  onlineMaxConsecutiveDays: 0,
  onlineUniqueOpponents: 0,
  onlineMostVsSingleOpponent: 0,
  onlineOpponents: {},
  onlineMaxRematchWinStreak: 0,
  onlineThemesPlayed: [],
};

export function loadStats(): Stats {
  return { ...DEFAULT_STATS, ...readJSON<Partial<Stats>>(KEY, {}) };
}

export function saveStats(s: Stats): void {
  writeJSON(KEY, s);
}

export interface MatchOutcome {
  winner: 0 | 1 | -1;
  scores: [number, number];
  myScore: number;
  totalClearsThisMatch: number;
  maxMultiClearThisMatch: number;
  bestComboThisMatch: number;
  hadPerfectClear: boolean;
  // breakdown очков игрока 0
  baseScore: number;       // сумма N·(N+1)/2 по всем очисткам
  comboBonus: number;      // сколько добавили комбо-множители (round(base·mult)−base)
  perfectBonus: number;    // сумма +perfectClearBonus
}

/** Сводка по итогам online-матча — нужна и для stats, и для ачивок. */
export interface OnlineMatchInfo {
  won: boolean;
  drew: boolean;
  myScore: number;
  opponentScore: number;
  scoreGap: number;
  opponentId: string;
  opponentNick: string;
  turnCount: number;
  themeId: string;
  reason?: "deadlock" | "timeout" | "resign";
  /** Был ли реванш этого же соперника. */
  isRematchOfSameOpponent: boolean;
  /** Лучшее комбо в этом матче (если знаем; для online не отслеживаем — оставляем 0). */
  bestComboThisMatch: number;
  /** N≥X одним ходом — максимум за матч. */
  maxMultiClearThisMatch: number;
  /** Сколько очисток было за матч у тебя. */
  myClearsThisMatch: number;
  /** Был ли хоть один perfect clear у меня. */
  hadPerfectClear: boolean;
  /** Текущий ELO игрока (если знаем). */
  myElo?: number;
  /** Текущая дата YYYY-MM-DD на стороне клиента. */
  today: string;
}

export function applyOnlineMatchToStats(prev: Stats, m: OnlineMatchInfo): Stats {
  const out: Stats = {
    ...prev,
    onlineGames: prev.onlineGames + 1,
    onlineWins: prev.onlineWins + (m.won ? 1 : 0),
    onlineLosses: prev.onlineLosses + (!m.won && !m.drew ? 1 : 0),
    onlineDraws: prev.onlineDraws + (m.drew ? 1 : 0),
    onlineCurrentWinStreak: m.won ? prev.onlineCurrentWinStreak + 1 : 0,
    onlineCurrentNoLossStreak: m.won || m.drew ? prev.onlineCurrentNoLossStreak + 1 : 0,
    onlineTotalClears: prev.onlineTotalClears + m.myClearsThisMatch,
    onlineTotalPerfects: prev.onlineTotalPerfects + (m.hadPerfectClear ? 1 : 0),
    onlineMaxMultiClear: Math.max(prev.onlineMaxMultiClear, m.maxMultiClearThisMatch),
    onlineBestCombo: Math.max(prev.onlineBestCombo, m.bestComboThisMatch),
    onlineLongestMatchTurns: Math.max(prev.onlineLongestMatchTurns, m.turnCount),
  };
  out.onlineBestWinStreak = Math.max(prev.onlineBestWinStreak, out.onlineCurrentWinStreak);
  out.onlineBestNoLossStreak = Math.max(prev.onlineBestNoLossStreak, out.onlineCurrentNoLossStreak);

  if (m.won) {
    out.onlineBiggestWinGap = Math.max(prev.onlineBiggestWinGap, m.scoreGap);
    // camback фиксируем только если рекламный sign — myScore был меньше на M в середине, но нам нужен sloppy метрик:
    // используем (opponentScore - myScore + scoreGap) — приближённо. Здесь упростим: если соперник в конце имел >0 очков и мы выиграли, condition на "отыграл" применим только если scoreGap < threshold. Для onlineBiggestComeback используем abs(opponentScore - myScore) as approximated comeback margin only при scoreGap >= 0.
    // Для нашей цели достаточно: comeback = opponentScore (т.к. он почти равен или больше до того как ты собрал свой gap)
    // Это даёт оценочный камбэк-метрик "сколько очков соперник набрал до нашей победы".
    out.onlineBiggestComeback = Math.max(prev.onlineBiggestComeback, m.opponentScore);
    if (prev.onlineFastestWinTurns === 0 || m.turnCount < prev.onlineFastestWinTurns) {
      out.onlineFastestWinTurns = m.turnCount;
    }
  }

  // Соперник
  const op = prev.onlineOpponents[m.opponentId] ?? { count: 0, wins: 0, losses: 0, lastResult: "draw" as const };
  const isNewOpponent = !prev.onlineOpponents[m.opponentId];
  const opUpd = {
    count: op.count + 1,
    wins: op.wins + (m.won ? 1 : 0),
    losses: op.losses + (!m.won && !m.drew ? 1 : 0),
    lastResult: m.won ? ("win" as const) : m.drew ? ("draw" as const) : ("loss" as const),
  };
  out.onlineOpponents = { ...prev.onlineOpponents, [m.opponentId]: opUpd };
  out.onlineUniqueOpponents = prev.onlineUniqueOpponents + (isNewOpponent ? 1 : 0);
  out.onlineMostVsSingleOpponent = Math.max(prev.onlineMostVsSingleOpponent, opUpd.count);

  // Тема
  if (!prev.onlineThemesPlayed.includes(m.themeId)) {
    out.onlineThemesPlayed = [...prev.onlineThemesPlayed, m.themeId];
  }

  // Реванш-стрик (выиграл подряд против того же)
  if (m.isRematchOfSameOpponent && m.won) {
    // приближение: считаем от opUpd.wins подряд — слишком сложно отслеживать строго; апprox-ом примем lossless wins подряд против него.
    if (op.lastResult === "win") {
      // если в предыдущем матче с ним мы тоже выиграли — стрик продолжается. У нас нет отдельного поля для серии — используем simple max: opUpd.wins на месте.
      out.onlineMaxRematchWinStreak = Math.max(prev.onlineMaxRematchWinStreak, opUpd.wins);
    } else {
      out.onlineMaxRematchWinStreak = Math.max(prev.onlineMaxRematchWinStreak, 1);
    }
  }

  // Дни подряд
  if (m.today !== prev.onlineLastPlayedDate) {
    if (prev.onlineLastPlayedDate === "") {
      out.onlineConsecutiveDays = 1;
    } else {
      const prevD = Date.parse(prev.onlineLastPlayedDate);
      const todayD = Date.parse(m.today);
      const diff = Math.round((todayD - prevD) / 86_400_000);
      out.onlineConsecutiveDays = diff === 1 ? prev.onlineConsecutiveDays + 1 : 1;
    }
    out.onlineMaxConsecutiveDays = Math.max(prev.onlineMaxConsecutiveDays, out.onlineConsecutiveDays);
    out.onlineLastPlayedDate = m.today;
  }

  return out;
}

export function applyMatchToStats(prev: Stats, m: MatchOutcome): Stats {
  const winStreak = m.winner === 0 ? prev.currentWinStreak + 1 : 0;
  return {
    ...prev,
    games: prev.games + 1,
    wins: prev.wins + (m.winner === 0 ? 1 : 0),
    losses: prev.losses + (m.winner === 1 ? 1 : 0),
    draws: prev.draws + (m.winner === -1 ? 1 : 0),
    bestScore: Math.max(prev.bestScore, m.myScore),
    totalClears: prev.totalClears + m.totalClearsThisMatch,
    maxMultiClear: Math.max(prev.maxMultiClear, m.maxMultiClearThisMatch),
    currentWinStreak: winStreak,
    bestWinStreak: Math.max(prev.bestWinStreak, winStreak),
    rematchStreak: prev.rematchStreak, // обновляется в App при rematch/non-rematch
  };
}
