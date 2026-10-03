# Phase 5.1 Build Fix

Fixed the Xcode compile error in `GameScene.swift` where `EnemyNode` declared a stored property named `speed`.

`SKNode` already defines an inherited `speed` property, so Swift does not allow a subclass to introduce another stored property with that name. The gameplay-specific enemy value is now named `movementSpeed`, and all movement, difficulty scaling, and stun/recovery references were updated to use it.
