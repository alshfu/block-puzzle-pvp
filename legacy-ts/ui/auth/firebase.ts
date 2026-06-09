/**
 * Единственная точка lazy-загрузки Firebase. Все динамические импорты
 * собраны здесь — rollup получает ровно один dynamic boundary и собирает
 * Firebase SDK в один компактный chunk, не дублируя deps между файлами.
 */
import type { FirebaseApp } from "firebase/app";
import type { Auth, User } from "firebase/auth";
import type { Firestore } from "firebase/firestore";

interface FbConfig {
  apiKey: string;
  authDomain: string;
  projectId: string;
  appId: string;
  storageBucket?: string;
  messagingSenderId?: string;
}

function readConfig(): FbConfig | null {
  const env = import.meta.env;
  if (!env.VITE_FB_API_KEY || !env.VITE_FB_AUTH_DOMAIN || !env.VITE_FB_PROJECT_ID || !env.VITE_FB_APP_ID) {
    return null;
  }
  return {
    apiKey: env.VITE_FB_API_KEY,
    authDomain: env.VITE_FB_AUTH_DOMAIN,
    projectId: env.VITE_FB_PROJECT_ID,
    appId: env.VITE_FB_APP_ID,
    storageBucket: env.VITE_FB_STORAGE_BUCKET,
    messagingSenderId: env.VITE_FB_MESSAGING_SENDER_ID,
  };
}

interface FbBundle {
  app: FirebaseApp;
  auth: Auth;
  db: Firestore;
  // Firestore helpers (передаём вместе с db чтобы избежать повторных импортов)
  fs: typeof import("firebase/firestore");
  // Auth helpers
  ax: typeof import("firebase/auth");
}

let pending: Promise<FbBundle | null> | null = null;

function load(): Promise<FbBundle | null> {
  if (pending) return pending;
  const cfg = readConfig();
  if (!cfg) {
    pending = Promise.resolve(null);
    return pending;
  }
  pending = (async () => {
    const [appMod, authMod, fsMod] = await Promise.all([
      import("firebase/app"),
      import("firebase/auth"),
      import("firebase/firestore"),
    ]);
    const app = appMod.initializeApp(cfg);
    return {
      app,
      auth: authMod.getAuth(app),
      db: fsMod.getFirestore(app),
      fs: fsMod,
      ax: authMod,
    };
  })();
  return pending;
}

export function isAuthEnabled(): boolean {
  return readConfig() !== null;
}

export type { User };

/** Подписка на текущего пользователя. Сразу зовёт cb(null) до загрузки SDK. */
export function observeUser(cb: (u: User | null) => void): () => void {
  let cancelled = false;
  let unsub: (() => void) | null = null;
  cb(null);
  void load().then((b) => {
    if (cancelled || !b) return;
    unsub = b.ax.onAuthStateChanged(b.auth, cb);
  });
  return () => {
    cancelled = true;
    if (unsub) unsub();
  };
}

const SIGNED_IN_FLAG = "bd_auth_signed_in";

/** true, если пользователь хотя бы раз залогинился на этом устройстве. */
export function hasPriorSession(): boolean {
  try {
    return localStorage.getItem(SIGNED_IN_FLAG) === "1";
  } catch {
    return false;
  }
}

function setPriorSession(on: boolean): void {
  try {
    if (on) localStorage.setItem(SIGNED_IN_FLAG, "1");
    else localStorage.removeItem(SIGNED_IN_FLAG);
  } catch {
    /* ignore */
  }
}

export async function googleSignIn(): Promise<User | null> {
  const b = await load();
  if (!b) return null;
  const cred = await b.ax.signInWithPopup(b.auth, new b.ax.GoogleAuthProvider());
  setPriorSession(true);
  return cred.user;
}

export async function googleSignOut(): Promise<void> {
  setPriorSession(false);
  const b = await load();
  if (!b) return;
  await b.ax.signOut(b.auth);
}

export async function fsGetDoc<T>(path: [string, string]): Promise<T | null> {
  const b = await load();
  if (!b) return null;
  const ref = b.fs.doc(b.db, path[0], path[1]);
  const snap = await b.fs.getDoc(ref);
  return snap.exists() ? (snap.data() as T) : null;
}

export async function fsSetDoc(path: [string, string], data: Record<string, unknown>): Promise<void> {
  const b = await load();
  if (!b) return;
  const ref = b.fs.doc(b.db, path[0], path[1]);
  await b.fs.setDoc(ref, data, { merge: true });
}
