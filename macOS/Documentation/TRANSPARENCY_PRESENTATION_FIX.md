# Transparency / Presentation Fix

This pass addresses the remaining impression that the main Mr. Yuk art was still sitting on a square background.

## What was happening

The image asset itself was already transparent, but the title screen and sign-off overlay were drawing a rectangular decorative frame directly behind the Mr. Yuk logo. That made the logo read visually as if it still had a boxed background.

## Fix applied

- removed the rectangular logo backdrop treatment on the title screen
- removed the rectangular logo backdrop treatment on the sign-off overlay
- replaced both with a subtler circular glow so the transparent logo reads correctly

This keeps the presentation styled while letting the logo feel properly cut out.
