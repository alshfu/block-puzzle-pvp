/**
 * Cloud-sync прогресса в Firestore. Структура: одна запись на пользователя,
 * `users/{uid}` со всеми разделами прогресса. Pull при логине, push debounced
 * при изменениях.
 */
import type { Firestore } from "firebase/firestore";
import type { PlayerAchievements } from "../storage/achievements";
import type { DailyState } from "../storage/daily";
import type { Profile } from "../storage/profile";
import type { PlayerSkins } from "../storage/skins";
import type { Stats } from "../storage/stats";
import type { Wallet } from "../storage/wallet";
import { getDbOrNull } from "./firebase";

export interface CloudSnapshot {
  profile?: Profile;
  stats?: Stats;
  wallet?: Wallet;
  achievements?: PlayerAchievements;
  daily?: DailyState;
  skins?: PlayerSkins;
  updatedAt?: number;
}

export async function pullCloud(uid: string): Promise<CloudSnapshot | null> {
  const [{ doc, getDoc }, db] = await Promise.all([
    import("firebase/firestore"),
    getDbOrNull(),
  ]);
  if (!db) return null;
  const snap = await getDoc(userDoc(db, doc, uid));
  if (!snap.exists()) return null;
  return snap.data() as CloudSnapshot;
}

export async function pushCloud(uid: string, snap: CloudSnapshot): Promise<void> {
  const [{ doc, setDoc }, db] = await Promise.all([
    import("firebase/firestore"),
    getDbOrNull(),
  ]);
  if (!db) return;
  await setDoc(
    userDoc(db, doc, uid),
    { ...snap, updatedAt: Date.now() },
    { merge: true },
  );
}

function userDoc(db: Firestore, docFn: typeof import("firebase/firestore").doc, uid: string) {
  return docFn(db, "users", uid);
}
