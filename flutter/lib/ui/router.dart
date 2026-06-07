/// router.dart — конфигурация навигации go_router (View-слой).
///
/// За что отвечает файл:
///   Объявляет маршруты приложения и связывает их с экранами 1:1. Сейчас:
///   `/` → меню, `/game/:mode` → заглушка игрового экрана. По мере Фаз 2–7
///   сюда добавляются профиль, настройки, магазин, ачивки, онлайн и т.д.
///
/// Соответствие TS: роутинг экранов из `App.tsx`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../online/online_models.dart';
import '../profile/profile_controller.dart';
import 'screens/achievements_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/game_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/online/online_game_screen.dart';
import 'screens/online/online_menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

/// Глобальный роутер приложения.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
    GoRoute(
      path: '/game/:mode',
      builder: (context, state) {
        final resume = state.uri.queryParameters['resume'] == '1';
        final seedStr = state.uri.queryParameters['seed'];
        final resumeSeed = resume ? int.tryParse(seedStr ?? '') : null;
        return GameScreen(
          modeRaw: state.pathParameters['mode'] ?? 'bot',
          resumeSeed: resumeSeed,
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),
    GoRoute(path: '/daily', builder: (context, state) => const DailyScreen()),
    GoRoute(
      path: '/online',
      builder: (context, state) => const OnlineMenuScreen(),
    ),
    GoRoute(
      path: '/online/game/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        final extra = state.extra;
        if (extra is OnlineGameArgs) {
          return OnlineGameScreen(
            roomId: roomId,
            me: extra.me,
            opponent: extra.opponent,
          );
        }
        // Фолбэк (deep-link / hot-reload без extra): профиль из провайдера,
        // соперник-заглушка (реальные имена придут в `joined`).
        return Consumer(
          builder: (context, ref, _) => OnlineGameScreen(
            roomId: roomId,
            me: OnlineProfile.fromProfile(ref.read(profileControllerProvider)),
            opponent: const OnlineProfile(
              id: '',
              nick: 'Соперник',
              avatar: '👤',
            ),
          ),
        );
      },
    ),
  ],
);
