# Release Pass Notes

This pass focuses on the build feeling like a cleaner release candidate, without changing signing settings or bundle naming.

## Main fixes in this pass

- cleaned the `MrYukReference` art so the light gray square background is removed
- regenerated the entire `AppIcon.appiconset` from the cleaned transparent Mr. Yuk art
- preserved the PSA-style attract screen, which now benefits from the transparent logo
- bumped the project version metadata to a release-style value:
  - `MARKETING_VERSION = 1.0`
  - `CURRENT_PROJECT_VERSION = 6`

## Intentionally not changed

- code signing settings
- bundle identifier naming
- team / notarization configuration

Those can be customized later on the Mac side when preparing a truly distributable build.
