import { QUEST_POOL } from "../daily/definitions";
import { readJSON, writeJSON } from "./storage";

const KEY = "bd_daily";

export interface QuestProgress {
  defId: string;
  current: number;
  completed: boolean;
  claimed: boolean;
}

export interface DailyState {
  /** Локальная дата YYYY-MM-DD, на которую сгенерирован пакет. */
  date: string;
  quests: QuestProgress[];
}

export function todayStr(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function pickThree(): QuestProgress[] {
  // случайные 3 из пула, без повторов
  const idx = new Set<number>();
  while (idx.size < 3) {
    idx.add(Math.floor(Math.random() * QUEST_POOL.length));
  }
  return [...idx].map((i) => ({
    defId: QUEST_POOL[i].id,
    current: 0,
    completed: false,
    claimed: false,
  }));
}

export function loadDaily(): DailyState {
  const raw = readJSON<DailyState | null>(KEY, null);
  const today = todayStr();
  if (raw && raw.date === today && raw.quests?.length === 3) return raw;
  // новый день — генерим новый пакет
  const fresh: DailyState = { date: today, quests: pickThree() };
  writeJSON(KEY, fresh);
  return fresh;
}

export function saveDaily(s: DailyState): void {
  writeJSON(KEY, s);
}
