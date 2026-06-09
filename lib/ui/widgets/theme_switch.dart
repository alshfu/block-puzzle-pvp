/// theme_switch.dart — переключатель темы (View).
///
/// За что отвечает файл:
///   Ряд из трёх чипов (neutral/candy/night). Тап выбирает тему — команда уходит
///   в ViewModel [ThemeController]. Чистый View: читает текущую тему из
///   провайдера, рисует, пробрасывает намерение; логики смены здесь нет.
///
/// Соответствие TS: `components/ThemeSwitch.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_tokens.dart';
import '../theme/theme_controller.dart';

/// Компактный переключатель из трёх тем-чипов.
class ThemeSwitch extends ConsumerWidget {
  /// Создаёт переключатель темы.
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;

    return Wrap(
      spacing: 8,
      children: [
        for (final id in themeOrder)
          _ThemeChip(
            theme: blockDuelThemes[id]!,
            selected: id == current,
            ink: tokens.ink,
            line: tokens.line,
            onTap: () => ref.read(themeControllerProvider.notifier).select(id),
          ),
      ],
    );
  }
}

/// Один чип темы: образец палитры + название, подсветка выбранного.
class _ThemeChip extends StatelessWidget {
  final BlockDuelTheme theme;
  final bool selected;
  final Color ink;
  final Color line;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.ink,
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: Border.all(
            color: selected ? theme.p0 : line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(theme.p0),
            const SizedBox(width: 3),
            _dot(theme.p1),
            const SizedBox(width: 8),
            Text(
              theme.label,
              style: TextStyle(
                color: theme.ink,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
