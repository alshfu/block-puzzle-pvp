/// composite_score.dart — сводный рейтинг игрока по режимам (pure, Model-слой).
///
/// За что отвечает файл:
///   Чистая формула «композитного» рейтинга из ROADMAP § 5.6:
///   `floor(0.4·E_general + 0.6·avg(E_modes))` — взвешивает общий ELO и средний
///   ELO по отдельным режимам. Утилита готова к использованию, когда появятся
///   серверные per-mode ELO-ladders (Memory Duel, Co-op online и т.д.); сами
///   ladder-эндпоинты — серверная (инфра) надстройка, см. ROADMAP § 5.6.
///
/// Чистота: без UI/IO/случайности — детерминированная функция входов.
library;

/// Вес общего рейтинга в композитной формуле.
const double compositeGeneralWeight = 0.4;

/// Вес среднего по режимам в композитной формуле.
const double compositeModesWeight = 0.6;

/// Считает сводный рейтинг: `floor(0.4·general + 0.6·avg(modes))`.
///
/// Если [modeElos] пуст — режимных данных ещё нет, возвращается [generalElo]
/// (композит вырождается в общий рейтинг).
int compositeScore(int generalElo, List<int> modeElos) {
  if (modeElos.isEmpty) return generalElo;
  final sum = modeElos.fold<int>(0, (a, b) => a + b);
  final avgModes = sum / modeElos.length;
  return (compositeGeneralWeight * generalElo + compositeModesWeight * avgModes)
      .floor();
}
