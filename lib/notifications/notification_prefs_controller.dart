/// notification_prefs_controller.dart — ViewModel opt-in уведомлений (§ 11.2).
///
/// За что отвечает файл:
///   Загружает/хранит [NotificationPrefs] в SharedPreferences и отдаёт команды
///   переключения мастер-тумблера и категорий. Чистый Riverpod-`Notifier`. Сама
///   доставка (FCM/APNs + серверный endpoint) — отдельная серверная часть (🔒);
///   здесь только пользовательский opt-in, который её будет гейтить.
///
/// Соответствие ROADMAP: § 11.2.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import 'notification_prefs.dart';

/// ViewModel предпочтений уведомлений.
class NotificationPrefsController extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(
          PrefKeys.notifications,
        );
    if (raw == null) return NotificationPrefs.initial;
    try {
      return NotificationPrefs.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return NotificationPrefs.initial;
    }
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).setString(
          PrefKeys.notifications,
          jsonEncode(state.toJson()),
        );
  }

  /// Переключает мастер-тумблер.
  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _persist();
  }

  /// Переключает категорию [kind].
  void toggle(NotificationKind kind) {
    state = state.toggled(kind);
    _persist();
  }
}

/// Провайдер ViewModel предпочтений уведомлений.
final notificationPrefsControllerProvider =
    NotifierProvider<NotificationPrefsController, NotificationPrefs>(
  NotificationPrefsController.new,
);
