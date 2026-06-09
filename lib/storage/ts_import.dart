/// ts_import.dart — one-shot импорт прогресса из TS-версии (Фаза 8 cut-over).
///
/// За что отвечает файл:
///   Единая точка входа миграции: при первом запуске Flutter-web переносит
///   локальные данные старой TS/React-версии (ключи `bd_*` в `localStorage`) в
///   Flutter-хранилище, чтобы локальные (несинканные через Firebase) профили не
///   потерялись при переключении прода. На не-web платформах — no-op.
///
///   Реализация выбирается условным экспортом: web читает `window.localStorage`
///   (`ts_import_web.dart`), остальные платформы — заглушка (`ts_import_stub.dart`).
library;

export 'ts_import_stub.dart' if (dart.library.html) 'ts_import_web.dart';
