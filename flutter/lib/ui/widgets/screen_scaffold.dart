/// screen_scaffold.dart — каркас вторичного экрана (View).
///
/// За что отвечает файл:
///   Общая обёртка для экранов профиля/настроек/и т.п.: фон темы, безопасная
///   зона, ограничение ширины, шапка с кнопкой «назад» и заголовком, прокрутка
///   содержимого. Убирает дублирование вёрстки между экранами.
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Каркас вторичного экрана с шапкой и прокручиваемым телом.
class ScreenScaffold extends StatelessWidget {
  /// Заголовок в шапке.
  final String title;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Обработчик кнопки «назад».
  final VoidCallback onBack;

  /// Содержимое (прокручиваемая колонка).
  final List<Widget> children;

  /// Создаёт каркас экрана.
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.theme,
    required this.onBack,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: Icon(Icons.arrow_back, color: theme.ink),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFamily: theme.fontDisplay,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
