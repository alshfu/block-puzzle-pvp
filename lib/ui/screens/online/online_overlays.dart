/// online_overlays.dart — оверлеи онлайн-матча (View, презентация).
///
/// За что отвечает файл:
///   Презентационные оверлеи поверх живого матча: баннер «соперник отключился»
///   с отсчётом, и финальный оверлей с результатом, ELO-заметкой и панелью
///   ремача. Логики нет — только колбэки наружу.
///
/// Соответствие TS: оверлеи из `screens/OnlineGame.tsx` (opponent-left,
/// result + rematch).
library;

import 'package:flutter/material.dart';

import '../../../online/online_models.dart';
import '../../decor/mascot.dart';
import '../../design_tokens.dart';

/// Баннер «соперник отключился» сверху экрана.
class OpponentLeftBanner extends StatelessWidget {
  final BlockDuelTheme theme;
  final int? timeoutMs;

  const OpponentLeftBanner({
    super.key,
    required this.theme,
    required this.timeoutMs,
  });

  @override
  Widget build(BuildContext context) {
    final secs = timeoutMs == null ? null : (timeoutMs! / 1000).round();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.panel,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.bad),
          ),
          child: Text(
            secs == null
                ? 'Соперник отключился, ждём…'
                : 'Соперник отключился, ждём $secs с…',
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontFamily: theme.fontMono,
            ),
          ),
        ),
      ),
    );
  }
}

/// Финальный оверлей онлайн-матча: результат + ELO-заметка + ремач + меню.
class OnlineGameOverOverlay extends StatelessWidget {
  final BlockDuelTheme theme;
  final ThemeId themeId;
  final OnlineResult result;
  final int you;
  final bool rematchYours;
  final bool rematchTheirs;
  final VoidCallback onToggleRematch;
  final VoidCallback onMenu;

  const OnlineGameOverOverlay({
    super.key,
    required this.theme,
    required this.themeId,
    required this.result,
    required this.you,
    required this.rematchYours,
    required this.rematchTheirs,
    required this.onToggleRematch,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final draw = result.winner < 0;
    final won = !draw && result.winner == you;
    final title = draw ? 'Ничья' : (won ? 'Победа!' : 'Поражение');

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.panel,
            borderRadius: BorderRadius.circular(theme.cardRadius),
            border: Border.all(color: theme.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(themeId: themeId, size: 96),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: theme.fontDisplay,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'счёт ${result.scores[0]} : ${result.scores[1]}',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 15,
                  fontFamily: theme.fontMono,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'рейтинг обновлён',
                style: TextStyle(color: theme.muted, fontSize: 11),
              ),
              const SizedBox(height: 20),
              if (rematchTheirs && !rematchYours)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Соперник хочет реванш',
                    style: TextStyle(color: theme.good, fontSize: 12),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Btn(
                    theme: theme,
                    label: rematchYours ? '⏳ ждём…' : '↺ реванш',
                    primary: !rematchYours,
                    onTap: onToggleRematch,
                  ),
                  const SizedBox(width: 12),
                  _Btn(theme: theme, label: '← меню', onTap: onMenu),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка оверлея (основная/призрак).
class _Btn extends StatelessWidget {
  final BlockDuelTheme theme;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _Btn({
    required this.theme,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: primary ? theme.p0 : Colors.transparent,
    borderRadius: BorderRadius.circular(theme.btnRadius),
    child: InkWell(
      borderRadius: BorderRadius.circular(theme.btnRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.btnRadius),
          border: primary ? null : Border.all(color: theme.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary ? theme.bg : theme.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
