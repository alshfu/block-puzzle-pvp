/// sync_controller.dart — синхронизация прогресса с Firestore (ViewModel/сервис).
///
/// За что отвечает файл:
///   При входе пользователя тянет документ `users/{uid}`, сливает его с
///   локальным состоянием ([mergeProfiles] + объединение ачивок + настройки из
///   облака) и пишет результат обратно; при последующих изменениях профиля/
///   ачивок/настроек делает debounced-push. Если Firebase не поднят или юзер не
///   вошёл — ничего не делает. Единственное место с `cloud_firestore`.
///
/// Активируется чтением [syncControllerProvider] в `app.dart` (как music).
///
/// Соответствие TS: `src/ui/auth/sync.ts` (pullCloud/pushCloud) + интеграция в
/// `App.tsx`.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../achievements/achievements_controller.dart';
import '../profile/profile_controller.dart';
import '../settings/settings_controller.dart';
import 'auth_controller.dart';
import 'cloud_snapshot.dart';

/// Статус синхронизации (для возможной индикации в UI).
enum SyncStatus { disabled, idle, syncing, synced, error }

/// Задержка debounced-push после изменения локального состояния.
const Duration _pushDebounce = Duration(milliseconds: 1500);

/// ViewModel синхронизации прогресса.
class SyncController extends Notifier<SyncStatus> {
  Timer? _pushTimer;
  bool _pulling = false;

  @override
  SyncStatus build() {
    if (Firebase.apps.isEmpty) return SyncStatus.disabled;

    ref.onDispose(() => _pushTimer?.cancel());

    // Реакция на вход/выход.
    ref.listen(authControllerProvider, (prev, next) {
      final wasIn = prev?.signedIn ?? false;
      if (next.signedIn && !wasIn) {
        _pullAndSeed(next.user!.uid);
      } else if (!next.signedIn) {
        _pushTimer?.cancel();
      }
    });

    // Изменения локального состояния → debounced push (если вошли).
    ref.listen(profileControllerProvider, (_, _) => _onLocalChange());
    ref.listen(achievementsControllerProvider, (_, _) => _onLocalChange());
    ref.listen(settingsControllerProvider, (_, _) => _onLocalChange());

    return SyncStatus.idle;
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// Тянет облако и сливает с локальным; если документа нет — заливает локальное.
  Future<void> _pullAndSeed(String uid) async {
    _pulling = true;
    state = SyncStatus.syncing;
    try {
      final doc = await _doc(uid).get();
      final data = doc.data();
      if (data != null) {
        final cloud = CloudSnapshot.fromJson(data);
        final localProfile = ref.read(profileControllerProvider);
        if (cloud.profile != null) {
          ref
              .read(profileControllerProvider.notifier)
              .replace(mergeProfiles(localProfile, cloud.profile!));
        }
        ref
            .read(achievementsControllerProvider.notifier)
            .mergeUnlocked(cloud.achievements);
        if (cloud.settings != null) {
          ref
              .read(settingsControllerProvider.notifier)
              .replace(cloud.settings!);
        }
      }
      await _push(uid);
      state = SyncStatus.synced;
    } catch (_) {
      state = SyncStatus.error;
    } finally {
      _pulling = false;
    }
  }

  void _onLocalChange() {
    if (_pulling) return; // изменения от самого pull не гоняем обратно сразу
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDebounce, () => _push(user.uid));
  }

  /// Пишет текущее локальное состояние в облако (merge).
  Future<void> _push(String uid) async {
    try {
      final snap = CloudSnapshot(
        profile: ref.read(profileControllerProvider),
        achievements: ref.read(achievementsControllerProvider),
        settings: ref.read(settingsControllerProvider),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _doc(uid).set(snap.toJson(), SetOptions(merge: true));
      if (state != SyncStatus.syncing) state = SyncStatus.synced;
    } catch (_) {
      state = SyncStatus.error;
    }
  }
}

/// Провайдер синхронизации прогресса (активируется чтением в `app.dart`).
final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
