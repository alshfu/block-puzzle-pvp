/**
 * Cloud-sync прогресса в Firestore. Структура: одна запись на пользователя,
 * `users/{uid}` со всеми разделами прогресса. Pull при логине, push debounced
 * при изменениях.
 */
import type { PlayerAchievements } from "../storage/achievements";
import type { DailyState } from "../storage/daily";
import type { Profile } from "../storage/profile";
import type { PlayerSkins } from "../storage/skins";
import type { Stats } from "../storage/stats";
import type { Wallet } from "../storage/wallet";
import { fsGetDoc, fsSetDoc } from "./firebase";

export interface CloudSnapshot {
  profile?: Profile;
  stats?: Stats;
  wallet?: Wallet;
  achievements?: PlayerAchievements;
  daily?: DailyState;
  skins?: PlayerSkins;
  updatedAt?: number;
}

export function pullCloud(uid: string): Promise<CloudSnapshot | null> {
  return fsGetDoc<CloudSnapshot>(["users", uid]);
}

export function pushCloud(uid: string, snap: CloudSnapshot): Promise<void> {
  return fsSetDoc(["users", uid], { ...snap, updatedAt: Date.now() });
}
