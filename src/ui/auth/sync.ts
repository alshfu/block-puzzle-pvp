/**
 * Cloud-sync прогресса в Firestore. Структура: одна запись на пользователя,
 * `users/{uid}` со всеми разделами прогресса. Pull при логине, push debounced
 * при изменениях.
 */
import { doc, getDoc, setDoc, type Firestore } from "firebase/firestore";
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

function userDoc(db: Firestore, uid: string) {
  return doc(db, "users", uid);
}

export async function pullCloud(uid: string): Promise<CloudSnapshot | null> {
  const db = getDbOrNull();
  if (!db) return null;
  const snap = await getDoc(userDoc(db, uid));
  if (!snap.exists()) return null;
  return snap.data() as CloudSnapshot;
}

export async function pushCloud(uid: string, snap: CloudSnapshot): Promise<void> {
  const db = getDbOrNull();
  if (!db) return;
  await setDoc(
    userDoc(db, uid),
    { ...snap, updatedAt: Date.now() },
    { merge: true },
  );
}
