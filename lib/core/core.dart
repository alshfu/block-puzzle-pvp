/// core.dart — публичный барель игрового ядра BlockDuel 9×9 (Dart-порт).
///
/// За что отвечает файл:
///   Единая точка импорта ядра для остального приложения и тестов:
///   `import 'package:block_duel/core/core.dart';`. Реэкспортирует все
///   подмодули ядра. Само ядро — pure и детерминированное (ТЗ §6.1): без UI,
///   IO, DateTime.now() и неуправляемой случайности.
///
/// Состав (соответствие `src/core/index.ts`):
///   types   — типы и конфигурация правил (defaultConfig).
///   rng     — детерминированный PRNG mulberry32.
///   pieces  — формы тетромино и ориентации.
///   board   — доска, постановка, очистка.
///   bag     — генератор фигур 7-bag.
///   scoring — система очков v1.5+.
///   moves   — перебор ходов и эвристики.
///   bot     — ИИ-бот трёх уровней.
///   timer   — blitz-таймер и force-place.
library;

export 'bag.dart';
export 'board.dart';
export 'bot.dart';
export 'moves.dart';
export 'pieces.dart';
export 'rng.dart';
export 'scoring.dart';
export 'timer.dart';
export 'types.dart';
