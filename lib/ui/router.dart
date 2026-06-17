/// router.dart — конфигурация навигации go_router (View-слой).
///
/// За что отвечает файл:
///   Объявляет маршруты приложения и связывает их с экранами 1:1. Сейчас:
///   `/` → меню, `/game/:mode` → заглушка игрового экрана. По мере Фаз 2–7
///   сюда добавляются профиль, настройки, магазин, ачивки, онлайн и т.д.
///
/// Соответствие TS: роутинг экранов из `App.tsx`.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../online/online_models.dart';
import '../profile/profile_controller.dart';
import 'screens/achievements_screen.dart';
import 'screens/coop_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/game_screen.dart';
import 'screens/match3_screen.dart';
import 'screens/memory_duel_screen.dart';
import 'screens/memory_solo_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/online/leaderboard_screen.dart';
import 'screens/online/online_game_screen.dart';
import 'screens/online/online_menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/tutorial_screen.dart';

/// Страница с плавным fade-through переходом (для экранов новых режимов
/// Фазы 5): затухание + лёгкий подъём — премиальное ощущение навигации.
CustomTransitionPage<void> _fadeThroughPage(Widget child) =>
    CustomTransitionPage<void>(
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Глобальный роутер приложения.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
    GoRoute(
      path: '/setup/:mode',
      builder: (context, state) =>
          SetupScreen(modeRaw: state.pathParameters['mode'] ?? 'bot'),
    ),
    GoRoute(
      path: '/game/:mode',
      builder: (context, state) {
        final q = state.uri.queryParameters;
        final resume = q['resume'] == '1';
        final resumeSeed = resume ? int.tryParse(q['seed'] ?? '') : null;
        return GameScreen(
          modeRaw: state.pathParameters['mode'] ?? 'bot',
          resumeSeed: resumeSeed,
          botLevel: resume ? null : botLevelFromParams(q),
          cfg: resume ? null : ruleConfigFromParams(q),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),
    GoRoute(
      path: '/memory',
      pageBuilder: (context, state) => _fadeThroughPage(const MemorySoloScreen()),
    ),
    GoRoute(
      path: '/coop',
      pageBuilder: (context, state) => _fadeThroughPage(const CoopScreen()),
    ),
    GoRoute(
      path: '/memory-duel',
      pageBuilder: (context, state) => _fadeThroughPage(const MemoryDuelScreen()),
    ),
    GoRoute(
      path: '/match3',
      pageBuilder: (context, state) => _fadeThroughPage(const Match3Screen()),
    ),
    GoRoute(path: '/daily', builder: (context, state) => const DailyScreen()),
    GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
    GoRoute(
      path: '/tutorial',
      builder: (context, state) => const TutorialScreen(),
    ),
    GoRoute(
      path: '/online',
      builder: (context, state) => const OnlineMenuScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
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
            token: extra.token,
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
