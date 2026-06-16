/// composite_score_test.dart — тесты сводного рейтинга (ROADMAP § 5.6).
library;

import 'package:block_duel/modes/ladder/composite_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('нет режимных данных → возвращается общий рейтинг', () {
    expect(compositeScore(1200, const []), 1200);
  });

  test('формула floor(0.4·general + 0.6·avg(modes))', () {
    // general=1000, modes avg=1500 → 0.4*1000 + 0.6*1500 = 400 + 900 = 1300.
    expect(compositeScore(1000, const [1500]), 1300);
    // modes avg = (1400+1600)/2 = 1500 → тот же 1300.
    expect(compositeScore(1000, const [1400, 1600]), 1300);
  });

  test('округление вниз', () {
    // general=1001, modes=[1001] → 1001.0 → 1001.
    expect(compositeScore(1001, const [1001]), 1001);
    // general=1000, modes=[1001] → 400 + 600.6 = 1000.6 → floor 1000.
    expect(compositeScore(1000, const [1001]), 1000);
  });

  test('монотонность по режимному рейтингу', () {
    expect(
      compositeScore(1000, const [1200]),
      lessThan(compositeScore(1000, const [1800])),
    );
  });
}
