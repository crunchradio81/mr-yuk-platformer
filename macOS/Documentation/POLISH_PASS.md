# Deluxe Polish Pass

## Game feel

The polish pass adds small arcade-style details that make input and feedback feel less prototype-like: jump buffering, a short coyote-time allowance, screen shake on large impacts, particle bursts, hit rings, clearer stun feedback, and a faster scoring cadence.

## Scoring

Consecutive successful safety actions within a short window build a `PSA CHAIN` multiplier up to x4. Hazard sealing and enemy stuns both participate. Episode completion grants a base clear award plus a time bonus.

## Persistence

The highest score is stored with `UserDefaults` and is shown on the title screen, HUD, game-over screen, and final sign-off.

## Audio

`theme.wav` is an original synthesized chiptune-style loop generated specifically for this prototype. The existing jump, slap, danger, start and clear effects remain intact. `M` toggles the background theme.

## Presentation

The title screen is branded as the Deluxe Cut, the episode intro card includes a concise gameplay tip, PSA break cards show the clear/time bonus, and pause/game-over/final-score screens now surface more useful state.

## Extended frame pass

The deluxe build also slices additional frames from the generated sprite sheet for dedicated idle, jump, fall, slap, hurt and defeat states. Enemy animation now uses four walk/ooze frames per enemy plus dedicated stunned art instead of relying only on the original two-frame placeholders.
