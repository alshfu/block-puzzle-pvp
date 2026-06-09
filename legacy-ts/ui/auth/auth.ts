import { googleSignIn, googleSignOut, hasPriorSession, observeUser, type User } from "./firebase";

export interface AuthUser {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
}

function toAuthUser(u: User | null): AuthUser | null {
  if (!u) return null;
  return {
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoURL: u.photoURL,
  };
}

export function observeAuthUser(cb: (user: AuthUser | null) => void): () => void {
  // Гостевой режим: если на устройстве никогда не логинились — не трогаем
  // Firebase SDK. Lazy-load случится только после явного клика "Войти".
  if (!hasPriorSession()) {
    cb(null);
    return () => {};
  }
  return observeUser((u) => cb(toAuthUser(u)));
}

export async function signInWithGoogle(): Promise<AuthUser | null> {
  return toAuthUser(await googleSignIn());
}

export async function signOut(): Promise<void> {
  await googleSignOut();
}
