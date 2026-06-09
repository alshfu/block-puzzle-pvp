/// ts_import_stub.dart — заглушка импорта TS-данных для не-web платформ.
///
/// На native/desktop переносить localStorage неоткуда — функция ничего не делает.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// No-op: миграция из localStorage актуальна только для web.
Future<void> importLegacyTsData(SharedPreferences prefs) async {}
