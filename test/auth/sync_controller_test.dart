/// sync_controller_test.dart — тесты кросс-девайс синхронизации прогресса.
///
/// Стало возможным после рефактора: доступ к Firestore вынесен за [CloudRepo]
/// ([cloudRepoProvider]), а auth-состояние переопределяется фейк-контроллером —
/// поэтому реактивный флоу (вход → pull → merge → push) юнит-тестируется без
/// Firebase. Раньше SyncController напрямую держал `FirebaseFirestore.instance`.
library;

import 'package:block_duel/auth/auth_controller.dart';
import 'package:block_duel/auth/cloud_repo.dart';
import 'package:block_duel/auth/cloud_snapshot.dart';
import 'package:block_duel/auth/sync_controller.dart';
import 'package:block_duel/profile/profile.dart';
import 'package:block_duel/profile/profile_controller.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фейковый облачный репозиторий: держит один документ в памяти.
class FakeCloudRepo implements CloudRepo {
  FakeCloudRepo({this.availableFlag = true, Map<String, dynamic>? seed})
      : stored = seed;

  final bool availableFlag;
  Map<String, dynamic>? stored;
  int saveCount = 0;
  int fetchCount = 0;

  @override
  bool get available => availableFlag;

  @override
  Future<Map<String, dynamic>?> fetch(String uid) async {
    fetchCount++;
    return stored;
  }

  @override
  Future<void> save(String uid, Map<String, dynamic> data) async {
    stored = data;
    saveCount++;
  }
}

/// Фейк-auth без Firebase: доступен, управляемый вход/выход.
class FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(available: true);

  void signIn(String uid) =>
      state = AuthState(available: true, user: AuthUser(uid: uid));

  void signOutTest() => state = const AuthState(available: true);
}

Future<ProviderContainer> _container(FakeCloudRepo repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      cloudRepoProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith(FakeAuthController.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('облако недоступно → статус disabled', () async {
    final c = await _container(FakeCloudRepo(availableFlag: false));
    expect(c.read(syncControllerProvider), SyncStatus.disabled);
  });

  test('доступно, не вошёл → idle, облако не трогается', () async {
    final repo = FakeCloudRepo();
    final c = await _container(repo);
    expect(c.read(syncControllerProvider), SyncStatus.idle);
    expect(repo.fetchCount, 0);
  });

  test('вход: тянет облако, сливает профиль (max-wins) и пишет обратно', () async {
    final cloud = CloudSnapshot(
      profile: Profile.initial.copyWith(xp: 500, coins: 99, id: 'cloud-id'),
      updatedAt: 1,
    );
    final repo = FakeCloudRepo(seed: cloud.toJson());
    final c = await _container(repo);
    expect(c.read(syncControllerProvider), SyncStatus.idle);
    expect(c.read(profileControllerProvider).xp, 0); // локально пусто

    (c.read(authControllerProvider.notifier) as FakeAuthController).signIn('u1');
    await Future<void>.delayed(Duration.zero); // дать _pullAndSeed отработать

    expect(repo.fetchCount, 1); // тянули облако
    expect(c.read(profileControllerProvider).xp, 500); // слит облачный xp
    expect(c.read(profileControllerProvider).coins, 99);
    expect(repo.saveCount, greaterThan(0)); // и записали обратно
    expect(c.read(syncControllerProvider), SyncStatus.synced);
  });

  test('вход при пустом облаке → заливает локальное (seed)', () async {
    final repo = FakeCloudRepo(); // документа нет
    final c = await _container(repo);
    c.read(syncControllerProvider); // активируем listener'ы sync
    (c.read(authControllerProvider.notifier) as FakeAuthController).signIn('u2');
    await Future<void>.delayed(Duration.zero);
    expect(repo.saveCount, greaterThan(0)); // локальное залито в облако
    expect(repo.stored, isNotNull);
  });
}
