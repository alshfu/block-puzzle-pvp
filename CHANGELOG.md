# Changelog

История значимых релизов BlockDuel 9×9. Формат — обратный хронологический.

## 1.5.0 — 2026-06-03

Mobile UX и тестирование.

- **Mobile-fit без скролла.** Game-screen теперь помещается в 100dvh даже
  при одновременно открытых URL-bar и toolbar мобильного браузера. Board
  остаётся родным квадратом (max-width 420 / 600 / 680), сжимается
  только обвязка.
- **Inline рука соперника.** Мини-фигуры соперника сидят прямо в его
  pcard (карточке со счётом) — отдельная watch-полоса убрана,
  экономия ~50px.
- **Pre-select.** Игрок может выбрать и повернуть фигуру до того, как
  ему разрешат ходить. Финальный place всё равно отвергается, пока
  не наша очередь.
- **Status-bar убран** — состояние («ходишь / ход соперника / отвалился»)
  переехало в заголовок своей руки.
- **bot×bot без лишней обвязки.** TransformControls и PowerupsPanel
  скрыты в наблюдательном режиме.
- **E2E mobile audit.** `tools/e2e-mobile.ts` — Playwright headless
  Chromium прогоняет 20 viewport-ов флагманов iPhone и Galaxy S
  (2015–2024) × 3 chrome-overhead режима (full / urlbar / urlbar+toolbar).
  Дамп метрик: viewport / board / gameOverflow.
- **UI Pilot.** `?pilot=1` — внешний робот-водитель, симулирует игрока
  через настоящие PointerEvent-ы на DOM. Лениво подгружается через
  dynamic import, в обычной сборке не попадает в initial bundle.
  Журналирует каждое действие.
- **Сетевые правила.** `OnlineMenuScreen` показывает выбор handSize /
  rotation / flip перед quick-play. Сервер принимает `cfg` от первого
  подключившегося клиента и пересоздаёт руки под нужный handSize.
- **Tetris-режим (handSize=1).** Доступен в offline; в онлайне передаётся
  через расширенный hello-протокол.
- Множество фиксов ориентации фигур: первый tap не крутит, drag
  сохраняет повёрнутую ориентацию, нормализация cells в Hand.

## 1.0.0 — 2026-06-01

Первый публичный релиз.

- Core: ядро игры — 9×9 board, 7-bag, scoring (триангулярный + combo +
  perfect), бот 3 уровней (easy/medium/hard), blitz-таймер.
- UI: vs Bot, hot-seat, arcade, bot×bot. Темы neutral/candy/night.
  Звук, музыка, vibration.
- Прогрессия: XP, daily quests, ~120 ачивок, магазин (power-ups + скины
  ячеек), валюта = кристаллы.
- Онлайн PvP: собственный Node WS-сервер на VPS pvp.alshfu.com,
  server-authoritative match, ELO-лидерборд K=24.
- Auth + sync: Google sign-in через Firebase + Firestore cross-device.
- Live на GitHub Pages: https://alshfu.github.io/block-puzzle-pvp/
