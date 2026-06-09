/// stats_screen_test.dart — тест экрана подробной статистики (Фаза 3b.3).
///
/// За что отвечает файл:
///   Проверяет, что [StatsScreen] рендерит секции и значения из засеянной
///   [Stats] (онлайн-сводка/серии/соперники/темы) и показывает подсказку при
///   отсутствии онлайн-матчей. reduceMotion:true — чтобы ThemeBackdrop не
///   запускал Ticker и pumpAndSettle сходился.
library;

import 'dart:convert';

import 'package:block_duel/achievements/achievement.dart';
import 'package:block_duel/storage/prefs.dart';
import 'package:block_duel/ui/design_tokens.dart';
import 'package:block_duel/ui/screens/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Stats stats) async {
  // Высокое окно — чтобы ленивый ListView отрисовал все секции сразу.
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'bd_settings': '{"soundOn":false,"musicOn":false,"reduceMotion":true}',
    PrefKeys.stats: jsonEncode(stats.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: ThemeData(extensions: [blockDuelThemes[ThemeId.neutral]!]),
        home: const StatsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('пустая статистика → подсказка и нули', (tester) async {
    await _pump(tester, const Stats());
    expect(find.textContaining('Сыграй онлайн-матч'), findsOneWidget);
    expect(find.text('Онлайн — сводка'), findsNothing); // секции без иконки нет
    expect(find.textContaining('Онлайн — сводка'), findsOneWidget);
  });

  testWidgets('секции и значения отрисованы', (tester) async {
    const stats = Stats(
      games: 10,
      wins: 6,
      onlineGames: 8,
      onlineWins: 5,
      onlineLosses: 2,
      onlineDraws: 1,
      onlineBestWinStreak: 4,
      onlineTotalPerfects: 3,
      onlineBestCombo: 7,
      onlineMaxMultiClear: 4,
      onlineUniqueOpponents: 5,
      onlineMostVsSingleOpponent: 3,
      onlineThemesPlayed: ['neutral', 'candy'],
      onlineConsecutiveDays: 2,
      onlineMaxConsecutiveDays: 5,
      onlineOpponents: {
        'abc123def': OnlineOpponentRecord(count: 3, wins: 2, lastResult: 'win'),
      },
    );
    await _pump(tester, stats);

    // Заголовки секций.
    expect(find.textContaining('Онлайн — сводка'), findsOneWidget);
    expect(find.textContaining('Онлайн — серии'), findsOneWidget);
    expect(find.textContaining('достижения в матчах'), findsOneWidget);
    expect(find.textContaining('Онлайн — соперники'), findsOneWidget);
    expect(find.textContaining('Частые соперники'), findsOneWidget);

    // Значения.
    expect(find.text('63%'), findsOneWidget); // онлайн-винрейт round(5*100/8)
    expect(find.text('×7'), findsOneWidget); // лучшее комбо
    expect(find.textContaining('Карамель'), findsOneWidget); // тема в списке
    // Подсказки нет при наличии матчей.
    expect(find.textContaining('Сыграй онлайн-матч'), findsNothing);
  });
}
