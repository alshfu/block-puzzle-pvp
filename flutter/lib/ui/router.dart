/// router.dart — конфигурация навигации go_router (View-слой).
///
/// За что отвечает файл:
///   Объявляет маршруты приложения и связывает их с экранами 1:1. Сейчас:
///   `/` → меню, `/game/:mode` → заглушка игрового экрана. По мере Фаз 2–7
///   сюда добавляются профиль, настройки, магазин, ачивки, онлайн и т.д.
///
/// Соответствие TS: роутинг экранов из `App.tsx`.
library;

import 'package:go_router/go_router.dart';

import 'screens/game_screen.dart';
import 'screens/menu_screen.dart';

/// Глобальный роутер приложения.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
    GoRoute(
      path: '/game/:mode',
      builder: (context, state) =>
          GameScreen(modeRaw: state.pathParameters['mode'] ?? 'bot'),
    ),
  ],
);
