# Web / GitHub Pages Build

The project now includes a first browser-native playable port in `Web/`.

## Files

- `Web/index.html` — self-contained Canvas/JavaScript game logic (no framework or build step)
- `Web/assets/` — PNG art copied from the native asset catalog
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow

## GitHub limitation

GitHub's normal repository file/README view does **not** execute arbitrary JavaScript. The repository-native way to make the game playable from GitHub is **GitHub Pages**.

## Enable it

1. Push this project to the repository's `main` branch.
2. Open **Settings → Pages** in GitHub.
3. Under **Build and deployment**, choose **GitHub Actions**.
4. The included `Deploy Web Game` workflow will publish the `Web/` folder.
5. Open the Pages URL shown after the workflow finishes.

No npm, bundler, CDN, or external JavaScript dependency is required.

## Browser controls

- Arrow keys / WASD — move and climb
- Z — jump
- Space — seal a nearby hazard or throw a sticker
- Enter — start / continue
- P or Escape — pause

## Port status

This is a browser-native gameplay port rather than a compiled Swift build. It mirrors the title presentation, eight-stage campaign data, platforms, ladders, hazards, enemy patrols, scoring, lives, sticker attacks, PSA cards, and core visual identity. Enemy ladder AI and some native audiovisual polish remain simplified in the web edition for this first pass.
