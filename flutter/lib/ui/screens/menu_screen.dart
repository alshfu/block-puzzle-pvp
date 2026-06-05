/// menu_screen.dart — главное меню (View).
///
/// За что отвечает файл:
///   Стартовый экран: профиль/монеты/иконки сверху, hero с логотипом и
///   декором, кнопка «Играть» → список режимов, переключатель тем, футер.
///   Чистый View (MVVM): локальное UI-состояние (раскрыт ли список режимов)
///   держит сам, тему читает из [ThemeController], навигацию делегирует
///   go_router. Бизнес-логики игры здесь нет.
///
/// Соответствие TS: `screens/MenuScreen.tsx`. Профиль/монеты пока статичны —
/// их ViewModel появится в Фазе 4.
library;

import 'package:block_duel/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/profile_controller.dart';
import '../design_tokens.dart';
import '../responsive.dart';
import '../widgets/logo.dart';
import '../widgets/mini_piece.dart';
import '../widgets/theme_switch.dart';

/// Режимы игры (как TS `GameMode`).
enum GameMode { bot, hotseat, arcade, tutorial, botvbot, online }

/// Главное меню игры.
class MenuScreen extends ConsumerStatefulWidget {
  /// Создаёт экран меню.
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  /// Раскрыт ли список режимов (локальное состояние View).
  bool _modeOpen = false;

  /// Навигация к игре выбранного режима.
  void _start(GameMode mode) => context.go('/game/${mode.name}');

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.bg, tokens.bg2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    const _TopBar(),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Logo(),
                          const SizedBox(height: 12),
                          Text(
                            'дуэль на поле 9×9 · ставь, очищай, побеждай',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: clampVw(
                                context,
                                min: 12,
                                prefVw: 3.4,
                                max: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _MiniDeco(),
                        ],
                      ),
                    ),
                    _Actions(
                      tokens: tokens,
                      modeOpen: _modeOpen,
                      onOpenModes: () => setState(() => _modeOpen = true),
                      onBack: () => setState(() => _modeOpen = false),
                      onStart: _start,
                    ),
                    const SizedBox(height: 16),
                    const ThemeSwitch(),
                    const SizedBox(height: 12),
                    Text(
                      'v2.0 · flutter migration',
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Верхняя панель: профиль (заглушка), монеты, иконки дейли/настроек.
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<BlockDuelTheme>()!;
    final profile = ref.watch(profileControllerProvider);
    return Row(
      children: [
        _Chip(
          tokens: tokens,
          onTap: () => context.go('/profile'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile.avatar, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.nick,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'ур. ${profile.level}',
                    style: TextStyle(color: tokens.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        _Chip(
          tokens: tokens,
          onTap: () => context.go('/profile'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '${profile.coins}',
                style: TextStyle(
                  color: tokens.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _IconChip(
          tokens: tokens,
          emoji: '🏆',
          onTap: () => context.go('/achievements'),
        ),
        const SizedBox(width: 8),
        _IconChip(
          tokens: tokens,
          emoji: '⚙',
          onTap: () => context.go('/settings'),
        ),
      ],
    );
  }
}

/// Декоративный ряд из нескольких мини-фигур под слоганом.
class _MiniDeco extends StatelessWidget {
  const _MiniDeco();

  @override
  Widget build(BuildContext context) {
    const demo = [
      PieceType.t,
      PieceType.l,
      PieceType.s,
      PieceType.o,
      PieceType.i,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < demo.length; i++) ...[
          MiniPiece(cells: baseShapes[demo[i]]!, owner: i % 2, cellSize: 13),
          if (i != demo.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// Блок действий: кнопка «Играть» или раскрытый список режимов.
class _Actions extends StatelessWidget {
  final BlockDuelTheme tokens;
  final bool modeOpen;
  final VoidCallback onOpenModes;
  final VoidCallback onBack;
  final void Function(GameMode) onStart;

  const _Actions({
    required this.tokens,
    required this.modeOpen,
    required this.onOpenModes,
    required this.onBack,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (!modeOpen) {
      return _HeroButton(tokens: tokens, label: '▶ Играть', onTap: onOpenModes);
    }
    return Column(
      children: [
        _ModeButton(
          tokens: tokens,
          icon: '🤖',
          title: 'С ботом',
          sub: 'быстрая партия против ИИ',
          primary: true,
          onTap: () => onStart(GameMode.bot),
        ),
        _ModeButton(
          tokens: tokens,
          icon: '👥',
          title: 'Вдвоём',
          sub: 'hot-seat на одном устройстве',
          onTap: () => onStart(GameMode.hotseat),
        ),
        _ModeButton(
          tokens: tokens,
          icon: '🎯',
          title: 'Аркада',
          sub: 'один на доске — на рекорд',
          onTap: () => onStart(GameMode.arcade),
        ),
        _ModeButton(
          tokens: tokens,
          icon: '🎬',
          title: 'Бот × бот',
          sub: 'смотри как ИИ играет с ИИ',
          onTap: () => onStart(GameMode.botvbot),
        ),
        TextButton(
          onPressed: onBack,
          child: Text('← назад', style: TextStyle(color: tokens.muted)),
        ),
      ],
    );
  }
}

/// Большая основная кнопка (hero).
class _HeroButton extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String label;
  final VoidCallback onTap;

  const _HeroButton({
    required this.tokens,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: tokens.p0,
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.btnRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.kind == Brightness.dark
                      ? const Color(0xFF0B0E13)
                      : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: tokens.fontDisplay,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кнопка одного режима в раскрытом списке.
class _ModeButton extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String icon;
  final String title;
  final String sub;
  final bool primary;
  final VoidCallback onTap;

  const _ModeButton({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: primary ? tokens.p0.withValues(alpha: 0.16) : tokens.panel,
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.btnRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.btnRadius),
              border: Border.all(color: tokens.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Контейнер-«чип» с фоном панели и скруглением темы (кликабельный).
class _Chip extends StatelessWidget {
  final BlockDuelTheme tokens;
  final Widget child;
  final VoidCallback? onTap;

  const _Chip({required this.tokens, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.panel,
      borderRadius: BorderRadius.circular(tokens.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.btnRadius),
            border: Border.all(color: tokens.line),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Квадратный чип-иконка (кликабельный).
class _IconChip extends StatelessWidget {
  final BlockDuelTheme tokens;
  final String emoji;
  final VoidCallback? onTap;

  const _IconChip({required this.tokens, required this.emoji, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.panel,
      borderRadius: BorderRadius.circular(tokens.btnRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.btnRadius),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.btnRadius),
            border: Border.all(color: tokens.line),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
