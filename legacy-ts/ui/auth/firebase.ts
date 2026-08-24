/**
 * СТАБ. Firebase JS SDK удалён из legacy-ts (2026-08-23).
 *
 * Почему: npm-пакет `firebase` тянул уязвимые транзитивные зависимости
 * (websocket-driver — critical, protobufjs — moderate) и использовался ТОЛЬКО
 * этим ретайрнутым TS-фронтом (legacy-ts/ui). Прод — Flutter Web с нативным
 * Dart-Firebase (проект blockduel-web), он этим кодом не пользуется; сервер
 * импортирует только legacy-ts/core. Веб-auth легаси-фронта и так был no-op без
 * gitignored `VITE_FB_*`-переменных, поэтому его понижение до постоянного
 * гостевого режима поведение rollback-сборки не меняет.
 *
 * Модуль сохраняет ту же публичную сигнатуру (её ждут auth/auth.ts, auth/sync.ts,
 * SettingsScreen.tsx), но НЕ импортирует `firebase/*` — все функции no-op.
 * Чтобы вернуть auth в легаси-фронт: `npm i firebase` и восстановить реализацию
 * из истории git (коммит до удаления).
 */

/** Минимальный тип пользователя (совместим с прежним `firebase/auth` User). */
export interface User {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
}

/** Auth в легаси-фронте отключён (Firebase SDK удалён). Всегда false. */
export function isAuthEnabled(): boolean {
  return false;
}

/** Подписка на пользователя: сразу отдаёт null, отписка — no-op. */
export function observeUser(cb: (u: User | null) => void): () => void {
  cb(null);
  return () => {};
}

/** Прежних сессий нет — SDK не грузится. */
export function hasPriorSession(): boolean {
  return false;
}

/** Вход отключён. */
export async function googleSignIn(): Promise<User | null> {
  return null;
}

/** Выход — no-op. */
export async function googleSignOut(): Promise<void> {
  /* auth отключён */
}

/** Чтение документа Firestore отключено. */
export async function fsGetDoc<T>(_path: [string, string]): Promise<T | null> {
  return null;
}

/** Запись документа Firestore отключена. */
export async function fsSetDoc(
  _path: [string, string],
  _data: Record<string, unknown>,
): Promise<void> {
  /* Firestore отключён */
}
