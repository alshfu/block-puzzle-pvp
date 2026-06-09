/// auth_controller_test.dart — тест guard-пути авторизации.
///
/// Без инициализированного Firebase (headless-тесты) AuthController должен
/// помечать авторизацию недоступной и НЕ трогать FirebaseAuth — приложение не
/// должно падать.
library;

import 'package:block_duel/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('без Firebase: available=false, не вошёл, не падает', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(authControllerProvider);
    expect(s.available, isFalse);
    expect(s.signedIn, isFalse);
    expect(s.user, isNull);
  });

  test('signIn/signOut на недоступной авторизации — no-op', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(authControllerProvider.notifier);
    await vm.signInWithGoogle();
    await vm.signOut();
    expect(c.read(authControllerProvider).available, isFalse);
  });
}
