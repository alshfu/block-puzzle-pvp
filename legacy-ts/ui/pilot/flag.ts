/**
 * Глобальный флаг включения UI-пилота. Активируется через ?pilot=1 в URL
 * либо localStorage["bd_pilot"] === "1" (для дебага без редиректа).
 *
 * Вычисляется один раз при загрузке модуля — useEffect/state не нужны,
 * флаг неизменяем за жизнь сессии.
 */
function compute(): boolean {
  try {
    const params = new URLSearchParams(window.location.search);
    if (params.get("pilot") === "1") return true;
    if (localStorage.getItem("bd_pilot") === "1") return true;
    return false;
  } catch {
    return false;
  }
}

const enabled = compute();

export function isPilotEnabled(): boolean {
  return enabled;
}
