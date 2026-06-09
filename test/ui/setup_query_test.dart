/// setup_query_test.dart — тесты кодирования/декодирования конфига матча.
///
/// SetupScreen кодирует выбор в query, роутер декодирует обратно — проверяем
/// round-trip уровня бота и правил (включая пресет блица и handSize).
library;

import 'package:block_duel/core/core.dart';
import 'package:block_duel/ui/screens/setup_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Извлекает query-параметры из пути `/game/...?a=b&c=d`.
Map<String, String> _query(String route) => Uri.parse(route).queryParameters;

void main() {
  test('gameRoute → query → botLevel/cfg round-trip', () {
    final route = gameRoute(
      mode: 'bot',
      bot: BotLevel.hard,
      rotation: false,
      flip: true,
      handSize: 2,
      blitz: true,
      blitzPreset: 'hardcore',
    );
    expect(route, startsWith('/game/bot?'));
    final q = _query(route);

    expect(botLevelFromParams(q), BotLevel.hard);
    final cfg = ruleConfigFromParams(q)!;
    expect(cfg.rotationEnabled, isFalse);
    expect(cfg.flipEnabled, isTrue);
    expect(cfg.handSize, 2);
    expect(cfg.turnTimerEnabled, isTrue);
    expect(cfg.turnTimeStart, 8); // hardcore
    expect(cfg.turnTimeMin, 2);
  });

  test('блиц выключен → turnTimerEnabled=false', () {
    final route = gameRoute(
      mode: 'hotseat',
      bot: BotLevel.medium,
      rotation: true,
      flip: true,
      handSize: 3,
      blitz: false,
      blitzPreset: 'normal',
    );
    final cfg = ruleConfigFromParams(_query(route))!;
    expect(cfg.turnTimerEnabled, isFalse);
  });

  test('без параметров конфига → null (зовущий берёт дефолт)', () {
    expect(ruleConfigFromParams(const {}), isNull);
    expect(botLevelFromParams(const {}), BotLevel.medium);
  });

  test('казуал-пресет → 20/6', () {
    final route = gameRoute(
      mode: 'bot',
      bot: BotLevel.easy,
      rotation: true,
      flip: false,
      handSize: 1,
      blitz: true,
      blitzPreset: 'casual',
    );
    final cfg = ruleConfigFromParams(_query(route))!;
    expect(cfg.turnTimeStart, 20);
    expect(cfg.turnTimeMin, 6);
    expect(cfg.handSize, 1);
    expect(botLevelFromParams(_query(route)), BotLevel.easy);
  });
}
