# Web Fidelity Pass

This browser build is a closer gameplay and presentation match to the native macOS version.

## Added in this pass

- enemy ladder-seeking and climbing AI
- full four-frame enemy animation sets plus dedicated stunned frames
- expanded Mr. Yuk animation frames for attack, hurt, and defeat states
- coyote-time and jump-buffer handling
- level-scaled enemy speed, decision timing, sticker cooldown, and stun duration
- PSA chain multiplier up to x4
- extra lives at 10,000-point thresholds, capped at five lives
- native-style time-bonus calculation
- original local WAV sound effects and looped theme music
- pause, music toggle, restart, and focus-loss auto-pause
- stronger CRT/static treatment, impact particles, and screen shake
- native-style episode intro cards, PSA interstitials, game-over card, and final sign-off
- more detailed per-stage procedural background art

## GitHub Pages

The repository includes `.github/workflows/pages.yml`. Push the repository to `main`, then enable GitHub Pages with **GitHub Actions** as the source. The workflow publishes the repository root as a static site.

No package manager, build system, framework, or external JavaScript dependency is required.
