import type { User } from "firebase/auth";
import { getAuthOrNull } from "./firebase";

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
  let cancelled = false;
  let unsub: (() => void) | null = null;
  cb(null);
  void (async () => {
    const [{ onAuthStateChanged }, auth] = await Promise.all([
      import("firebase/auth"),
      getAuthOrNull(),
    ]);
    if (cancelled || !auth) return;
    unsub = onAuthStateChanged(auth, (u) => cb(toAuthUser(u)));
  })();
  return () => {
    cancelled = true;
    if (unsub) unsub();
  };
}

export async function signInWithGoogle(): Promise<AuthUser | null> {
  const [{ GoogleAuthProvider, signInWithPopup }, auth] = await Promise.all([
    import("firebase/auth"),
    getAuthOrNull(),
  ]);
  if (!auth) return null;
  const cred = await signInWithPopup(auth, new GoogleAuthProvider());
  return toAuthUser(cred.user);
}

export async function signOut(): Promise<void> {
  const [{ signOut: fbSignOut }, auth] = await Promise.all([
    import("firebase/auth"),
    getAuthOrNull(),
  ]);
  if (!auth) return;
  await fbSignOut(auth);
}
