# Build Notes

- Platform: macOS
- Deployment target: macOS 14.0
- Architecture: arm64
- UI: SwiftUI host with SpriteKit gameplay view
- External dependencies: none
- Network access: none
- Marketing version: 1.0
- Build number: 15
- Campaign: 8 playable PSA episodes

## Phase 8 changes

- added four new playable episodes and four new procedural stage backdrops
- tuned the full campaign difficulty curve
- added score-threshold bonus lives
- added episode-aware time bonus calculation and spawn grace
- retained transparent branding assets and the Phase 7 presentation redesign


## Title-screen layout tweak

- added a center cutout/opening in the lower title-screen frame so `PRESS RETURN TO START` is no longer visually clipped by the border


## Transparency presentation cleanup

- removed the rectangular decorative backdrop behind the Mr. Yuk logo on the title screen and sign-off overlay
- replaced it with a subtle circular glow so the transparent source art reads correctly


## Layout overlap fix

- expanded and re-spaced the PSA interstitial card so the panel boxes, score band, and prompt band no longer collide visually


## Title / backdrop cleanup

- separated the lower title-screen text stack more clearly
- replaced the bathroom stage's large placeholder cabinet and sink shapes with more detailed decorative art


## Full stage-art cleanup

- expanded all eight stage backdrops with themed, low-contrast decorative props and removed remaining placeholder-like large shapes


## Web preview integration

- added `Web/index.html` browser port and copied game sprites to `Web/assets/`
- added a GitHub Pages Actions workflow under `.github/workflows/pages.yml`
- no framework or package-install step is required for the web edition


## Web fidelity pass

- updated the `Web/` build with enemy ladder AI, expanded sprite animation, original audio, combo/extra-life systems, improved CRT effects, and native-style presentation screens
