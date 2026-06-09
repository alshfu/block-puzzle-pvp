/**
 * limits.ts — защитные ограничения протокола (anti-DoS / валидация ввода).
 *
 * Закрывает находки аудита (SECURITY_AUDIT_SERVER.md):
 *   - H4: rate-limit на сообщения (вместе с maxPayload в index.ts);
 *   - M1: строгая валидация формы/диапазона входа `move` (cells/r/c).
 *
 * Чистый модуль без состояния сервера — переиспользуется лобби/комнатой/
 * лидербордом.
 */
import type { Coord } from "../legacy-ts/core";
import type { Conn } from "./types";

/** Параметры рейт-лимита по умолчанию: не более 40 сообщений за 1 c на conn. */
export const DEFAULT_MSG_PER_WINDOW = 40;
export const DEFAULT_WINDOW_MS = 1_000;

/**
 * Простой оконный rate-limiter на соединение (token-bucket по окну).
 * Состояние висит на самом conn через WeakMap → авто-GC при закрытии сокета.
 */
export class RateLimiter {
  private hits = new WeakMap<object, { count: number; resetAt: number }>();

  constructor(
    private max: number = DEFAULT_MSG_PER_WINDOW,
    private windowMs: number = DEFAULT_WINDOW_MS,
  ) {}

  /** true — сообщение можно обработать; false — лимит превышен, дропаем. */
  allow(conn: Conn): boolean {
    const now = Date.now();
    const rec = this.hits.get(conn);
    if (!rec || now >= rec.resetAt) {
      this.hits.set(conn, { count: 1, resetAt: now + this.windowMs });
      return true;
    }
    rec.count += 1;
    return rec.count <= this.max;
  }
}

/** Доска 9×9 → допустимый диапазон координат. */
const BOARD_SIZE = 9;

/** Максимум клеток в фигуре (тетромино = 4; запас на нормализацию). */
const MAX_PIECE_CELLS = 5;

/**
 * Строгая валидация входа хода до игровой логики (M1): cells — массив 1..5
 * целочисленных пар в [0,8]; r/c — целые в [0,8]. Защищает от гигантских/
 * кривых `cells` (CPU/исключения) ещё до canPlace/normalize.
 */
export function isValidMoveInput(
  cells: unknown,
  r: unknown,
  c: unknown,
): cells is Coord[] {
  if (!Array.isArray(cells) || cells.length < 1 || cells.length > MAX_PIECE_CELLS) {
    return false;
  }
  for (const cell of cells) {
    if (!Array.isArray(cell) || cell.length !== 2) return false;
    const [cr, cc] = cell as [unknown, unknown];
    if (!isCoordInt(cr) || !isCoordInt(cc)) return false;
  }
  return isCoordInt(r) && isCoordInt(c);
}

function isCoordInt(v: unknown): v is number {
  return typeof v === "number" && Number.isInteger(v) && v >= 0 && v < BOARD_SIZE;
}

/** Лимиты строковых полей профиля (M6: анти-мусор/раздувание). */
export const MAX_ID_LEN = 64;
export const MAX_NICK_LEN = 24;
export const MAX_AVATAR_LEN = 8;

/**
 * Валидация профиля игрока на входе: id/nick/avatar — непустые строки в
 * пределах лимитов. Длинный/кривой профиль отбрасывается (M6, частично H1 —
 * хотя бы санитайз; полноценная аутентификация — отдельно через roomToken).
 */
export function isValidProfile(p: unknown): p is { id: string; nick: string; avatar: string } {
  if (typeof p !== "object" || p === null) return false;
  const o = p as Record<string, unknown>;
  return (
    typeof o.id === "string" && o.id.length > 0 && o.id.length <= MAX_ID_LEN &&
    typeof o.nick === "string" && o.nick.length > 0 && o.nick.length <= MAX_NICK_LEN &&
    typeof o.avatar === "string" && o.avatar.length > 0 && o.avatar.length <= MAX_AVATAR_LEN
  );
}
