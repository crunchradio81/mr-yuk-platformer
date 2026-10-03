# Mr. Yuk's Poison Patrol — Deluxe Polish Build

Native macOS 14+ / Apple Silicon game built with SwiftUI and SpriteKit. The project is designed to feel like a playable late-1980s/early-1990s poison-control PSA filtered through a single-screen arcade platformer.

## Run

1. Open `MrYukPoisonPatrol.xcodeproj` in Xcode.
2. Select the `MrYukPoisonPatrol` scheme.
3. Choose **My Mac**.
4. Run.

## Controls

- Arrow keys or WASD — move / climb
- Z — jump
- Space — seal a nearby hazard; otherwise toss a Mr. Yuk sticker at an enemy
- P or Escape — pause / resume
- M — toggle background music
- R — restart the current episode
- Return — start / continue between PSA cards

## Deluxe polish additions

- persistent local high score
- PSA chain multiplier up to x4 for quick consecutive seals/stuns
- episode timer and time-bonus scoring
- responsive jump buffering and short coyote-time window
- pause overlay
- original looping chiptune-style background theme
- hit particles, impact rings, screen shake, stronger stun feedback
- refined title card, HUD, game-over, final-score and interstitial presentation
- gradual difficulty ramp across the full eight-episode campaign
- the integrated pixel-art sprite atlas remains the active visual basis

The game currently contains eight episodes: bathroom, garage, basement/storage, kitchen, laundry room, garden shed, visiting another house, and a final Poison Control Challenge.

## Distribution note

Mr. Yuk and related marks are associated with poison-control public education. This is an unofficial fan/game-development project. Confirm trademark, licensing, and branding permission before public or commercial distribution.


## Phase 5.2 title-screen pass

The attract screen now uses a faux 1990s poison-control PSA layout instead of showing the development sprite sheet.


## Phase 6 release pass

This pass cleans the Mr. Yuk logo asset and app icon backgrounds to proper transparency and bumps the project version metadata for a cleaner release-candidate style handoff.


## Phase 7 presentation pass

The HUD, episode-intro banner, PSA interstitial cards, and end-state overlays were redesigned for a more complete faux-1990s public-service-arcade presentation.


## Phase 8 — expanded release candidate

The campaign now contains eight episodes and a full-run balance curve, including progressive enemy behavior, tuned sticker/stun timing, spawn grace, score-based bonus lives, and par-aware time bonuses.


## Phase 9 stage-art + web preview

All eight native stage backdrops received a detailed cleanup pass. A first browser-native Canvas port is also included under `Web/` for GitHub Pages deployment.
