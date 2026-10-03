# Animation + Mechanics Notes

## Animation changes

The player sprite path no longer swaps a single texture in a purely positional way. It now selects frames based on visible gameplay state:

- idle
- walk
- climb
- airborne (jump / fall)
- slap
- hurt

Enemies also now have explicit visual handling for normal patrol versus stunned behavior.

## Sticker toss mechanic

Space is now dual-purpose:

1. if Mr. Yuk is close enough to an unsealed hazard, Space seals it
2. otherwise, Space throws a Mr. Yuk sticker projectile forward

Thrown stickers temporarily stun enemies and award bonus points. This creates a more arcade-like route-planning layer while staying thematically appropriate.

## Recommended next step

The strongest next gameplay pass is to add **triggerable shelf/cabinet drops** or similar screen-specific traps so the levels start to gain BurgerTime-style environmental interaction rather than relying only on movement and thrown stickers.
