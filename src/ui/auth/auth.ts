import {
  GoogleAuthProvider,
  signInWithPopup,
  signOut as fbSignOut,
  onAuthStateChanged,
  type User,
} from "firebase/auth";
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
  const auth = getAuthOrNull();
  if (!auth) {
    cb(null);
    return () => {};
  }
  return onAuthStateChanged(auth, (u) => cb(toAuthUser(u)));
}

export async function signInWithGoogle(): Promise<AuthUser | null> {
  const auth = getAuthOrNull();
  if (!auth) return null;
  const provider = new GoogleAuthProvider();
  const cred = await signInWithPopup(auth, provider);
  return toAuthUser(cred.user);
}

export async function signOut(): Promise<void> {
  const auth = getAuthOrNull();
  if (!auth) return;
  await fbSignOut(auth);
}
