/// auth_controller.dart — ViewModel авторизации (MVVM, ViewModel).
///
/// За что отвечает файл:
///   Оборачивает Firebase Auth: отслеживает состояние входа
///   (`authStateChanges`), выполняет вход через Google и выход. Если Firebase не
///   инициализирован (нативная платформа без конфигурации, офлайн, headless-
///   тесты) — авторизация помечается недоступной и `FirebaseAuth` не трогается,
///   чтобы ничего не падало. Без BuildContext.
///
/// Соответствие TS: `src/ui/auth/auth.ts` (observeAuthUser/signInWithGoogle/
/// signOut).
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Минимальные данные вошедшего пользователя.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AuthUser.fromUser(User u) => AuthUser(
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoUrl: u.photoURL,
  );
}

/// Состояние авторизации.
class AuthState {
  /// Доступна ли авторизация (Firebase инициализирован).
  final bool available;

  /// Вошедший пользователь или null.
  final AuthUser? user;

  /// Идёт ли операция входа/выхода.
  final bool busy;

  /// Текст последней ошибки.
  final String? error;

  const AuthState({
    this.available = false,
    this.user,
    this.busy = false,
    this.error,
  });

  /// Вошёл ли пользователь.
  bool get signedIn => user != null;

  AuthState copyWith({
    bool? available,
    AuthUser? user,
    bool clearUser = false,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => AuthState(
    available: available ?? this.available,
    user: clearUser ? null : (user ?? this.user),
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

/// ViewModel авторизации.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<User?>? _sub;

  @override
  AuthState build() {
    // Firebase не поднят (нативная платформа без конфигурации / тесты) —
    // авторизация недоступна, FirebaseAuth не трогаем.
    if (Firebase.apps.isEmpty) return const AuthState(available: false);

    final auth = FirebaseAuth.instance;
    _sub = auth.authStateChanges().listen((user) {
      state = state.copyWith(
        user: user == null ? null : AuthUser.fromUser(user),
        clearUser: user == null,
        busy: false,
        clearError: true,
      );
    });
    ref.onDispose(() => _sub?.cancel());
    final current = auth.currentUser;
    return AuthState(
      available: true,
      user: current == null ? null : AuthUser.fromUser(current),
    );
  }

  /// Вход через Google. Web — popup; нативные платформы (macOS/iOS/Android) —
  /// через `google_sign_in` → Firebase-credential по OpenID ID-token.
  Future<void> signInWithGoogle() async {
    if (!state.available) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        await _signInWithGoogleNative();
      }
      // authStateChanges обновит user и снимет busy.
    } on GoogleSignInException catch (e) {
      // Пользователь закрыл диалог — не показываем как ошибку.
      final canceled = e.code == GoogleSignInExceptionCode.canceled;
      state = state.copyWith(busy: false, error: canceled ? null : _humanError(e));
    } catch (e) {
      state = state.copyWith(busy: false, error: _humanError(e));
    }
  }

  /// Нативный вход: получает ID-token у Google и меняет его на сессию Firebase.
  /// clientId/URL-схема берутся из платформенной конфигурации (на macOS/iOS —
  /// `GIDClientID` + `CFBundleURLTypes` в Info.plist; см. MACOS_AUTH_SETUP.md).
  Future<void> _signInWithGoogleNative() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw UnsupportedError('Google sign-in не поддержан на этой платформе');
    }
    if (!_googleSignInInitialized) {
      await google.initialize();
      _googleSignInInitialized = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google не вернул idToken');
    }
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Инициализация `GoogleSignIn` идемпотентна — флаг защищает от повторной.
  static bool _googleSignInInitialized = false;

  /// Выход из аккаунта (на нативных платформах — и из Google-сессии).
  Future<void> signOut() async {
    if (!state.available) return;
    try {
      if (!kIsWeb && _googleSignInInitialized) {
        await GoogleSignIn.instance.signOut();
      }
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // игнорируем — состояние обновит authStateChanges
    }
  }

  String _humanError(Object e) {
    if (e is FirebaseAuthException) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return 'вход отменён';
      }
      return e.message ?? e.code;
    }
    return 'ошибка входа';
  }
}

/// Провайдер ViewModel авторизации.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
