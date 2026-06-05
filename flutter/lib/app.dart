/// app.dart — корневой виджет приложения (View, связывает MVVM).
///
/// За что отвечает файл:
///   Строит `MaterialApp.router`: берёт текущую тему из ViewModel
///   [ThemeController], собирает `ThemeData` через [buildThemeData] и
///   подключает навигацию [appRouter]. Это «крыша» View-слоя — здесь сходятся
///   тема (ViewModel) и маршрутизация. Замена заглушки Фазы 0.
///
/// Соответствие TS: `src/ui/App.tsx` (провайдер темы + роутер).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/design_tokens.dart';
import 'ui/router.dart';
import 'ui/theme/theme_controller.dart';

/// Корневой виджет BlockDuel. Перестраивается при смене темы.
class BlockDuelApp extends ConsumerWidget {
  /// Создаёт корневой виджет приложения.
  const BlockDuelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(themeControllerProvider);
    final tokens = blockDuelThemes[themeId]!;
    return MaterialApp.router(
      title: 'BlockDuel 9×9',
      debugShowCheckedModeBanner: false,
      theme: buildThemeData(tokens),
      routerConfig: appRouter,
    );
  }
}
