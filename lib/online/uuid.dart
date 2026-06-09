/// uuid.dart — генерация UUID v4 без внешнего пакета (Model-утилита).
///
/// За что отвечает файл:
///   Возвращает случайный UUID v4 строкой `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
///   на основе `Random.secure()`. Нужен для стабильного id игрока в онлайне
///   (генерится один раз и сохраняется в профиле).
library;

import 'dart:math';

/// Генерирует случайный UUID v4.
String newUuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  // Версия (4) и вариант (10xx) по RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) {
    final sb = StringBuffer();
    for (int i = start; i < end; i++) {
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
