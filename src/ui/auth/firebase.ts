/**
 * Ленивая инициализация Firebase. Если переменные окружения не заданы —
 * `isAuthEnabled()` вернёт false и весь auth-блок UI прячется. Локальная
 * игра остаётся полностью рабочей без Firebase.
 */
import { initializeApp, type FirebaseApp } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";
import { getFirestore, type Firestore } from "firebase/firestore";

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

let app: FirebaseApp | null = null;
let auth: Auth | null = null;
let db: Firestore | null = null;

function init(): void {
  if (app !== null) return;
  const cfg = readConfig();
  if (!cfg) return;
  app = initializeApp(cfg);
  auth = getAuth(app);
  db = getFirestore(app);
}

export function isAuthEnabled(): boolean {
  return readConfig() !== null;
}

export function getAuthOrNull(): Auth | null {
  init();
  return auth;
}

export function getDbOrNull(): Firestore | null {
  init();
  return db;
}
