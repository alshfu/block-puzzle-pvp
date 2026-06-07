/// toast_stack.dart — стопка тостов о достижениях (View, декоративный слой).
///
/// За что отвечает файл:
///   Порт `src/ui/components/ToastStack.tsx` (+ `@keyframes toastIn/toastOut`).
///   Показывает сверху всплывашки о вновь разблокированных ачивках: каждая
///   въезжает сверху, висит ~4с и уезжает обратно; тап убирает раньше. Родитель
///   держит список и через [onDismiss] выкидывает завершившиеся.
///
/// Соответствие TS: `components/ToastStack.tsx`, правила `.toast*`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../achievements/achievement.dart';
import '../design_tokens.dart';

/// Стопка тостов, выровненная по верхнему краю.
class ToastStack extends StatelessWidget {
  /// Текущие тосты (вновь разблокированные ачивки).
  final List<Achievement> toasts;

  /// Токены темы.
  final BlockDuelTheme theme;

  /// Убрать тост с данным id (по таймауту или тапу).
  final void Function(String id) onDismiss;

  /// Создаёт стопку тостов.
  const ToastStack({
    super.key,
    required this.toasts,
    required this.theme,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in toasts)
                _ToastItem(
                  key: ValueKey(a.id),
                  achievement: a,
                  theme: theme,
                  onDismiss: () => onDismiss(a.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Один тост: въезд сверху, авто-уезд через 4с, тап — убрать раньше.
class _ToastItem extends StatefulWidget {
  final Achievement achievement;
  final BlockDuelTheme theme;
  final VoidCallback onDismiss;

  const _ToastItem({
    super.key,
    required this.achievement,
    required this.theme,
    required this.onDismiss,
  });

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _autoHide = Timer(const Duration(milliseconds: 4000), _hide);
  }

  Future<void> _hide() async {
    _autoHide?.cancel();
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final a = widget.achievement;
    final slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: _c,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: _hide,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.panel,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.p0, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ачивка: ${a.title}',
                          style: TextStyle(
                            color: t.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.description,
                          style: TextStyle(
                            color: t.muted,
                            fontSize: 10.5,
                            fontFamily: t.fontMono,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
