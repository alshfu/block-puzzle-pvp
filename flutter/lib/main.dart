/// main.dart — точка входа Flutter-приложения BlockDuel 9×9 (Dart-порт).
///
/// За что отвечает файл:
///   Запускает приложение через [runApp]. На этапе скелета (Фаза 0) здесь
///   стоит временная заглушка [MigrationPlaceholderApp], подтверждающая, что
///   toolchain и сборка работают на всех платформах. В Фазе 2 эта заглушка
///   заменяется реальным корнем приложения (`app.dart` + go_router + темы),
///   соответствующим `src/main.tsx` из TS-версии.
///
/// Соответствие TS-версии:
///   `src/main.tsx` → этот файл (bootstrap) + будущий `lib/app.dart` (роутер).
library;

import 'package:flutter/material.dart';

/// Запускает приложение. Единственная задача — отдать корневой виджет Flutter.
void main() {
  runApp(const MigrationPlaceholderApp());
}

/// Временный корневой виджет на время Фазы 0 миграции.
///
/// Показывает статус «миграция в процессе». Заменяется на реальный
/// `BlockDuelApp` в Фазе 2 (UI shell + design tokens + go_router).
class MigrationPlaceholderApp extends StatelessWidget {
  /// Создаёт заглушку. `const`, чтобы Flutter не перестраивал её лишний раз.
  const MigrationPlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlockDuel 9×9',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _PlaceholderScreen(),
    );
  }
}

/// Экран-заглушка: название игры и пометка о стадии миграции.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BlockDuel 9×9',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text('Dart/Flutter migration — Phase 0 skeleton'),
          ],
        ),
      ),
    );
  }
}
