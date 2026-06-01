# BlockDuel 9×9

Соревновательный блок-пазл: два игрока по очереди ставят тетромино (I, O, T, S, Z, J, L) на общую доску 9×9. Заполненная строка / столбец / бокс 3×3 очищается, очки достаются игроку, чей ход вызвал очистку. Партия идёт до тупика; blitz-таймер + force-place гарантируют сходимость.

Полная спецификация: `TZ_BlockDuel_9x9.md` (RU, v1.0) — **источник истины** по правилам, балансу и фазам.

## Текущий статус

Фаза 1 (MVP). Этап «Фундамент» закрыт; следующий — игровой UI.

- `src/core/index.ts` — pure-ядро игры (TS): типы, PRNG mulberry32, 7-bag, доска, очистка, очки, перебор ходов, бот 3 уровней, blitz-таймер (`turnTimeForRound`), `forcePlace`. **Единственный** источник правды по логике.
- `src/main.tsx` + `src/ui/App.tsx` — точка входа React. Сейчас экран-заглушка.
- `tests/` — Vitest. 41 тест: очистки/пересечения, очки/комбо/perfect, 7-bag, тупик/forcePlace, бот, детерминизм, таймер.
- `legacy/` — старые прототипы (`blockduel-demo.html`, `blockduel-jsx-prototype/`). **Не подключены к сборке**, оставлены как референс по визуальным решениям. См. `legacy/README.md`.
- `vite.config.ts`, `vitest.config.ts`, `tsconfig.{app,node}.json` — конфиги.

## Команды

```bash
npm run dev         # Vite dev server на http://localhost:5173
npm run build       # tsc -b && vite build → dist/
npm test            # Vitest (one-shot)
npm run test:watch  # Vitest watch
npm run typecheck   # tsc -b --noEmit
```

## Архитектура

Жёсткое разделение слоёв (ТЗ § 6.1):

```
Презентация (UI, ввод, анимации)              ← src/ui/
    ↓
Игровое ядро (pure, детерминированное)         ← src/core/
    ↓
Платформенные сервисы / Сетевой слой           ← (нет на MVP)
```

**Ядро (`src/core/`) обязано оставаться pure и детерминированным:**
- никаких `Math.random()` — только переданный `rng: () => number` от `makeRng(seed)`;
- никакого `Date.now()`, `fetch`, `localStorage`, DOM, импортов UI-фреймворков;
- одинаковый `(matchSeed, RuleConfig, moveLog)` → одинаковое состояние (нужно для реплеев, server-authoritative онлайна, golden-тестов, анти-чита).

Презентационный код (drag-and-drop, анимации, звук, тикание таймера) — только в `src/ui/`.

## Конвенции

- Идентификаторы и комментарии в коде — английский (`BoardCell`, `enumerateMoves`, `RuleConfig`).
- Документация и общение с пользователем — русский; технические термины можно оставлять английскими.
- Дефолты конфига зафиксированы в `DEFAULT_CONFIG` (`src/core/index.ts`) и в ТЗ § 15 — должны совпадать.
- Формула очков: `base = N*(N+1)/2`, `mult = 1 + 0.1·min(combo, comboCap)`, `+15` за perfect clear.
- 7-bag: у каждого игрока свой мешок (`sharedBag = false`).
- Blitz: `turnTimeStart=12`, `turnTimeDecay=0.4`, `turnTimeMin=3`, `onTimeout="forcePlace"`.

## Стек

ТЗ рекомендует **Flutter + Flame** как целевой стек. Текущая реализация — **TypeScript + React + Vite + Vitest**. Не предлагай миграцию на Flutter без явного запроса.

## Чего НЕ делать самостоятельно

- Не дублировать игровую логику в `src/ui/` — всё через импорт из `src/core/`.
- Не править файлы в `legacy/` — они инертные.
- Не вводить онлайн / магазин / ачивки — это Фазы 3–4, не текущий MVP.
- Не отходить от ТЗ по правилам/балансу без явного запроса.
