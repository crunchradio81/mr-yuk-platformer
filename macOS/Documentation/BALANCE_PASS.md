# Release-Candidate Balance Pass

This pass tunes the game as an eight-episode arcade run instead of treating every stage as the same difficulty.

## Difficulty curve

- enemy speed now scales smoothly across the full episode list instead of increasing by a fixed amount per stage
- enemy AI decision intervals tighten gradually in later episodes
- sticker stun duration is more generous early and shorter in late episodes
- sticker throw cooldown grows slightly across the run so late-stage crowd control cannot be spammed as easily
- the PSA-chain combo window gradually tightens across the season

## Fairness improvements

- each newly loaded episode now provides a short spawn-grace window
- stage time bonus now uses a hazard-count / episode-aware par calculation instead of one universal formula
- a bonus life is awarded at each 10,000-point threshold, up to five lives total

The intended curve is forgiving enough to learn in episodes 1–2, noticeably busier in 4–6, and arcade-challenging in the final two episodes without relying on sudden one-off difficulty spikes.
