/// stats_screen.dart — экран подробной статистики (View, Фаза 3b.3).
///
/// За что отвечает файл:
///   Показывает «богатую» статистику игрока, которую копит [StatsController]:
///   сводку онлайна (партии/винрейт), серии (победы/без поражений/дни подряд),
///   достижения в матчах (очистки/perfect/комбо/мульти/длина матча), счётчики
///   соперников и сыгранные темы, плюс краткую офлайн-сводку. Чистый View:
///   только читает [statsControllerProvider], логики нет.
///
/// Соответствие TS: расширенная часть `screens/ProfileScreen.tsx` + поля
/// `Stats` из `src/ui/storage/stats.ts`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../achievements/achievement.dart';
import '../../achievements/stats_controller.dart';
import '../design_tokens.dart';
import '../widgets/screen_scaffold.dart';

/// Названия тем для отображения в списке сыгранных.
const Map<String, String> _themeTitles = {
  'neutral': 'Нейтральная',
  'candy': 'Карамель',
  'night': 'Ночь',
};

/// Экран подробной статистики.
class StatsScreen extends ConsumerWidget {
  /// Создаёт экран статистики.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<BlockDuelTheme>()!;
    final s = ref.watch(statsControllerProvider);

    final onlineWinrate = s.onlineGames == 0
        ? 0
        : (s.onlineWins * 100 / s.onlineGames).round();
    final offlineWinrate = s.games == 0
        ? 0
        : (s.wins * 100 / s.games).round();

    final themes = s.onlineThemesPlayed
        .map((t) => _themeTitles[t] ?? t)
        .join(', ');

    return ScreenScaffold(
      title: 'Статистика',
      theme: theme,
      onBack: () => context.go('/profile'),
      children: [
        if (s.onlineGames == 0)
          _Hint(
            theme: theme,
            text:
                'Сыграй онлайн-матч, чтобы здесь появилась статистика PvP и '
                'начали открываться соответствующие достижения.',
          ),
        _Section(
          theme: theme,
          icon: '🌐',
          title: 'Онлайн — сводка',
          rows: [
            ('Матчей сыграно', '${s.onlineGames}'),
            ('Побед', '${s.onlineWins}'),
            ('Поражений', '${s.onlineLosses}'),
            ('Ничьих', '${s.onlineDraws}'),
            ('Винрейт', '$onlineWinrate%'),
          ],
        ),
        _Section(
          theme: theme,
          icon: '🔥',
          title: 'Онлайн — серии',
          rows: [
            ('Текущая серия побед', '${s.onlineCurrentWinStreak}'),
            ('Лучшая серия побед', '${s.onlineBestWinStreak}'),
            ('Серия без поражений', '${s.onlineCurrentNoLossStreak}'),
            ('Лучшая без поражений', '${s.onlineBestNoLossStreak}'),
            ('Дней подряд', '${s.onlineConsecutiveDays}'),
            ('Макс. дней подряд', '${s.onlineMaxConsecutiveDays}'),
            ('Серия реваншей', '${s.onlineMaxRematchWinStreak}'),
          ],
        ),
        _Section(
          theme: theme,
          icon: '🏆',
          title: 'Онлайн — достижения в матчах',
          rows: [
            ('Очищено линий/боксов', '${s.onlineTotalClears}'),
            ('Perfect-очисток', '${s.onlineTotalPerfects}'),
            ('Лучшее комбо', '×${s.onlineBestCombo}'),
            ('Лучшая мульти-очистка', '×${s.onlineMaxMultiClear}'),
            ('Самый долгий матч', '${s.onlineLongestMatchTurns} ходов'),
          ],
        ),
        _Section(
          theme: theme,
          icon: '🤝',
          title: 'Онлайн — соперники',
          rows: [
            ('Уникальных соперников', '${s.onlineUniqueOpponents}'),
            ('Больше всего матчей с одним', '${s.onlineMostVsSingleOpponent}'),
            ('Тем сыграно', '${s.onlineThemesPlayed.length} / 3'),
            if (themes.isNotEmpty) ('Темы', themes),
          ],
        ),
        _Section(
          theme: theme,
          icon: '🎮',
          title: 'Офлайн — сводка',
          rows: [
            ('Партий', '${s.games}'),
            ('Побед', '${s.wins}'),
            ('Винрейт', '$offlineWinrate%'),
            ('Рекорд за партию', '${s.bestScore}'),
            ('Лучшая мульти-очистка', '×${s.maxMultiClear}'),
            ('Очищено линий/боксов', '${s.totalClears}'),
            ('Лучшая серия побед', '${s.bestWinStreak}'),
          ],
        ),
        if (s.onlineOpponents.isNotEmpty)
          _TopOpponents(theme: theme, opponents: s.onlineOpponents),
      ],
    );
  }
}

/// Подсказка-плашка (когда статистики ещё нет).
class _Hint extends StatelessWidget {
  final BlockDuelTheme theme;
  final String text;

  const _Hint({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.panel2,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.line),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.muted, fontSize: 13, height: 1.35),
      ),
    );
  }
}

/// Секция статистики: заголовок + панель строк «метка → значение».
class _Section extends StatelessWidget {
  final BlockDuelTheme theme;
  final String icon;
  final String title;
  final List<(String, String)> rows;

  const _Section({
    required this.theme,
    required this.icon,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '$icon  $title',
              style: TextStyle(
                color: theme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.panel,
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(color: theme.line),
            ),
            child: Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            r.$1,
                            style: TextStyle(color: theme.muted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            r.$2,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: theme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Топ соперников по числу сыгранных матчей (ник недоступен — показываем
/// короткий префикс id; полные ники соперников пока не сохраняются).
class _TopOpponents extends StatelessWidget {
  final BlockDuelTheme theme;
  final Map<String, OnlineOpponentRecord> opponents;

  const _TopOpponents({required this.theme, required this.opponents});

  @override
  Widget build(BuildContext context) {
    final top = opponents.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    final rows = <(String, String)>[
      for (final e in top.take(5))
        (
          'Соперник ${e.key.length > 6 ? e.key.substring(0, 6) : e.key}',
          '${e.value.count} матч., ${e.value.wins} поб.',
        ),
    ];
    return _Section(
      theme: theme,
      icon: '⚔️',
      title: 'Частые соперники',
      rows: rows,
    );
  }
}
