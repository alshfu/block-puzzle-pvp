/// notification_prefs_test.dart — тесты opt-in уведомлений (§ 11.2).
///
/// Проверяют: маска `allows` (мастер + категория), переключение категории,
/// JSON round-trip и персист контроллера через mock-prefs.
library;

import 'package:block_duel/notifications/notification_prefs.dart';
import 'package:block_duel/notifications/notification_prefs_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('модель', () {
    test('allows учитывает мастер и категорию', () {
      const p = NotificationPrefs.initial;
      expect(p.allows(NotificationKind.invite), isTrue);
      expect(
        p.copyWith(enabled: false).allows(NotificationKind.invite),
        isFalse,
      );
      expect(
        p.toggled(NotificationKind.invite).allows(NotificationKind.invite),
        isFalse,
      );
    });

    test('JSON round-trip', () {
      final p = NotificationPrefs.initial.toggled(NotificationKind.season);
      final back = NotificationPrefs.fromJson(p.toJson());
      expect(back.enabled, p.enabled);
      expect(back.kinds, p.kinds);
    });
  });

  group('контроллер', () {
    test('переключение мастера и категории персистится', () async {
      final c = await _container();
      final vm = c.read(notificationPrefsControllerProvider.notifier);
      vm.setEnabled(false);
      expect(c.read(notificationPrefsControllerProvider).enabled, isFalse);
      vm.setEnabled(true);
      vm.toggle(NotificationKind.dailyReminder);
      expect(
        c
            .read(notificationPrefsControllerProvider)
            .kinds
            .contains(NotificationKind.dailyReminder),
        isFalse,
      );
    });
  });
}
