# BlockDuel 9×9

> Competitive block puzzle on a shared 9×9 grid. Two players take turns placing
> tetrominoes; complete rows, columns or 3×3 boxes clear instantly and score the
> mover. Tight matches, themed mascots, and a deterministic, replayable core.

**🎮 Play now:** <https://alshfu.github.io/block-puzzle-pvp/>

[![tests](https://img.shields.io/badge/tests-46%20passing-brightgreen)](#testing)
[![bundle](https://img.shields.io/badge/bundle-~230%20KB%20JS%20gz%20%7E75%20KB-blue)](#)
[![stack](https://img.shields.io/badge/stack-Vite%20%2B%20React%20%2B%20TS-purple)](#stack)

---

## Highlights

- **Hand-tuned bot**, three levels — calibrated through 5 000+ self-play games
  (`tools/bot-sim.ts`). easy/medium/hard win-rates: 0.7 / 98.4 / 99.3.
- **PvP online** via [PartyKit](https://www.partykit.io) — server-authoritative,
  WebSocket, quick-play matchmaking. Same TS core runs on both client and edge.
- **Hot-seat** mode for two humans on one device, **Bot × bot** spectator mode.
- **Three themes** (`neutral`, `candy`, `night`) with bespoke SVG mascots,
  synthesized chiptune loops per theme (no audio files), drift-friendly UI
  vars driven by a single CSS variable map.
- **15 achievements** across 4 categories (Вехи / Прогресс / Серии / Секреты),
  win-streak XP, score breakdown after each match.
- **Pointer-based drag-and-drop** that works on mouse and touch.
- **Auto-save in localStorage** — interrupted matches resume deterministically
  by replaying the 7-bag from the saved seed + draw counts.
- **PWA-friendly**: 100 dvh phone frame on mobile, fluid desktop layout above
  900 px.

---

## Quick start

```bash
git clone https://github.com/alshfu/block-puzzle-pvp
cd block-puzzle-pvp
npm install

# Frontend dev server (hot reload)
npm run dev               # http://localhost:5173

# Type-check / tests / production build
npm run typecheck
npm test
npm run build

# Static deploy to GitHub Pages
npm run deploy            # builds + pushes dist/ to gh-pages branch

# Online (PvP) backend — runs separately
npm run party:dev         # local PartyKit on ws://localhost:1999
npm run party:deploy      # publishes to <name>.<your-pk-user>.partykit.dev
```

For online play in dev, set `VITE_PARTY_HOST` in `.env.local`
(defaults to `localhost:1999`). In production point it at your deployed
PartyKit URL.

---

## Architecture

Three hard layers, no leaks between them — required by the spec
([`TZ_BlockDuel_9x9.md`](./TZ_BlockDuel_9x9.md) § 6.1):

```
┌──────────────────────────────────────────────┐
│           Presentation (src/ui/)              │  ← React, drag-drop, themes,
│                                               │     audio, mascots, achievements
├──────────────────────────────────────────────┤
│         Game core (src/core/index.ts)         │  ← pure TS, deterministic
│  PRNG · 7-bag · board · clears · scoring ·    │     7 tetrominoes, RuleConfig,
│  bot · forcePlace · blitz timer               │     BOT_WEIGHTS, opponentThreatGain
├──────────────────────────────────────────────┤
│  Platform / network (party/)                  │  ← PartyKit (Cloudflare DO)
│  Lobby (matchmaking)  +  Room (game state)    │     reuses src/core
└──────────────────────────────────────────────┘
```

### Determinism guarantee

Same `matchSeed` + `RuleConfig` + `moveLog` → identical state.
Tested by `tests/determinism.test.ts` (golden) and exploited by save/restore,
PvP server validation, and bot calibration.

### Game core surface

| Function | Purpose |
|---|---|
| `makeRng(seed)` | mulberry32 PRNG |
| `Bag(seed)` | 7-bag tetromino randomizer, per-player |
| `emptyBoard()` / `place()` / `canPlace()` | Board ops |
| `findClears(board)` → rows/cols/boxes + cleared cells | Clears (atomic) |
| `scoreForMove(N, combo, perfect, cfg)` | Triangular base × combo mult + perfect bonus |
| `enumerateMoves` / `hasAnyMove` / `pieceHasMove` | Move enumeration, deadlock |
| `chooseBotMove(board, hand, level, cfg, rng)` | Bot AI (uses `BOT_WEIGHTS`) |
| `forcePlace(board, hand, cfg, rng)` | Blitz timeout fallback |
| `turnTimeForRound(round, cfg)` | Blitz curve |

---

## Game modes

| Mode | Players | Notes |
|---|---|---|
| **vs Bot** | 1 human, 1 AI | Easy / Medium / Hard. Bot AI completes a move in < 1 ms; well under the 300 ms spec budget. |
| **Hot-seat** | 2 humans, one device | Active hand always rotates to the bottom. |
| **Bot × bot** | 0 humans | Spectate two bots; pick each level independently. |
| **Online (PvP)** | 2 humans, separate devices | Quick-play matchmaking via PartyKit lobby; server validates every move. |

---

## Bot calibration

`tools/bot-sim.ts` runs N self-play matches between any pair of levels and
prints win-rate, average turns, ms per move, and so on. Calibrated values
land in `src/core/BOT_WEIGHTS`.

```bash
npx tsx tools/bot-sim.ts --games 1000           # all 5 pairs, ~1 min
npx tsx tools/bot-sim.ts --games 2000 --pair medium,hard
```

Most recent calibration (5 000 games per pair):

| Match | p0 winrate | p1 winrate | Notes |
|---|---|---|---|
| easy vs medium | 0.9 % | **98.4 %** | medium clearly stronger |
| easy vs hard | 0.4 % | **99.3 %** | |
| medium vs hard | 38.3 % | **56.9 %** | +18 pp for hard |
| medium vs medium | 49.1 % | 47.4 % | symmetric ✓ |
| hard vs hard | 49.9 % | 45.8 % | symmetric ✓ |

---

## Scoring

```
base   = N · (N + 1) / 2          where N = rows + cols + boxes cleared
combo  = 1 + 0.1 · min(combo, 10)
perfect = +15  (board empty after move)
total  = round(base · combo) + perfect
```

After a match, `ResultOverlay` shows the breakdown: **База / Комбо / Perfect**,
plus a streak banner with a themed mascot if the player just chained 3+ wins.

XP per match: 50 (win) / 25 (draw) / 10 (loss) + 1 per clear + streak bonus
(25 / 75 / 200 at 3 / 5 / 10 wins) + sum of unlocked achievement rewards.

---

## Testing

```bash
npm test
```

Vitest covers: clears (rows / cols / boxes / overlaps), scoring (triangular,
combo, perfect, no-combo), 7-bag fairness + determinism, deadlock and
`forcePlace`, golden determinism test (same seed → identical state), bot
move validity + sub-300 ms timing, opponent-threat heuristic, blitz timer
curve. 46 tests total.

---

## Stack

- **Vite 5 + React 18 + TypeScript 5** — UI
- **Vitest 2** — tests
- **PartyKit** (Cloudflare Durable Objects) — online backend
- **Web Audio API** — synthesized SFX + theme loops, no audio files
- **GitHub Pages** — static hosting via `gh-pages` npm package (Actions
  workflow exists in `.disabled` form for future billing-restored use)

Everything statically deployable; the only paid surface area is PartyKit's free
tier on Cloudflare.

---

## Repo layout

```
src/
  core/index.ts            — pure game core
  ui/
    App.tsx                — root, screen routing
    main.tsx               — entry
    styles.css             — single global stylesheet (CSS vars per theme)
    themes.ts              — neutral / candy / night palettes
    audio.ts               — sound FX synthesizer
    music.ts               — theme background loops
    useGame.ts             — local game state hook
    online/
      client.ts            — PartySocket wrapper
      useOnlineGame.ts     — online state hook
    components/            — Board, Hand, Scoreboard, Mascot, Confetti, …
    screens/               — Menu, Setup, Game, Profile, Settings,
                             Achievements, OnlineMenu, OnlineGame
    achievements/          — definitions + engine
    storage/               — localStorage (profile, stats, settings,
                             achievements, saved game)
party/
  protocol.ts              — client↔server message types
  lobby.ts                 — matchmaking (singleton)
  room.ts                  — game state (instance per match)
tools/
  bot-sim.ts               — bot-vs-bot calibrator
tests/                     — Vitest suites
legacy/                    — original JSX prototype (visual reference only)
TZ_BlockDuel_9x9.md        — full Russian spec (v1.0)
CLAUDE.md                  — code conventions, layout, what not to touch
```

---

## Roadmap

- [x] Pure deterministic core + tests
- [x] Vite + React + TS scaffold + 3 themes
- [x] Playable single-device modes (vs Bot, hot-seat, bot × bot)
- [x] Profile, stats, autosave, settings
- [x] Sound + themed music + drag-and-drop
- [x] 15 achievements + win-streak XP + score breakdown
- [x] Bot calibration via self-play sim
- [x] PvP online — PartyKit lobby + room
- [ ] Google Auth + cross-device sync
- [ ] Tutorial / first-time onboarding
- [ ] Solo arcade with daily quests
- [ ] Shop: cosmetics, block skins (gems, bullets, …)
- [ ] EN localisation, colour-blind patterns

---

## Credits

- Spec author: project owner
- Code & systems: built with [Claude Code](https://claude.com/claude-code)
- Themes inspired by but original to BlockDuel

Made for [TZ_BlockDuel_9x9.md](./TZ_BlockDuel_9x9.md). Pull requests welcome.
