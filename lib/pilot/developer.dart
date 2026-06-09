/// developer.dart — гейт «режима разработчика» для скрытого pilot (ViewModel).
///
/// За что отвечает файл:
///   Решает, доступен ли скрытый авто-игрок (pilot). Включается двумя путями:
///   (1) вход через аккаунт из вайтлиста разработчиков (по e-mail), либо
///   (2) локальный флаг-override (`bd_pilot`) — для платформ без Google-входа
///   (например macOS-десктоп), активируется секретным жестом в меню.
///
/// Соответствие TS: `src/ui/pilot/flag.ts` (`?pilot=1` / localStorage).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../storage/prefs.dart';

/// E-mail аккаунтов-разработчиков, которым доступен pilot.
const Set<String> developerEmails = {'alshfu@gmail.com'};

/// ViewModel доступности режима разработчика (pilot).
class DeveloperController extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getString(PrefKeys.pilotDev) == '1') return true;
    final auth = ref.watch(authControllerProvider);
    return auth.signedIn &&
        auth.user?.email != null &&
        developerEmails.contains(auth.user!.email);
  }

  /// Включает режим разработчика локально (секретный жест) — работает без входа.
  void enableViaSecret() {
    ref.read(sharedPreferencesProvider).setString(PrefKeys.pilotDev, '1');
    ref.invalidateSelf();
  }

  /// Выключает локальный override режима разработчика.
  void disable() {
    ref.read(sharedPreferencesProvider).remove(PrefKeys.pilotDev);
    ref.invalidateSelf();
  }
}

/// Провайдер доступности режима разработчика (pilot).
final isDeveloperProvider = NotifierProvider<DeveloperController, bool>(
  DeveloperController.new,
);
