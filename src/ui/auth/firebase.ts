/**
 * Ленивая инициализация Firebase. SDK подгружается через dynamic import
 * только при первом обращении к `getAuthOrNull()` / `getDbOrNull()` —
 * это вырезает ~100 KB gzip из initial bundle для гостевой загрузки.
 */
import type { FirebaseApp } from "firebase/app";
import type { Auth } from "firebase/auth";
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

interface FbHandles {
  app: FirebaseApp;
  auth: Auth;
  db: Firestore;
}

let pending: Promise<FbHandles | null> | null = null;

function loadFirebase(): Promise<FbHandles | null> {
  if (pending) return pending;
  const cfg = readConfig();
  if (!cfg) {
    pending = Promise.resolve(null);
    return pending;
  }
  pending = (async () => {
    const [{ initializeApp }, { getAuth }, { getFirestore }] = await Promise.all([
      import("firebase/app"),
      import("firebase/auth"),
      import("firebase/firestore"),
    ]);
    const app = initializeApp(cfg);
    return { app, auth: getAuth(app), db: getFirestore(app) };
  })();
  return pending;
}

export function isAuthEnabled(): boolean {
  return readConfig() !== null;
}

export async function getAuthOrNull(): Promise<Auth | null> {
  const h = await loadFirebase();
  return h?.auth ?? null;
}

export async function getDbOrNull(): Promise<Firestore | null> {
  const h = await loadFirebase();
  return h?.db ?? null;
}
