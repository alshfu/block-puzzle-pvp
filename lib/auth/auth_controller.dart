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

  /// Вход через Google (web — popup; нативные платформы — позже).
  Future<void> signInWithGoogle() async {
    if (!state.available) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        // Нативный Google sign-in (google_sign_in) добавим вместе с
        // конфигурацией платформ; пока недоступно.
        throw UnsupportedError('вход доступен только в web-сборке');
      }
      // authStateChanges обновит user и снимет busy.
    } catch (e) {
      state = state.copyWith(busy: false, error: _humanError(e));
    }
  }

  /// Выход из аккаунта.
  Future<void> signOut() async {
    if (!state.available) return;
    try {
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
