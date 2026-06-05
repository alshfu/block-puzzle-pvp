/// main.dart — точка входа Flutter-приложения BlockDuel 9×9 (Dart-порт).
///
/// За что отвечает файл:
///   Запускает приложение: оборачивает корневой [BlockDuelApp] в Riverpod
///   `ProviderScope` (корень DI для всех ViewModel) и отдаёт его в [runApp].
///   Минимальный bootstrap — вся логика во View/ViewModel/Model слоях.
///
/// Соответствие TS: `src/main.tsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Запускает приложение под корневым `ProviderScope` (MVVM DI-корень).
void main() {
  runApp(const ProviderScope(child: BlockDuelApp()));
}
