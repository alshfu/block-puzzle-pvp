# BlockDuel 9×9

> Competitive block puzzle on a shared 9×9 grid. Two players take turns placing
> tetrominoes; complete rows, columns or 3×3 boxes clear instantly and score the
> mover. Tight matches, themed mascots, and a deterministic, replayable core.

**🎮 Play now:** <https://alshfu.github.io/block-puzzle-pvp/>

[![tests](https://img.shields.io/badge/tests-176%20passing-brightgreen)](#testing)
[![version](https://img.shields.io/badge/version-2.0.0-blue)](./CHANGELOG.md)
[![stack](https://img.shields.io/badge/stack-Dart%20%2B%20Flutter%20%2B%20Flame-0175C2)](#stack)

> **Migration note (2026-06-09).** The app was ported from TypeScript + React to
> **Dart + Flutter (+ Flame + Riverpod)** and the migration is **merged to
> `main`**. The Flutter project now lives at the **repo root** (`lib/`, `test/`,
> `web/`, `pubspec.yaml`, `android/ios/macos/`). The original TS/React front-end
> moved to **`legacy-ts/`** and is retired — but its **pure TS core
> (`legacy-ts/core`) is still live** as the dependency of the Node PvP server.
> Production cut-over (GitHub Pages: TS → Flutter Web) is pending; see
> [`DEPLOY.md`](./DEPLOY.md).

---

## Highlights

- **Hand-tuned bot**, three levels — calibrated through thousands of self-play
  games. The Dart core is bit-for-bit deterministic with the original TS core.
- **PvP online** — server-authoritative WebSocket backend (Node + `ws`) on a
  VPS (`pvp.alshfu.com`), quick-play matchmaking, ELO leaderboard (K=24).
- **Hot-seat** mode for two humans on one device, **Bot × bot** spectator mode,
  **Arcade** solo-for-score.
- **Three themes** (`neutral`, `candy`, `night`) with bespoke SVG mascots and
  synthesized chiptune loops per theme (no audio files).
- **~120 achievements** (15 base + 105 PvP), win-streak XP, daily quests,
  a crystal-currency shop with power-ups and board skins.
- **Google sign-in** (Firebase) + **Firestore cross-device sync**.
- **Pointer-based drag-and-drop** that works on mouse and touch.
- **Deterministic resume** — interrupted matches replay the 7-bag from the
  saved seed + draw counts.

---

## Quick start

The Flutter project is at the **repo root**. Run all `flutter` commands from there.

```bash
git clone https://github.com/alshfu/block-puzzle-pvp
cd block-puzzle-pvp
flutter pub get

# Dev (web on http://localhost:8080)
flutter run -d chrome

# Tests / static analysis
flutter test              # 176 tests
flutter analyze           # must be clean

# E2E pilot (integration test through the real widget tree)
flutter test integration_test/app_test.dart -d chrome

# Production build + deploy of Flutter Web to GitHub Pages
npm run build:flutter     # flutter build web --release --base-href /block-puzzle-pvp/
npm run deploy:flutter    # build:flutter + gh-pages (build/web → gh-pages branch)
```

Online (PvP) backend — a separate Node WS server (lives in `server/`, deployed
on the VPS):

```bash
npm run server:dev        # local WS server on PORT=1999
npm run server:start      # production entry (same)
```

The client points at the server via the `PARTY_HOST` / `PARTY_TLS` dart-defines
(production: `pvp.alshfu.com`, TLS on — baked into `npm run build:flutter`).

> **Legacy TS front-end** still builds for fallback/rollback: `npm run dev`
> (Vite, `http://localhost:5173`), `npm test` (Vitest), `npm run deploy`. It
> reads its sources from `legacy-ts/`.

---

## Architecture

Three hard layers, no leaks between them — required by the spec
([`TZ_BlockDuel_9x9.md`](./TZ_BlockDuel_9x9.md) § 6.1), with strict **MVVM** on
the Flutter side (Model = core/repositories, ViewModel = Riverpod notifiers
without `BuildContext`, View = widgets without logic):

```
┌───────────────────────────────────────────────────┐
│        Presentation (lib/ui/, Flame, Riverpod)     │  ← widgets, drag-drop,
│                                                    │     themes, audio, mascots
├───────────────────────────────────────────────────┤
│            Game core (lib/core/, pure Dart)        │  ← deterministic
│  PRNG · 7-bag · board · clears · scoring ·         │     7 tetrominoes,
│  bot · forcePlace · blitz timer                    │     RuleConfig, BOT_WEIGHTS
├───────────────────────────────────────────────────┤
│   Platform / network (server/, Node + ws)          │  ← server-authoritative
│   Lobby (matchmaking)  +  Room (game state)        │     VPS, reuses legacy-ts/core
└───────────────────────────────────────────────────┘
```

The Node PvP server imports the **TypeScript** core from `legacy-ts/core`; the
Flutter client runs the **Dart** port in `lib/core`. A golden-gate determinism
test keeps the two cores bit-for-bit identical, so server-authoritative
validation, save/restore and replays line up across both.

### Determinism guarantee

Same `matchSeed` + `RuleConfig` + `moveLog` → identical state. Tested by golden
suites on both cores; exploited by save/restore, PvP server validation, and bot
calibration. The core stays pure: no `DateTime.now()`, no RNG outside the seeded
PRNG, no I/O, no UI imports.

---

## Game modes

| Mode | Players | Notes |
|---|---|---|
| **vs Bot** | 1 human, 1 AI | Easy / Medium / Hard. Bot move well under the 300 ms spec budget. |
| **Hot-seat** | 2 humans, one device | Active hand always rotates to the bottom. |
| **Bot × bot** | 0 humans | Spectate two bots; pick each level independently. |
| **Arcade** | 1 human | Solo play for high score. |
| **Online (PvP)** | 2 humans, separate devices | Quick-play matchmaking; server validates every move; ELO ladder. |

---

## Scoring

```
base    = N · (N + 1) / 2          where N = rows + cols + boxes cleared
combo   = 1 + 0.1 · min(combo, 10)
perfect = +15  (board empty after move)
total   = round(base · combo) + perfect
```

After a match, the result overlay shows the breakdown: **База / Комбо /
Perfect**, plus a streak banner with a themed mascot on 3+ chained wins.

XP per match: 50 (win) / 25 (draw) / 10 (loss) + 1 per clear + streak bonus
(25 / 75 / 200 at 3 / 5 / 10 wins) + sum of unlocked achievement rewards.

---

## Testing

```bash
flutter test              # 176 tests
```

Coverage: clears (rows / cols / boxes / overlaps), scoring (triangular, combo,
perfect), 7-bag fairness + determinism, deadlock and `forcePlace`, golden
determinism (same seed → identical state), bot move validity + timing, blitz
timer curve, plus widget / view-model / online / auth / pilot suites.

The legacy TS core retains its Vitest suite (`npm test`, run from the repo root
against `legacy-ts/`).

---

## Stack

- **Dart 3.12 + Flutter 3.44 + Flame 1.37** — app & rendering
- **Riverpod 3.3** — state management (MVVM view-models)
- **flutter_test + integration_test** — unit / widget / E2E tests
- **Node + `ws` + tsx** (`server/`) — online PvP backend, server-authoritative
- **Firebase Auth + Firestore** — Google sign-in + cross-device sync
- **GitHub Pages** — static hosting via `gh-pages` (Actions workflow kept in
  `.disabled` form pending restored billing)

---

## Repo layout

```
lib/
  core/                    — pure Dart game core (deterministic)
  game/                    — Flame game + components
  ui/                      — screens, widgets, themes (MVVM views)
  online/                  — WS client + online view-models
  auth/                    — Google sign-in + Firestore sync
  storage/                 — persistence (profile, stats, settings, save, TS import)
  achievements/ daily/ profile/ settings/ audio/   — features
  firebase_options.dart    — Firebase web config
test/                      — flutter_test suites (176)
integration_test/app_test.dart  — E2E pilot
web/ android/ ios/ macos/ assets/  — Flutter platforms & assets
pubspec.yaml               — Flutter / Flame / Riverpod deps
server/                    — Node WS PvP backend (imports legacy-ts/core)
legacy-ts/                 — retired TS/React front-end; legacy-ts/core still live
tools/                     — bot-sim, test-plan & pentest tooling
legacy/                    — original JSX prototype (visual reference only)
TZ_BlockDuel_9x9.md        — full Russian spec (source of truth)
MIGRATION_FLUTTER.md       — migration plan; MIGRATION_PROGRESS.md — live checklist
ROADMAP.md  CHANGELOG.md  CLAUDE.md  HANDOFF.md  DEPLOY.md
```

---

## Roadmap

See [`ROADMAP.md`](./ROADMAP.md) for the full phased checklist. Near-term:
production cut-over of GitHub Pages from the TS build to Flutter Web; then the
platform-expansion phases (extra game modes, LAN PvP, social system, deeper
progression, monetization v2, native mobile rollout).

---

## Credits

- Spec author: project owner
- Code & systems: built with [Claude Code](https://claude.com/claude-code)
- Themes inspired by but original to BlockDuel

Made for [TZ_BlockDuel_9x9.md](./TZ_BlockDuel_9x9.md). Pull requests welcome.
