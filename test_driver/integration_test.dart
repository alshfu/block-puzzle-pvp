// test_driver/integration_test.dart — driver-обёртка для запуска
// integration_test в браузере через `flutter drive` (нужен запущенный
// chromedriver на :4444). Создано для web-прогона pilot на Chrome.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
