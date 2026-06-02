/**
 * Низкоуровневые DOM-эмиттеры для UI-пилота.
 *
 * Все действия — настоящие PointerEvent-ы, как от руки/мыши. Никакого setSel
 * или sendMove напрямую: пилот должен ходить ТОЛЬКО через те же события,
 * которые получает обычный игрок.
 */

const POINTER_ID = 9999;

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

/** Ждёт пока элемент по селектору не появится. Поллит каждые 50мс. */
export async function findEl<T extends Element = Element>(
  selector: string,
  timeoutMs = 5000,
): Promise<T | null> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const el = document.querySelector<T>(selector);
    if (el) return el;
    await sleep(50);
  }
  return null;
}

interface FireOptions {
  x: number;
  y: number;
  pointerId?: number;
  pointerType?: "mouse" | "touch" | "pen";
  button?: number;
}

function makeEvent(type: string, opt: FireOptions): PointerEvent {
  return new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    composed: true,
    clientX: opt.x,
    clientY: opt.y,
    screenX: opt.x,
    screenY: opt.y,
    pointerId: opt.pointerId ?? POINTER_ID,
    pointerType: opt.pointerType ?? "mouse",
    button: opt.button ?? 0,
    buttons: type === "pointerup" ? 0 : 1,
    isPrimary: true,
  });
}

/** Эмитит PointerEvent с pointermove/pointerup проксированы на window (как в OnlineGameScreen). */
export function fireOn(target: EventTarget, type: string, opt: FireOptions): void {
  target.dispatchEvent(makeEvent(type, opt));
}

/** Координаты центра элемента в viewport. */
export function center(el: Element): { x: number; y: number } {
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

/** Простой tap (pointerdown → pointerup без движения). Триггерит onPieceTap. */
export async function tap(el: Element): Promise<void> {
  const p = center(el);
  fireOn(el, "pointerdown", p);
  await sleep(40);
  // ВАЖНО: pointerup на самом slot'е, не на window. Hand.tsx слушает
  // React onPointerUp на элементе — events на window НЕ bubble обратно в DOM.
  fireOn(el, "pointerup", p);
  await sleep(80);
}

/** Обычный клик (для .tc-btn "Повернуть"/"Отразить"). */
export async function clickEl(el: Element): Promise<void> {
  const p = center(el);
  fireOn(el, "pointerdown", p);
  fireOn(el, "pointerup", p);
  el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, clientX: p.x, clientY: p.y }));
  await sleep(80);
}

/**
 * Drag: pointerdown на source → серия pointermove → pointerup над target.
 * Двигаемся по диагонали с шагом, гарантированно проходящим DRAG_THRESHOLD_PX=6.
 * move/up — на window, потому что useEffect в Game/OnlineGameScreen слушает window.
 */
export async function drag(source: Element, target: Element, steps = 10): Promise<void> {
  const a = center(source);
  const b = center(target);
  fireOn(source, "pointerdown", a);
  await sleep(60); // дать React зарегистрировать drag state
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const x = a.x + (b.x - a.x) * t;
    const y = a.y + (b.y - a.y) * t;
    fireOn(window, "pointermove", { x, y });
    await sleep(20);
  }
  // финальный move прямо над целью (для lastHoverRef)
  fireOn(window, "pointermove", b);
  await sleep(30);
  fireOn(window, "pointerup", b);
  await sleep(60);
}

/** Возвращает rect для конкретной клетки board, или null. */
export function boardCellRect(r: number, c: number): DOMRect | null {
  const cells = document.querySelectorAll<HTMLElement>(".board .cell");
  const idx = r * 9 + c;
  const el = cells[idx];
  return el?.getBoundingClientRect() ?? null;
}

/** Слот в нижней руке (наш владелец) по pieceId — ищем через children порядок. */
export function findMyHandSlot(handIndex: number): HTMLElement | null {
  // Активная рука — последний `.hand` в DOM (внизу), tone="play" даёт класс `.hand.play`.
  const myHands = document.querySelectorAll<HTMLElement>(".hand.play");
  const myHand = myHands[myHands.length - 1];
  if (!myHand) return null;
  const slots = myHand.querySelectorAll<HTMLElement>(".hand-slot");
  return slots[handIndex] ?? null;
}

export function findRotateBtn(): HTMLElement | null {
  return document.querySelector<HTMLElement>(".transform-controls .tc-btn:nth-child(1)");
}

export function findFlipBtn(): HTMLElement | null {
  return document.querySelector<HTMLElement>(".transform-controls .tc-btn:nth-child(2)");
}
