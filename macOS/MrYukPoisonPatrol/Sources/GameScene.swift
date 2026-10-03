import SpriteKit
import AppKit

final class GameScene: SKScene {
    private enum Mode {
        case attract
        case playing
        case interstitial
        case paused
        case gameOver
        case finished
    }

    private final class HazardNode: SKNode {
        let id = UUID()
        let kind: HazardKind
        let sprite: SKSpriteNode
        var sealed = false

        init(kind: HazardKind, sprite: SKSpriteNode) {
            self.kind = kind
            self.sprite = sprite
            super.init()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private final class EnemyNode: SKNode {
        enum Movement {
            case patrol
            case seeking(ladder: CGRect, targetY: CGFloat)
            case climbing(ladder: CGRect, targetY: CGFloat)
        }

        let kind: EnemyKind
        let sprite: SKSpriteNode
        var baseSpeed: CGFloat
        var minX: CGFloat
        var maxX: CGFloat
        var movementSpeed: CGFloat
        var direction: CGFloat = 1
        var movement: Movement = .patrol
        var nextDecision: TimeInterval = 0
        var stunnedUntil: TimeInterval = 0
        var starsNode: SKNode?

        init(kind: EnemyKind, sprite: SKSpriteNode, minX: CGFloat, maxX: CGFloat, speed: CGFloat) {
            self.kind = kind
            self.sprite = sprite
            self.baseSpeed = speed
            self.minX = minX
            self.maxX = maxX
            self.movementSpeed = speed
            super.init()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private final class StickerProjectileNode: SKSpriteNode {
        var velocityVector: CGVector

        init(texture: SKTexture, size: CGSize, velocity: CGVector) {
            self.velocityVector = velocity
            super.init(texture: texture, color: .clear, size: size)
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private let world = SKNode()
    private let hud = SKNode()
    private let overlay = SKNode()
    private let player = SKNode()
    private let playerSprite = SKSpriteNode()

    private var platforms: [CGRect] = []
    private var ladders: [CGRect] = []
    private var hazards: [HazardNode] = []
    private var enemies: [EnemyNode] = []
    private var projectiles: [StickerProjectileNode] = []
    private var keysDown = Set<UInt16>()
    private var textureCache: [String: SKTexture] = [:]

    private var levelIndex = 0
    private var mode: Mode = .attract
    private var score = 0
    private var lives = 3
    private var playerVelocity = CGVector.zero
    private var playerOnLadder = false
    private var lastUpdateTime: TimeInterval = 0
    private var invulnerableUntil: TimeInterval = 0
    private var facing: CGFloat = 1
    private var wasJumpDown = false
    private var wasActionDown = false
    private var animationClock: CGFloat = 0
    private var noiseClock: CGFloat = 0
    private var currentTimeValue: TimeInterval = 0
    private var slapUntil: TimeInterval = 0
    private var hurtUntil: TimeInterval = 0
    private var actionCooldownUntil: TimeInterval = 0
    private var levelStartTime: TimeInterval = 0
    private var lastTimerSecond: Int = -1
    private var comboCount = 0
    private var comboExpiresAt: TimeInterval = 0
    private var lastStageBonus = 0
    private var highScore = UserDefaults.standard.integer(forKey: "MrYukPoisonPatrolHighScore")
    private var musicEnabled = UserDefaults.standard.object(forKey: "MrYukPoisonPatrolMusic") as? Bool ?? true
    private var lastGroundedAt: TimeInterval = 0
    private var jumpBufferUntil: TimeInterval = 0
    private var pauseStartedAt: TimeInterval = 0
    private var nextExtraLifeScore = 10000

    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let livesLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let targetLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let highScoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let psaLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let trackingBar = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 4))
    private let randomNoise = SKNode()

    override func didMove(to view: SKView) {
        backgroundColor = GamePalette.nearBlack
        anchorPoint = CGPoint.zero
        addChild(world)
        addChild(hud)
        addChild(overlay)
        buildPlayer()
        buildHUD()
        buildCRTOverlay()
        showAttractMode()
    }

    // MARK: - Assets

    private func texture(_ name: String) -> SKTexture {
        if let cached = textureCache[name] { return cached }
        let loaded = SKTexture(imageNamed: name)
        loaded.filteringMode = .nearest
        textureCache[name] = loaded
        return loaded
    }

    private func textures(_ names: [String]) -> [SKTexture] {
        names.map { texture($0) }
    }

    // MARK: - Release balance

    private var balanceProgress: Double {
        guard LevelBook.levels.count > 1 else { return 0 }
        return Double(levelIndex) / Double(LevelBook.levels.count - 1)
    }

    private var enemySpeedScale: CGFloat {
        1.0 + CGFloat(balanceProgress * 0.20)
    }

    private var stickerCooldown: TimeInterval {
        0.34 + balanceProgress * 0.12
    }

    private var enemyStunDuration: TimeInterval {
        2.8 - balanceProgress * 0.9
    }

    private var comboWindow: TimeInterval {
        3.15 - balanceProgress * 0.55
    }

    private var enemyDecisionDelay: ClosedRange<Double> {
        let low = 0.52 - balanceProgress * 0.12
        let high = 0.92 - balanceProgress * 0.22
        return low...high
    }

    private func calculateTimeBonus(elapsed: TimeInterval) -> Int {
        let hazardAllowance = Double(hazards.count) * 3.4
        let parTime = 28.0 + hazardAllowance + Double(levelIndex) * 1.8
        if elapsed <= parTime {
            return min(4500, 3500 + Int((parTime - elapsed) * 22))
        }
        return max(500, 3500 - Int((elapsed - parTime) * 55))
    }

    private func grantExtraLifeIfNeeded() {
        var earnedLife = false
        while score >= nextExtraLifeScore {
            if lives < 5 {
                lives += 1
                earnedLife = true
            }
            nextExtraLifeScore += 10000
        }
        if earnedLife {
            flashMessage("BONUS YUK! +1 LIFE", color: GamePalette.yukGreen)
            runSound("clear.wav")
        }
    }

    // MARK: - Player / HUD

    private func buildPlayer() {
        player.name = "player"
        player.zPosition = 20
        playerSprite.texture = texture("PlayerIdle1")
        playerSprite.size = CGSize(width: 34, height: 34)
        player.addChild(playerSprite)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 6))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -17)
        shadow.zPosition = -1
        player.addChild(shadow)

        world.addChild(player)
    }

    private func buildHUD() {
        let bar = SKShapeNode(rect: CGRect(x: 0, y: 442, width: 640, height: 38))
        bar.fillColor = .black
        bar.strokeColor = GamePalette.yukGreen
        bar.lineWidth = 2
        hud.addChild(bar)

        let topInset = SKShapeNode(rect: CGRect(x: 6, y: 446, width: 628, height: 30))
        topInset.fillColor = GamePalette.nearBlack.withAlphaComponent(0.96)
        topInset.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.20)
        topInset.lineWidth = 1
        hud.addChild(topInset)

        let segments: [(CGFloat, CGFloat)] = [(8, 122), (134, 100), (240, 160), (406, 96), (508, 124)]
        for (x, width) in segments {
            let panel = SKShapeNode(rect: CGRect(x: x, y: 448, width: width, height: 26))
            panel.fillColor = SKColor.white.withAlphaComponent(0.03)
            panel.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.18)
            panel.lineWidth = 1
            hud.addChild(panel)
        }

        configureHUDLabel(scoreLabel, x: 14, alignment: .left)
        scoreLabel.fontSize = 11

        configureHUDLabel(highScoreLabel, x: 138, alignment: .left)
        highScoreLabel.fontSize = 9
        highScoreLabel.fontColor = GamePalette.warningYellow

        configureHUDLabel(targetLabel, x: 320, alignment: .center)
        targetLabel.fontSize = 10

        configureHUDLabel(timerLabel, x: 496, alignment: .right)
        timerLabel.fontSize = 9
        timerLabel.fontColor = GamePalette.offWhite

        configureHUDLabel(livesLabel, x: 624, alignment: .right)
        livesLabel.fontSize = 10

        comboLabel.fontSize = 9
        comboLabel.fontColor = GamePalette.warningYellow
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .center
        comboLabel.position = CGPoint(x: 320, y: 427)
        comboLabel.zPosition = 80
        hud.addChild(comboLabel)

        let ticker = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 17))
        ticker.fillColor = .black
        ticker.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.75)
        ticker.lineWidth = 1
        hud.addChild(ticker)

        psaLabel.fontSize = 10
        psaLabel.fontColor = GamePalette.phosphorGreen
        psaLabel.horizontalAlignmentMode = .center
        psaLabel.verticalAlignmentMode = .center
        psaLabel.position = CGPoint(x: 320, y: 8)
        hud.addChild(psaLabel)
        refreshHUD()
    }

    private func configureHUDLabel(_ label: SKLabelNode, x: CGFloat, alignment: SKLabelHorizontalAlignmentMode) {
        label.fontSize = 14
        label.fontColor = GamePalette.yukGreen
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: x, y: 461)
        hud.addChild(label)
    }

    private func buildCRTOverlay() {
        let scanlines = SKNode()
        scanlines.zPosition = 1000
        for y in stride(from: CGFloat(0), through: 480, by: 4) {
            let line = SKShapeNode(rect: CGRect(x: 0, y: y, width: 640, height: 1))
            line.fillColor = SKColor.black.withAlphaComponent(0.13)
            line.strokeColor = .clear
            scanlines.addChild(line)
        }
        scanlines.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.78, duration: 0.05),
            .fadeAlpha(to: 1.0, duration: 0.08),
            .wait(forDuration: 1.25)
        ])))
        addChild(scanlines)

        trackingBar.fillColor = SKColor.white.withAlphaComponent(0.075)
        trackingBar.strokeColor = .clear
        trackingBar.zPosition = 1002
        trackingBar.position.y = -10
        addChild(trackingBar)
        trackingBar.run(.repeatForever(.sequence([
            .moveTo(y: 490, duration: 3.8),
            .moveTo(y: -10, duration: 0)
        ])))

        randomNoise.zPosition = 1001
        addChild(randomNoise)

        let topEdge = SKShapeNode(rect: CGRect(x: 0, y: 476, width: 640, height: 4))
        topEdge.fillColor = GamePalette.vhsCyan.withAlphaComponent(0.08)
        topEdge.strokeColor = .clear
        topEdge.zPosition = 1003
        addChild(topEdge)

        let bottomEdge = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 3))
        bottomEdge.fillColor = GamePalette.vhsMagenta.withAlphaComponent(0.08)
        bottomEdge.strokeColor = .clear
        bottomEdge.zPosition = 1003
        addChild(bottomEdge)
    }

    private func refreshNoise() {
        randomNoise.removeAllChildren()
        for _ in 0..<10 {
            let width = CGFloat.random(in: 18...140)
            let line = SKShapeNode(rect: CGRect(x: CGFloat.random(in: 0...620),
                                                y: CGFloat.random(in: 0...478),
                                                width: width,
                                                height: Bool.random() ? 1 : 2))
            line.fillColor = SKColor.white.withAlphaComponent(CGFloat.random(in: 0.02...0.09))
            line.strokeColor = .clear
            randomNoise.addChild(line)
        }
    }

    private func staticBurst(duration: TimeInterval = 0.24) {
        let burst = SKNode()
        burst.zPosition = 1900
        for _ in 0..<48 {
            let h = CGFloat.random(in: 1...5)
            let line = SKShapeNode(rect: CGRect(x: CGFloat.random(in: 0...80),
                                                y: CGFloat.random(in: 0...480),
                                                width: CGFloat.random(in: 280...640),
                                                height: h))
            line.fillColor = Bool.random()
                ? SKColor.white.withAlphaComponent(CGFloat.random(in: 0.12...0.45))
                : GamePalette.yukGreen.withAlphaComponent(CGFloat.random(in: 0.05...0.22))
            line.strokeColor = .clear
            burst.addChild(line)
        }
        addChild(burst)
        burst.run(.sequence([
            .wait(forDuration: duration * 0.45),
            .fadeOut(withDuration: duration * 0.55),
            .removeFromParent()
        ]))
    }

    // MARK: - Attract mode / progression

    private func showAttractMode() {
        mode = .attract
        stopMusic()
        clearWorld(keepPlayer: true)
        player.isHidden = true
        hud.isHidden = true
        overlay.removeAllChildren()
        staticBurst(duration: 0.32)
        buildTitleScreen()
    }

    private func buildTitleScreen() {
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 480))
        bg.fillColor = GamePalette.nearBlack
        bg.strokeColor = .clear
        bg.zPosition = 200
        overlay.addChild(bg)

        for x in stride(from: CGFloat(0), through: 640, by: 16) {
            let stripe = SKShapeNode(rect: CGRect(x: x, y: 0, width: 8, height: 480))
            stripe.fillColor = (Int(x / 16) % 2 == 0 ? GamePalette.yukGreen : GamePalette.warningYellow).withAlphaComponent(0.025)
            stripe.strokeColor = .clear
            stripe.zPosition = 201
            overlay.addChild(stripe)
        }

        let tv = SKShapeNode(rectOf: CGSize(width: 586, height: 430), cornerRadius: 12)
        tv.position = CGPoint(x: 320, y: 246)
        tv.fillColor = SKColor.black.withAlphaComponent(0.94)
        tv.strokeColor = GamePalette.yukGreen
        tv.lineWidth = 4
        tv.zPosition = 202
        overlay.addChild(tv)

        let inset = SKShapeNode(rectOf: CGSize(width: 558, height: 402), cornerRadius: 10)
        inset.fillColor = GamePalette.nearBlack.withAlphaComponent(0.92)
        inset.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.25)
        inset.lineWidth = 1
        inset.zPosition = 0
        tv.addChild(inset)

        let channel = label("CHANNEL 13 • PUBLIC SERVICE ARCADE • DELUXE CUT", size: 10.5, color: GamePalette.warningYellow)
        channel.position = CGPoint(x: 0, y: 190)
        tv.addChild(channel)

        let sponsor = label("A LOST 1990s POISON-CONTROL TV SPECIAL • 8 EPISODES", size: 7.8, color: GamePalette.offWhite)
        sponsor.position = CGPoint(x: 0, y: 173)
        sponsor.alpha = 0.88
        tv.addChild(sponsor)

        let warningBar = SKShapeNode(rectOf: CGSize(width: 500, height: 18), cornerRadius: 3)
        warningBar.position = CGPoint(x: 0, y: 152)
        warningBar.fillColor = GamePalette.warningYellow.withAlphaComponent(0.16)
        warningBar.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.55)
        warningBar.lineWidth = 1
        tv.addChild(warningBar)

        let warningText = label("KEEP OUT OF REACH OF CHILDREN • READ THE LABEL • CALL POISON HELP", size: 7.8, color: GamePalette.warningYellow)
        warningText.position = CGPoint(x: 0, y: 152)
        tv.addChild(warningText)

        let logoGlow = SKShapeNode(circleOfRadius: 60)
        logoGlow.position = CGPoint(x: 0, y: 92)
        logoGlow.fillColor = GamePalette.yukGreen.withAlphaComponent(0.05)
        logoGlow.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.20)
        logoGlow.lineWidth = 1
        tv.addChild(logoGlow)

        let logo = SKSpriteNode(texture: texture("MrYukReference"), size: CGSize(width: 108, height: 108))
        logo.position = CGPoint(x: 0, y: 92)
        logo.zPosition = 2
        tv.addChild(logo)

        let titleTop = label("MR. YUK'S", size: 18, color: GamePalette.phosphorGreen)
        titleTop.position = CGPoint(x: 0, y: 20)
        tv.addChild(titleTop)

        let titleBottom = label("POISON PATROL", size: 29, color: GamePalette.yukGreen)
        titleBottom.position = CGPoint(x: 0, y: -8)
        tv.addChild(titleBottom)

        let tagline = label("THE BAD STUFF IS ON THE LOOSE!", size: 10.5, color: GamePalette.offWhite)
        tagline.position = CGPoint(x: 0, y: -34)
        tv.addChild(tagline)

        let lowerBand = SKShapeNode(rectOf: CGSize(width: 522, height: 104), cornerRadius: 6)
        lowerBand.position = CGPoint(x: 0, y: -109)
        lowerBand.fillColor = SKColor.white.withAlphaComponent(0.035)
        lowerBand.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.25)
        lowerBand.lineWidth = 1
        tv.addChild(lowerBand)

        func addPSACard(x: CGFloat, title: String, body: String, accent: SKColor, iconName: String) {
            let card = SKShapeNode(rectOf: CGSize(width: 154, height: 82), cornerRadius: 5)
            card.position = CGPoint(x: x, y: -107)
            card.fillColor = GamePalette.nearBlack.withAlphaComponent(0.94)
            card.strokeColor = accent.withAlphaComponent(0.8)
            card.lineWidth = 2
            card.zPosition = 2
            tv.addChild(card)

            let headerBand = SKShapeNode(rectOf: CGSize(width: 148, height: 16), cornerRadius: 3)
            headerBand.position = CGPoint(x: 0, y: 25)
            headerBand.fillColor = accent.withAlphaComponent(0.16)
            headerBand.strokeColor = .clear
            card.addChild(headerBand)

            let head = label(title, size: 8.2, color: accent)
            head.position = CGPoint(x: 0, y: 25)
            card.addChild(head)

            let icon = SKSpriteNode(texture: texture(iconName), size: CGSize(width: 26, height: 26))
            icon.position = CGPoint(x: -53, y: -2)
            icon.zPosition = 2
            card.addChild(icon)

            let bodyNode = multilineLabel(body, size: 7.1, color: GamePalette.offWhite, width: 108, lineHeight: 10)
            bodyNode.position = CGPoint(x: 22, y: -6)
            card.addChild(bodyNode)
        }

        addPSACard(x: -176,
                   title: "MEDICINE SAFETY",
                   body: "MEDICINE IS\nNOT CANDY.",
                   accent: GamePalette.warningYellow,
                   iconName: "HazardMedicine1")

        addPSACard(x: 0,
                   title: "STICK ON A YUK",
                   body: "IF IT'S HARMFUL,\nLABEL IT CLEARLY.",
                   accent: GamePalette.yukGreen,
                   iconName: "YukSticker")

        addPSACard(x: 176,
                   title: "POISON HELP",
                   body: "CALL\n1-800-222-1222",
                   accent: GamePalette.phosphorGreen,
                   iconName: "HazardCleaner1")

        let controls = label("MOVE ARROWS/WASD   Z JUMP   SPACE SEAL/TOSS   P PAUSE   M MUSIC", size: 7.6, color: GamePalette.offWhite)
        controls.position = CGPoint(x: 0, y: -158)
        tv.addChild(controls)

        let hi = label(String(format: "LOCAL HIGH SCORE  %06d", highScore), size: 8.6, color: GamePalette.phosphorGreen)
        hi.position = CGPoint(x: 0, y: -173)
        tv.addChild(hi)

        let help = label("POISON HELP  1-800-222-1222", size: 10.2, color: GamePalette.warningYellow)
        help.position = CGPoint(x: 0, y: -189)
        tv.addChild(help)

        let bottomCutout = SKShapeNode(rectOf: CGSize(width: 276, height: 28), cornerRadius: 10)
        bottomCutout.position = CGPoint(x: 0, y: -213)
        bottomCutout.fillColor = GamePalette.nearBlack
        bottomCutout.strokeColor = .clear
        bottomCutout.zPosition = 2.5
        tv.addChild(bottomCutout)

        let bottomCutoutLine = SKShapeNode(rectOf: CGSize(width: 246, height: 1), cornerRadius: 0)
        bottomCutoutLine.position = CGPoint(x: 0, y: -199)
        bottomCutoutLine.fillColor = GamePalette.yukGreen.withAlphaComponent(0.45)
        bottomCutoutLine.strokeColor = .clear
        bottomCutoutLine.zPosition = 2.6
        tv.addChild(bottomCutoutLine)

        let press = label("PRESS RETURN TO START", size: 11.2, color: GamePalette.yukGreen)
        press.position = CGPoint(x: 0, y: -210)
        press.zPosition = 3
        press.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 0.4),
            .fadeAlpha(to: 1.0, duration: 0.4)
        ])))
        tv.addChild(press)
    }

    private func startGame() {
        score = 0
        lives = 3
        levelIndex = 0
        comboCount = 0
        comboExpiresAt = 0
        lastStageBonus = 0
        actionCooldownUntil = 0
        nextExtraLifeScore = 10000
        player.isHidden = false
        hud.isHidden = false
        overlay.removeAllChildren()
        runSound("start.wav")
        startMusicIfNeeded()
        loadLevel(levelIndex)
    }

    private func loadLevel(_ index: Int) {
        guard LevelBook.levels.indices.contains(index) else { return }
        mode = .playing
        overlay.removeAllChildren()
        clearWorld(keepPlayer: true)
        hazards.removeAll()
        enemies.removeAll()
        projectiles.removeAll()
        comboCount = 0
        comboExpiresAt = 0
        levelStartTime = currentTimeValue
        lastTimerSecond = -1
        lastStageBonus = 0
        jumpBufferUntil = 0
        lastGroundedAt = currentTimeValue

        let level = LevelBook.levels[index]
        platforms = level.platforms.map(\.rect)
        ladders = level.ladders.map(\.rect)

        buildBackdrop(levelNumber: index + 1, level: level)
        for spec in level.platforms { addPlatform(spec.rect) }
        for spec in level.ladders { addLadder(spec.rect) }
        for spec in level.hazards { addHazard(spec) }
        for spec in level.enemies { addEnemy(spec) }
        for enemy in enemies {
            enemy.movementSpeed *= enemySpeedScale
            enemy.baseSpeed = enemy.movementSpeed
        }

        player.position = level.spawn
        playerVelocity = .zero
        playerOnLadder = false
        player.alpha = 1
        playerSprite.alpha = 1
        player.xScale = 1
        facing = 1
        invulnerableUntil = max(lastUpdateTime, currentTimeValue) + 1.05
        psaLabel.text = "POISON HELP 1-800-222-1222  •  \(level.psaLine)"
        refreshHUD()
        staticBurst(duration: 0.18)
        showLevelBanner(level)
    }

    private func showLevelBanner(_ level: LevelDefinition) {
        let card = SKShapeNode(rectOf: CGSize(width: 540, height: 134), cornerRadius: 8)
        card.position = CGPoint(x: 320, y: 258)
        card.fillColor = SKColor.black.withAlphaComponent(0.94)
        card.strokeColor = GamePalette.yukGreen
        card.lineWidth = 3
        card.zPosition = 100
        overlay.addChild(card)

        let inset = SKShapeNode(rectOf: CGSize(width: 522, height: 116), cornerRadius: 6)
        inset.fillColor = GamePalette.nearBlack.withAlphaComponent(0.96)
        inset.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.22)
        inset.lineWidth = 1
        card.addChild(inset)

        let headerBand = SKShapeNode(rectOf: CGSize(width: 506, height: 18), cornerRadius: 4)
        headerBand.position = CGPoint(x: 0, y: 43)
        headerBand.fillColor = GamePalette.warningYellow.withAlphaComponent(0.16)
        headerBand.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.55)
        headerBand.lineWidth = 1
        card.addChild(headerBand)

        let channel = label("PSA EPISODE \(levelIndex + 1) • \(level.channelTag)", size: 8.8, color: GamePalette.warningYellow)
        channel.position = CGPoint(x: 0, y: 43)
        card.addChild(channel)

        let top = label(level.title, size: 19, color: GamePalette.yukGreen)
        top.position = CGPoint(x: 0, y: 15)
        card.addChild(top)

        let bottom = label(level.psaLine, size: 10, color: GamePalette.offWhite)
        bottom.position = CGPoint(x: 0, y: -11)
        card.addChild(bottom)

        let reminderBand = SKShapeNode(rectOf: CGSize(width: 468, height: 22), cornerRadius: 4)
        reminderBand.position = CGPoint(x: 0, y: -41)
        reminderBand.fillColor = SKColor.white.withAlphaComponent(0.04)
        reminderBand.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.24)
        reminderBand.lineWidth = 1
        card.addChild(reminderBand)

        let tip = label("SPACE seals nearby hazards or tosses a sticker • chain actions for PSA multipliers", size: 6.7, color: GamePalette.phosphorGreen)
        tip.position = CGPoint(x: 0, y: -41)
        card.addChild(tip)

        let footer = label("GET READY", size: 8.2, color: GamePalette.yukGreen)
        footer.position = CGPoint(x: 0, y: -62)
        footer.alpha = 0.92
        card.addChild(footer)

        card.alpha = 0
        card.run(.sequence([
            .fadeIn(withDuration: 0.08),
            .wait(forDuration: 1.55),
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))
    }

    private func completeLevel() {
        guard mode == .playing else { return }
        mode = .interstitial
        let elapsed = max(0, currentTimeValue - levelStartTime)
        lastStageBonus = calculateTimeBonus(elapsed: elapsed)
        score += 1000 + lastStageBonus
        grantExtraLifeIfNeeded()
        updateHighScoreIfNeeded()
        refreshHUD()
        runSound("clear.wav")
        impactBurst(at: player.position, color: GamePalette.yukGreen, count: 18)
        screenShake(intensity: 5, duration: 0.24)
        staticBurst(duration: 0.3)
        showPSABreak(for: LevelBook.levels[levelIndex], isFinalStage: levelIndex == LevelBook.levels.count - 1)
    }

    private func showPSABreak(for level: LevelDefinition, isFinalStage: Bool) {
        overlay.removeAllChildren()
        let dim = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 480))
        dim.fillColor = .black
        dim.strokeColor = .clear
        dim.zPosition = 200
        overlay.addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: 570, height: 408), cornerRadius: 10)
        card.position = CGPoint(x: 320, y: 244)
        card.fillColor = GamePalette.nearBlack
        card.strokeColor = GamePalette.yukGreen
        card.lineWidth = 4
        card.zPosition = 201
        overlay.addChild(card)

        let inset = SKShapeNode(rectOf: CGSize(width: 548, height: 386), cornerRadius: 8)
        inset.fillColor = GamePalette.nearBlack.withAlphaComponent(0.96)
        inset.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.18)
        inset.lineWidth = 1
        card.addChild(inset)

        let headerBand = SKShapeNode(rectOf: CGSize(width: 520, height: 22), cornerRadius: 4)
        headerBand.position = CGPoint(x: 0, y: 167)
        headerBand.fillColor = GamePalette.warningYellow.withAlphaComponent(0.16)
        headerBand.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.5)
        headerBand.lineWidth = 1
        card.addChild(headerBand)

        let top = label("WE INTERRUPT THIS GAME FOR A PUBLIC SERVICE ANNOUNCEMENT", size: 8.2, color: GamePalette.warningYellow)
        top.position = CGPoint(x: 0, y: 167)
        card.addChild(top)

        let leftPanel = SKShapeNode(rectOf: CGSize(width: 150, height: 214), cornerRadius: 7)
        leftPanel.position = CGPoint(x: -176, y: 30)
        leftPanel.fillColor = SKColor.white.withAlphaComponent(0.03)
        leftPanel.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.3)
        leftPanel.lineWidth = 1
        card.addChild(leftPanel)

        let logo = SKSpriteNode(texture: texture("MrYukReference"), size: CGSize(width: 90, height: 90))
        logo.position = CGPoint(x: 0, y: 50)
        leftPanel.addChild(logo)

        let badge = label("EPISODE CLEAR", size: 9, color: GamePalette.yukGreen)
        badge.position = CGPoint(x: 0, y: -10)
        leftPanel.addChild(badge)

        let station = multilineLabel("CHANNEL 13\nPOISON HELP TV", size: 8, color: GamePalette.offWhite, width: 120, lineHeight: 12)
        station.position = CGPoint(x: 0, y: -36)
        leftPanel.addChild(station)

        let phoneMini = multilineLabel("CALL\n1-800-222-1222", size: 8.5, color: GamePalette.warningYellow, width: 120, lineHeight: 12)
        phoneMini.position = CGPoint(x: 0, y: -76)
        leftPanel.addChild(phoneMini)

        let rightPanel = SKShapeNode(rectOf: CGSize(width: 350, height: 214), cornerRadius: 7)
        rightPanel.position = CGPoint(x: 88, y: 30)
        rightPanel.fillColor = SKColor.white.withAlphaComponent(0.03)
        rightPanel.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.3)
        rightPanel.lineWidth = 1
        card.addChild(rightPanel)

        let headline = label(level.psaLine, size: 17, color: GamePalette.yukGreen)
        headline.position = CGPoint(x: 0, y: 73)
        rightPanel.addChild(headline)

        let subhead = label(level.title, size: 9, color: GamePalette.warningYellow)
        subhead.position = CGPoint(x: 0, y: 52)
        rightPanel.addChild(subhead)

        let detail = multilineLabel(level.psaDetail, size: 10, color: GamePalette.offWhite, width: 310, lineHeight: 15)
        detail.position = CGPoint(x: 0, y: 8)
        rightPanel.addChild(detail)

        let whatToDoBand = SKShapeNode(rectOf: CGSize(width: 300, height: 20), cornerRadius: 3)
        whatToDoBand.position = CGPoint(x: 0, y: -52)
        whatToDoBand.fillColor = GamePalette.phosphorGreen.withAlphaComponent(0.10)
        whatToDoBand.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.36)
        whatToDoBand.lineWidth = 1
        rightPanel.addChild(whatToDoBand)

        let whatToDo = label("STOP • LOOK • DON'T TOUCH • GET HELP", size: 8, color: GamePalette.phosphorGreen)
        whatToDo.position = CGPoint(x: 0, y: -52)
        rightPanel.addChild(whatToDo)

        let scoreBand = SKShapeNode(rectOf: CGSize(width: 520, height: 34), cornerRadius: 5)
        scoreBand.position = CGPoint(x: 0, y: -114)
        scoreBand.fillColor = SKColor.white.withAlphaComponent(0.035)
        scoreBand.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.24)
        scoreBand.lineWidth = 1
        card.addChild(scoreBand)

        let bonus = label(String(format: "EPISODE CLEAR +1000   •   TIME BONUS +%04d", lastStageBonus), size: 9.2, color: GamePalette.phosphorGreen)
        bonus.position = CGPoint(x: 0, y: -107)
        card.addChild(bonus)

        let phone = label("POISON HELP  •  1-800-222-1222", size: 14, color: GamePalette.warningYellow)
        phone.position = CGPoint(x: 0, y: -140)
        card.addChild(phone)

        let emergency = label("IF SOMEONE COLLAPSES OR HAS TROUBLE BREATHING, CALL 911.", size: 8.2, color: GamePalette.dangerRed)
        emergency.position = CGPoint(x: 0, y: -165)
        card.addChild(emergency)

        let promptText = isFinalStage ? "PRESS RETURN FOR THE FINAL SIGN-OFF" : "PRESS RETURN FOR THE NEXT EPISODE"
        let promptBand = SKShapeNode(rectOf: CGSize(width: 380, height: 22), cornerRadius: 4)
        promptBand.position = CGPoint(x: 0, y: -186)
        promptBand.fillColor = GamePalette.yukGreen.withAlphaComponent(0.10)
        promptBand.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.42)
        promptBand.lineWidth = 1
        card.addChild(promptBand)

        let prompt = label(promptText, size: 9.3, color: GamePalette.yukGreen)
        prompt.position = CGPoint(x: 0, y: -186)
        prompt.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])))
        card.addChild(prompt)
    }

    private func advanceFromInterstitial() {
        if levelIndex < LevelBook.levels.count - 1 {
            levelIndex += 1
            loadLevel(levelIndex)
        } else {
            updateHighScoreIfNeeded()
            stopMusic()
            mode = .finished
            staticBurst(duration: 0.28)
            showOverlay(title: "REMEMBER MR. YUK!",
                        subtitle: String(format: "FINAL SCORE  %06d   •   HIGH SCORE  %06d\n\nSTOP • LOOK • DON'T TOUCH\n\nPOISON HELP  1-800-222-1222\n\nUNOFFICIAL RETRO GAME PROTOTYPE\nNOT AFFILIATED WITH POISON CONTROL OR MR. YUK'S OWNER\nNOT A SUBSTITUTE FOR PROFESSIONAL MEDICAL ADVICE\n\nPRESS RETURN TO PLAY AGAIN", score, highScore),
                        showLogo: true)
        }
    }

    // MARK: - World building

    private func clearWorld(keepPlayer: Bool) {
        for child in world.children where (!keepPlayer || child !== player) {
            child.removeFromParent()
        }
        if keepPlayer && player.parent == nil { world.addChild(player) }
        platforms.removeAll()
        ladders.removeAll()
        projectiles.removeAll()
    }

    private func buildBackdrop(levelNumber: Int, level: LevelDefinition) {
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 442))
        bg.fillColor = GamePalette.charcoal
        bg.strokeColor = .clear
        bg.zPosition = -30
        world.addChild(bg)

        switch level.theme {
        case .bathroom: buildBathroomBackdrop()
        case .garage: buildGarageBackdrop()
        case .basement: buildBasementBackdrop()
        case .kitchen: buildKitchenBackdrop()
        case .laundry: buildLaundryBackdrop()
        case .garden: buildGardenBackdrop()
        case .guestHouse: buildGuestHouseBackdrop()
        case .challenge: buildChallengeBackdrop()
        }

        let episode = label("PSA EPISODE \(levelNumber)", size: 11, color: GamePalette.warningYellow)
        episode.horizontalAlignmentMode = .left
        episode.position = CGPoint(x: 18, y: 418)
        episode.zPosition = -2
        world.addChild(episode)

        let name = label(level.channelTag, size: 10, color: GamePalette.phosphorGreen)
        name.horizontalAlignmentMode = .right
        name.position = CGPoint(x: 622, y: 418)
        name.zPosition = -2
        world.addChild(name)

        addPoisonHelpPoster()
        addDecorativeWarningStripes()
    }

    private func addBackdropBottle(at point: CGPoint, color: SKColor, size: CGSize = CGSize(width: 10, height: 18)) {
        let bottle = SKShapeNode(rectOf: size, cornerRadius: 2)
        bottle.position = point
        bottle.fillColor = color.withAlphaComponent(0.18)
        bottle.strokeColor = color.withAlphaComponent(0.28)
        bottle.lineWidth = 1
        bottle.zPosition = -18
        world.addChild(bottle)

        let cap = SKShapeNode(rectOf: CGSize(width: max(4, size.width * 0.45), height: 3), cornerRadius: 1)
        cap.position = CGPoint(x: point.x, y: point.y + size.height * 0.5 + 2)
        cap.fillColor = color.withAlphaComponent(0.30)
        cap.strokeColor = .clear
        cap.zPosition = -17
        world.addChild(cap)
    }

    private func addBackdropShelf(x: CGFloat, y: CGFloat, width: CGFloat, color: SKColor = GamePalette.offWhite) {
        let shelf = SKShapeNode(rect: CGRect(x: x, y: y, width: width, height: 5))
        shelf.fillColor = color.withAlphaComponent(0.12)
        shelf.strokeColor = color.withAlphaComponent(0.18)
        shelf.lineWidth = 1
        shelf.zPosition = -21
        world.addChild(shelf)

        for supportX in [x + 12, x + width - 16] {
            let support = SKShapeNode(rect: CGRect(x: supportX, y: y - 12, width: 4, height: 12))
            support.fillColor = color.withAlphaComponent(0.10)
            support.strokeColor = .clear
            support.zPosition = -22
            world.addChild(support)
        }
    }

    private func addBackdropSign(_ text: String, at point: CGPoint, width: CGFloat, accent: SKColor) {
        let sign = SKShapeNode(rectOf: CGSize(width: width, height: 24), cornerRadius: 3)
        sign.position = point
        sign.fillColor = SKColor.black.withAlphaComponent(0.20)
        sign.strokeColor = accent.withAlphaComponent(0.20)
        sign.lineWidth = 1
        sign.zPosition = -20
        world.addChild(sign)

        let signText = label(text, size: 6.5, color: accent.withAlphaComponent(0.30))
        signText.position = point
        signText.zPosition = -19
        world.addChild(signText)
    }

    private func buildBathroomBackdrop() {
        for x in stride(from: CGFloat(0), to: 640, by: 64) {
            for y in stride(from: CGFloat(32), to: 420, by: 48) {
                let tile = SKShapeNode(rect: CGRect(x: x + 1, y: y + 1, width: 62, height: 46))
                tile.fillColor = GamePalette.tileBlue.withAlphaComponent(0.18)
                tile.strokeColor = GamePalette.offWhite.withAlphaComponent(0.08)
                tile.lineWidth = 1
                tile.zPosition = -26
                world.addChild(tile)
            }
        }

        let cabinetBody = SKShapeNode(rectOf: CGSize(width: 122, height: 84), cornerRadius: 4)
        cabinetBody.position = CGPoint(x: 320, y: 320)
        cabinetBody.fillColor = SKColor(hex: 0x516860, alpha: 0.18)
        cabinetBody.strokeColor = GamePalette.offWhite.withAlphaComponent(0.22)
        cabinetBody.lineWidth = 2
        cabinetBody.zPosition = -20
        world.addChild(cabinetBody)

        let cabinetHeader = SKShapeNode(rectOf: CGSize(width: 116, height: 14), cornerRadius: 2)
        cabinetHeader.position = CGPoint(x: 320, y: 354)
        cabinetHeader.fillColor = GamePalette.warningYellow.withAlphaComponent(0.10)
        cabinetHeader.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.18)
        cabinetHeader.lineWidth = 1
        cabinetHeader.zPosition = -19
        world.addChild(cabinetHeader)

        let cabinetCross = SKShapeNode(rect: CGRect(x: 319, y: 282, width: 2, height: 76))
        cabinetCross.fillColor = GamePalette.offWhite.withAlphaComponent(0.18)
        cabinetCross.strokeColor = .clear
        cabinetCross.zPosition = -19
        world.addChild(cabinetCross)

        let cabinetShelf = SKShapeNode(rect: CGRect(x: 266, y: 319, width: 108, height: 2))
        cabinetShelf.fillColor = GamePalette.offWhite.withAlphaComponent(0.14)
        cabinetShelf.strokeColor = .clear
        cabinetShelf.zPosition = -19
        world.addChild(cabinetShelf)

        for (x, y, color) in [(292.0, 336.0, GamePalette.warningYellow), (348.0, 336.0, GamePalette.phosphorGreen), (292.0, 304.0, GamePalette.offWhite), (348.0, 304.0, GamePalette.tileBlue)] as [(Double, Double, SKColor)] {
            let bottle = SKShapeNode(rectOf: CGSize(width: 10, height: 18), cornerRadius: 2)
            bottle.position = CGPoint(x: x, y: y)
            bottle.fillColor = color.withAlphaComponent(0.22)
            bottle.strokeColor = color.withAlphaComponent(0.28)
            bottle.lineWidth = 1
            bottle.zPosition = -18
            world.addChild(bottle)
        }

        let wallSign = SKShapeNode(rectOf: CGSize(width: 92, height: 24), cornerRadius: 3)
        wallSign.position = CGPoint(x: 320, y: 250)
        wallSign.fillColor = GamePalette.offWhite.withAlphaComponent(0.05)
        wallSign.strokeColor = GamePalette.offWhite.withAlphaComponent(0.16)
        wallSign.lineWidth = 1
        wallSign.zPosition = -20
        world.addChild(wallSign)

        let sinkTop = SKShapeNode(rectOf: CGSize(width: 136, height: 12), cornerRadius: 6)
        sinkTop.position = CGPoint(x: 320, y: 86)
        sinkTop.fillColor = GamePalette.offWhite.withAlphaComponent(0.10)
        sinkTop.strokeColor = GamePalette.offWhite.withAlphaComponent(0.20)
        sinkTop.lineWidth = 1
        sinkTop.zPosition = -22
        world.addChild(sinkTop)

        let sinkBasin = SKShapeNode(rectOf: CGSize(width: 72, height: 10), cornerRadius: 5)
        sinkBasin.position = CGPoint(x: 320, y: 79)
        sinkBasin.fillColor = GamePalette.tileBlue.withAlphaComponent(0.10)
        sinkBasin.strokeColor = GamePalette.offWhite.withAlphaComponent(0.14)
        sinkBasin.lineWidth = 1
        sinkBasin.zPosition = -22
        world.addChild(sinkBasin)

        let faucetStem = SKShapeNode(rect: CGRect(x: 316, y: 96, width: 8, height: 26))
        faucetStem.fillColor = SKColor.gray.withAlphaComponent(0.22)
        faucetStem.strokeColor = .clear
        faucetStem.zPosition = -22
        world.addChild(faucetStem)

        let faucetHead = SKShapeNode(rectOf: CGSize(width: 26, height: 6), cornerRadius: 3)
        faucetHead.position = CGPoint(x: 327, y: 122)
        faucetHead.fillColor = SKColor.gray.withAlphaComponent(0.22)
        faucetHead.strokeColor = .clear
        faucetHead.zPosition = -22
        world.addChild(faucetHead)
    }

    private func buildGarageBackdrop() {
        for y in stride(from: CGFloat(38), to: 420, by: 32) {
            let seam = SKShapeNode(rect: CGRect(x: 0, y: y, width: 640, height: 1))
            seam.fillColor = SKColor.white.withAlphaComponent(0.035)
            seam.strokeColor = .clear
            seam.zPosition = -27
            world.addChild(seam)
        }

        for x in stride(from: CGFloat(18), to: 360, by: 36) {
            for y in stride(from: CGFloat(82), to: 390, by: 28) {
                let peg = SKShapeNode(circleOfRadius: 1.05)
                peg.position = CGPoint(x: x, y: y)
                peg.fillColor = GamePalette.warningYellow.withAlphaComponent(0.075)
                peg.strokeColor = .clear
                peg.zPosition = -26
                world.addChild(peg)
            }
        }

        let garageDoor = SKShapeNode(rect: CGRect(x: 394, y: 64, width: 214, height: 304))
        garageDoor.fillColor = SKColor(hex: 0x242B27, alpha: 0.42)
        garageDoor.strokeColor = GamePalette.offWhite.withAlphaComponent(0.10)
        garageDoor.lineWidth = 2
        garageDoor.zPosition = -25
        world.addChild(garageDoor)
        for y in stride(from: CGFloat(100), to: 350, by: 42) {
            let band = SKShapeNode(rect: CGRect(x: 396, y: y, width: 210, height: 2))
            band.fillColor = GamePalette.offWhite.withAlphaComponent(0.08)
            band.strokeColor = .clear
            band.zPosition = -24
            world.addChild(band)
        }

        addBackdropShelf(x: 34, y: 320, width: 274, color: GamePalette.warningYellow)
        addBackdropShelf(x: 34, y: 236, width: 274, color: GamePalette.offWhite)
        for item in [
            (CGPoint(x: 66, y: 337), GamePalette.dangerRed),
            (CGPoint(x: 104, y: 337), GamePalette.cleanerBlue),
            (CGPoint(x: 144, y: 337), GamePalette.warningYellow),
            (CGPoint(x: 224, y: 253), GamePalette.medicinePink),
            (CGPoint(x: 266, y: 253), GamePalette.phosphorGreen)
        ] { addBackdropBottle(at: item.0, color: item.1) }

        let toolbox = SKShapeNode(rectOf: CGSize(width: 110, height: 54), cornerRadius: 5)
        toolbox.position = CGPoint(x: 98, y: 92)
        toolbox.fillColor = GamePalette.dangerRed.withAlphaComponent(0.16)
        toolbox.strokeColor = GamePalette.dangerRed.withAlphaComponent(0.28)
        toolbox.lineWidth = 2
        toolbox.zPosition = -23
        world.addChild(toolbox)
        let handle = SKShapeNode(rectOf: CGSize(width: 42, height: 8), cornerRadius: 3)
        handle.position = CGPoint(x: 98, y: 124)
        handle.fillColor = .clear
        handle.strokeColor = GamePalette.offWhite.withAlphaComponent(0.18)
        handle.lineWidth = 2
        handle.zPosition = -22
        world.addChild(handle)

        let tireOuter = SKShapeNode(circleOfRadius: 31)
        tireOuter.position = CGPoint(x: 316, y: 91)
        tireOuter.fillColor = SKColor.black.withAlphaComponent(0.20)
        tireOuter.strokeColor = GamePalette.offWhite.withAlphaComponent(0.12)
        tireOuter.lineWidth = 7
        tireOuter.zPosition = -23
        world.addChild(tireOuter)
        let tireInner = SKShapeNode(circleOfRadius: 12)
        tireInner.position = tireOuter.position
        tireInner.fillColor = .clear
        tireInner.strokeColor = GamePalette.offWhite.withAlphaComponent(0.10)
        tireInner.lineWidth = 3
        tireInner.zPosition = -22
        world.addChild(tireInner)

        addBackdropSign("LOCK IT UP", at: CGPoint(x: 174, y: 386), width: 118, accent: GamePalette.warningYellow)
    }

    private func buildBasementBackdrop() {
        for row in 0..<11 {
            let y = CGFloat(44 + row * 34)
            let offset: CGFloat = row % 2 == 0 ? 0 : 28
            for x in stride(from: -offset, to: 640, by: 56) {
                let brick = SKShapeNode(rect: CGRect(x: x, y: y, width: 54, height: 32))
                brick.fillColor = GamePalette.brown.withAlphaComponent(0.085)
                brick.strokeColor = GamePalette.offWhite.withAlphaComponent(0.03)
                brick.lineWidth = 1
                brick.zPosition = -27
                world.addChild(brick)
            }
        }

        let pipe = SKShapeNode(rect: CGRect(x: 38, y: 70, width: 13, height: 320))
        pipe.fillColor = GamePalette.cleanerBlue.withAlphaComponent(0.11)
        pipe.strokeColor = GamePalette.cleanerBlue.withAlphaComponent(0.20)
        pipe.lineWidth = 2
        pipe.zPosition = -22
        world.addChild(pipe)
        for y in stride(from: CGFloat(92), to: 370, by: 74) {
            let collar = SKShapeNode(rect: CGRect(x: 34, y: y, width: 21, height: 6))
            collar.fillColor = GamePalette.offWhite.withAlphaComponent(0.10)
            collar.strokeColor = .clear
            collar.zPosition = -21
            world.addChild(collar)
        }

        let boiler = SKShapeNode(rectOf: CGSize(width: 110, height: 146), cornerRadius: 14)
        boiler.position = CGPoint(x: 554, y: 160)
        boiler.fillColor = SKColor.gray.withAlphaComponent(0.10)
        boiler.strokeColor = GamePalette.offWhite.withAlphaComponent(0.15)
        boiler.lineWidth = 2
        boiler.zPosition = -23
        world.addChild(boiler)
        let boilerBand = SKShapeNode(rect: CGRect(x: 503, y: 134, width: 102, height: 8))
        boilerBand.fillColor = GamePalette.warningYellow.withAlphaComponent(0.07)
        boilerBand.strokeColor = .clear
        boilerBand.zPosition = -22
        world.addChild(boilerBand)
        let gauge = SKShapeNode(circleOfRadius: 16)
        gauge.position = CGPoint(x: 554, y: 203)
        gauge.fillColor = SKColor.black.withAlphaComponent(0.18)
        gauge.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.23)
        gauge.lineWidth = 2
        gauge.zPosition = -22
        world.addChild(gauge)

        addBackdropShelf(x: 92, y: 322, width: 244, color: GamePalette.offWhite)
        addBackdropShelf(x: 92, y: 250, width: 244, color: GamePalette.offWhite)
        for rect in [CGRect(x: 110, y: 327, width: 48, height: 34), CGRect(x: 178, y: 327, width: 58, height: 34), CGRect(x: 256, y: 327, width: 58, height: 34), CGRect(x: 128, y: 255, width: 64, height: 36), CGRect(x: 214, y: 255, width: 78, height: 36)] {
            let crate = SKShapeNode(rect: rect)
            crate.fillColor = GamePalette.brown.withAlphaComponent(0.11)
            crate.strokeColor = GamePalette.offWhite.withAlphaComponent(0.08)
            crate.lineWidth = 1
            crate.zPosition = -20
            world.addChild(crate)
        }
        addBackdropBottle(at: CGPoint(x: 372, y: 118), color: GamePalette.warningYellow, size: CGSize(width: 12, height: 24))
        addBackdropBottle(at: CGPoint(x: 396, y: 118), color: GamePalette.dangerRed, size: CGSize(width: 12, height: 24))
        addBackdropSign("STORAGE ONLY", at: CGPoint(x: 214, y: 390), width: 132, accent: GamePalette.phosphorGreen)
    }

    private func buildKitchenBackdrop() {
        for x in stride(from: CGFloat(0), to: 640, by: 32) {
            for y in stride(from: CGFloat(88), to: 420, by: 32) {
                let checker = SKShapeNode(rect: CGRect(x: x, y: y, width: 31, height: 31))
                let alternate = (Int(x / 32) + Int(y / 32)) % 2 == 0
                checker.fillColor = (alternate ? GamePalette.kitchenCream : GamePalette.tileBlue).withAlphaComponent(0.055)
                checker.strokeColor = .clear
                checker.zPosition = -27
                world.addChild(checker)
            }
        }

        let counter = SKShapeNode(rect: CGRect(x: 34, y: 92, width: 572, height: 18))
        counter.fillColor = GamePalette.kitchenCream.withAlphaComponent(0.08)
        counter.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.14)
        counter.lineWidth = 1
        counter.zPosition = -23
        world.addChild(counter)

        for x in [CGFloat(66), 176, 464, 574] {
            let cabinet = SKShapeNode(rectOf: CGSize(width: 92, height: 80), cornerRadius: 3)
            cabinet.position = CGPoint(x: x, y: 365)
            cabinet.fillColor = GamePalette.brown.withAlphaComponent(0.11)
            cabinet.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.16)
            cabinet.lineWidth = 2
            cabinet.zPosition = -23
            world.addChild(cabinet)
            let panel = SKShapeNode(rectOf: CGSize(width: 68, height: 56), cornerRadius: 2)
            panel.position = CGPoint(x: x, y: 365)
            panel.fillColor = .clear
            panel.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.08)
            panel.lineWidth = 1
            panel.zPosition = -22
            world.addChild(panel)
            let knob = SKShapeNode(circleOfRadius: 2.3)
            knob.position = CGPoint(x: x + 27, y: 365)
            knob.fillColor = GamePalette.warningYellow.withAlphaComponent(0.28)
            knob.strokeColor = .clear
            knob.zPosition = -22
            world.addChild(knob)
        }

        let fridge = SKShapeNode(rectOf: CGSize(width: 96, height: 210), cornerRadius: 7)
        fridge.position = CGPoint(x: 320, y: 176)
        fridge.fillColor = GamePalette.offWhite.withAlphaComponent(0.065)
        fridge.strokeColor = GamePalette.offWhite.withAlphaComponent(0.15)
        fridge.lineWidth = 2
        fridge.zPosition = -24
        world.addChild(fridge)
        let divider = SKShapeNode(rect: CGRect(x: 275, y: 198, width: 90, height: 2))
        divider.fillColor = GamePalette.offWhite.withAlphaComponent(0.11)
        divider.strokeColor = .clear
        divider.zPosition = -23
        world.addChild(divider)
        let handle = SKShapeNode(rectOf: CGSize(width: 5, height: 54), cornerRadius: 2)
        handle.position = CGPoint(x: 352, y: 188)
        handle.fillColor = GamePalette.offWhite.withAlphaComponent(0.16)
        handle.strokeColor = .clear
        handle.zPosition = -22
        world.addChild(handle)

        let toaster = SKShapeNode(rectOf: CGSize(width: 44, height: 24), cornerRadius: 6)
        toaster.position = CGPoint(x: 112, y: 124)
        toaster.fillColor = SKColor.gray.withAlphaComponent(0.09)
        toaster.strokeColor = GamePalette.offWhite.withAlphaComponent(0.12)
        toaster.lineWidth = 1
        toaster.zPosition = -21
        world.addChild(toaster)
        addBackdropBottle(at: CGPoint(x: 500, y: 126), color: GamePalette.cleanerBlue, size: CGSize(width: 12, height: 24))
        addBackdropBottle(at: CGPoint(x: 528, y: 126), color: GamePalette.warningYellow, size: CGSize(width: 12, height: 24))
        addBackdropSign("NOT WITH FOOD", at: CGPoint(x: 320, y: 390), width: 132, accent: GamePalette.warningYellow)
    }

    private func buildLaundryBackdrop() {
        for y in stride(from: CGFloat(56), to: 420, by: 44) {
            let seam = SKShapeNode(rect: CGRect(x: 0, y: y, width: 640, height: 1))
            seam.fillColor = GamePalette.cleanerBlue.withAlphaComponent(0.045)
            seam.strokeColor = .clear
            seam.zPosition = -27
            world.addChild(seam)
        }

        for x in [CGFloat(116), 524] {
            let appliance = SKShapeNode(rectOf: CGSize(width: 108, height: 122), cornerRadius: 9)
            appliance.position = CGPoint(x: x, y: 122)
            appliance.fillColor = GamePalette.offWhite.withAlphaComponent(0.055)
            appliance.strokeColor = GamePalette.cleanerBlue.withAlphaComponent(0.18)
            appliance.lineWidth = 2
            appliance.zPosition = -24
            world.addChild(appliance)

            let control = SKShapeNode(rectOf: CGSize(width: 92, height: 18), cornerRadius: 4)
            control.position = CGPoint(x: x, y: 164)
            control.fillColor = SKColor.black.withAlphaComponent(0.10)
            control.strokeColor = GamePalette.offWhite.withAlphaComponent(0.10)
            control.lineWidth = 1
            control.zPosition = -23
            world.addChild(control)
            for dx in [CGFloat(-28), 0, 28] {
                let knob = SKShapeNode(circleOfRadius: 3)
                knob.position = CGPoint(x: x + dx, y: 164)
                knob.fillColor = GamePalette.offWhite.withAlphaComponent(0.14)
                knob.strokeColor = .clear
                knob.zPosition = -22
                world.addChild(knob)
            }

            let door = SKShapeNode(circleOfRadius: 31)
            door.position = CGPoint(x: x, y: 112)
            door.fillColor = GamePalette.tileBlue.withAlphaComponent(0.075)
            door.strokeColor = GamePalette.offWhite.withAlphaComponent(0.16)
            door.lineWidth = 3
            door.zPosition = -23
            world.addChild(door)
            let doorInner = SKShapeNode(circleOfRadius: 22)
            doorInner.position = door.position
            doorInner.fillColor = .clear
            doorInner.strokeColor = GamePalette.cleanerBlue.withAlphaComponent(0.12)
            doorInner.lineWidth = 2
            doorInner.zPosition = -22
            world.addChild(doorInner)
        }

        addBackdropShelf(x: 196, y: 334, width: 248, color: GamePalette.offWhite)
        for item in [
            (CGPoint(x: 230, y: 352), GamePalette.cleanerBlue),
            (CGPoint(x: 270, y: 352), GamePalette.warningYellow),
            (CGPoint(x: 310, y: 352), GamePalette.medicinePink),
            (CGPoint(x: 350, y: 352), GamePalette.cleanerBlue),
            (CGPoint(x: 390, y: 352), GamePalette.phosphorGreen)
        ] { addBackdropBottle(at: item.0, color: item.1, size: CGSize(width: 13, height: 24)) }

        let basket = SKShapeNode(rectOf: CGSize(width: 82, height: 40), cornerRadius: 5)
        basket.position = CGPoint(x: 320, y: 88)
        basket.fillColor = GamePalette.kitchenCream.withAlphaComponent(0.07)
        basket.strokeColor = GamePalette.offWhite.withAlphaComponent(0.12)
        basket.lineWidth = 1
        basket.zPosition = -23
        world.addChild(basket)
        for dx in stride(from: CGFloat(-28), through: 28, by: 14) {
            let slat = SKShapeNode(rect: CGRect(x: 319 + dx, y: 72, width: 2, height: 32))
            slat.fillColor = GamePalette.offWhite.withAlphaComponent(0.07)
            slat.strokeColor = .clear
            slat.zPosition = -22
            world.addChild(slat)
        }
        addBackdropSign("LOCK UP PODS & CLEANERS", at: CGPoint(x: 320, y: 398), width: 188, accent: GamePalette.warningYellow)
    }

    private func buildGardenBackdrop() {
        for x in stride(from: CGFloat(10), to: 640, by: 46) {
            let plank = SKShapeNode(rect: CGRect(x: x, y: 40, width: 2, height: 378))
            plank.fillColor = GamePalette.brown.withAlphaComponent(0.085)
            plank.strokeColor = .clear
            plank.zPosition = -28
            world.addChild(plank)
        }

        let window = SKShapeNode(rect: CGRect(x: 244, y: 286, width: 152, height: 92))
        window.fillColor = GamePalette.cleanerBlue.withAlphaComponent(0.055)
        window.strokeColor = GamePalette.offWhite.withAlphaComponent(0.15)
        window.lineWidth = 2
        window.zPosition = -25
        world.addChild(window)
        let windowV = SKShapeNode(rect: CGRect(x: 319, y: 288, width: 2, height: 88))
        windowV.fillColor = GamePalette.offWhite.withAlphaComponent(0.12)
        windowV.strokeColor = .clear
        windowV.zPosition = -24
        world.addChild(windowV)
        let windowH = SKShapeNode(rect: CGRect(x: 246, y: 331, width: 148, height: 2))
        windowH.fillColor = GamePalette.offWhite.withAlphaComponent(0.12)
        windowH.strokeColor = .clear
        windowH.zPosition = -24
        world.addChild(windowH)

        addBackdropShelf(x: 34, y: 250, width: 184, color: GamePalette.warningYellow)
        addBackdropBottle(at: CGPoint(x: 70, y: 270), color: GamePalette.warningYellow, size: CGSize(width: 14, height: 28))
        addBackdropBottle(at: CGPoint(x: 110, y: 270), color: GamePalette.dangerRed, size: CGSize(width: 14, height: 28))
        addBackdropBottle(at: CGPoint(x: 154, y: 270), color: GamePalette.cleanerBlue, size: CGSize(width: 14, height: 28))

        for x in [CGFloat(82), 558] {
            let pot = SKShapeNode(rectOf: CGSize(width: 52, height: 30), cornerRadius: 5)
            pot.position = CGPoint(x: x, y: 84)
            pot.fillColor = GamePalette.brown.withAlphaComponent(0.15)
            pot.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.12)
            pot.zPosition = -23
            world.addChild(pot)
            let stem = SKShapeNode(rect: CGRect(x: x - 2, y: 100, width: 4, height: 46))
            stem.fillColor = GamePalette.yukGreen.withAlphaComponent(0.11)
            stem.strokeColor = .clear
            stem.zPosition = -24
            world.addChild(stem)
            for offset in [-12.0, 12.0] {
                let leaf = SKShapeNode(ellipseOf: CGSize(width: 18, height: 8))
                leaf.position = CGPoint(x: x + offset, y: 132)
                leaf.zRotation = offset < 0 ? -0.45 : 0.45
                leaf.fillColor = GamePalette.yukGreen.withAlphaComponent(0.08)
                leaf.strokeColor = .clear
                leaf.zPosition = -24
                world.addChild(leaf)
            }
        }

        for (x, angle) in [(CGFloat(470), CGFloat(-0.22)), (CGFloat(510), CGFloat(0.16))] {
            let handle = SKShapeNode(rectOf: CGSize(width: 5, height: 128), cornerRadius: 2)
            handle.position = CGPoint(x: x, y: 222)
            handle.zRotation = angle
            handle.fillColor = GamePalette.brown.withAlphaComponent(0.16)
            handle.strokeColor = .clear
            handle.zPosition = -24
            world.addChild(handle)
        }
        let rake = SKShapeNode(rectOf: CGSize(width: 44, height: 7), cornerRadius: 2)
        rake.position = CGPoint(x: 454, y: 281)
        rake.zRotation = -0.22
        rake.fillColor = GamePalette.offWhite.withAlphaComponent(0.12)
        rake.strokeColor = .clear
        rake.zPosition = -23
        world.addChild(rake)
        addBackdropSign("SHED CHEMICALS • KEEP LOCKED", at: CGPoint(x: 320, y: 398), width: 204, accent: GamePalette.warningYellow)
    }

    private func buildGuestHouseBackdrop() {
        for x in stride(from: CGFloat(0), to: 640, by: 48) {
            let strip = SKShapeNode(rect: CGRect(x: x, y: 38, width: 24, height: 380))
            strip.fillColor = (Int(x / 48) % 2 == 0 ? GamePalette.medicinePink : GamePalette.tileBlue).withAlphaComponent(0.028)
            strip.strokeColor = .clear
            strip.zPosition = -28
            world.addChild(strip)
        }

        let baseboard = SKShapeNode(rect: CGRect(x: 0, y: 72, width: 640, height: 6))
        baseboard.fillColor = GamePalette.kitchenCream.withAlphaComponent(0.07)
        baseboard.strokeColor = .clear
        baseboard.zPosition = -26
        world.addChild(baseboard)

        let cupboard = SKShapeNode(rectOf: CGSize(width: 144, height: 126), cornerRadius: 6)
        cupboard.position = CGPoint(x: 520, y: 164)
        cupboard.fillColor = GamePalette.brown.withAlphaComponent(0.10)
        cupboard.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.14)
        cupboard.lineWidth = 2
        cupboard.zPosition = -24
        world.addChild(cupboard)
        let cupboardSplit = SKShapeNode(rect: CGRect(x: 519, y: 104, width: 2, height: 120))
        cupboardSplit.fillColor = GamePalette.kitchenCream.withAlphaComponent(0.10)
        cupboardSplit.strokeColor = .clear
        cupboardSplit.zPosition = -23
        world.addChild(cupboardSplit)
        for x in [CGFloat(492), 548] {
            let knob = SKShapeNode(circleOfRadius: 2.5)
            knob.position = CGPoint(x: x, y: 164)
            knob.fillColor = GamePalette.warningYellow.withAlphaComponent(0.22)
            knob.strokeColor = .clear
            knob.zPosition = -22
            world.addChild(knob)
        }

        let tableTop = SKShapeNode(rect: CGRect(x: 54, y: 92, width: 130, height: 10))
        tableTop.fillColor = GamePalette.brown.withAlphaComponent(0.13)
        tableTop.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.10)
        tableTop.lineWidth = 1
        tableTop.zPosition = -24
        world.addChild(tableTop)
        for x in [CGFloat(68), 168] {
            let leg = SKShapeNode(rect: CGRect(x: x, y: 58, width: 6, height: 34))
            leg.fillColor = GamePalette.brown.withAlphaComponent(0.11)
            leg.strokeColor = .clear
            leg.zPosition = -24
            world.addChild(leg)
        }
        let lampStem = SKShapeNode(rect: CGRect(x: 114, y: 102, width: 4, height: 34))
        lampStem.fillColor = GamePalette.offWhite.withAlphaComponent(0.10)
        lampStem.strokeColor = .clear
        lampStem.zPosition = -23
        world.addChild(lampStem)
        let lampShade = SKShapeNode(path: {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 98, y: 136)); p.addLine(to: CGPoint(x: 134, y: 136)); p.addLine(to: CGPoint(x: 128, y: 154)); p.addLine(to: CGPoint(x: 104, y: 154)); p.closeSubpath(); return p
        }())
        lampShade.fillColor = GamePalette.warningYellow.withAlphaComponent(0.08)
        lampShade.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.10)
        lampShade.lineWidth = 1
        lampShade.zPosition = -23
        world.addChild(lampShade)

        for point in [CGPoint(x: 236, y: 342), CGPoint(x: 338, y: 342)] {
            let frame = SKShapeNode(rectOf: CGSize(width: 70, height: 52), cornerRadius: 3)
            frame.position = point
            frame.fillColor = SKColor.black.withAlphaComponent(0.08)
            frame.strokeColor = GamePalette.kitchenCream.withAlphaComponent(0.10)
            frame.lineWidth = 1
            frame.zPosition = -24
            world.addChild(frame)
        }
        addBackdropSign("ASK BEFORE YOU TOUCH", at: CGPoint(x: 320, y: 398), width: 176, accent: GamePalette.phosphorGreen)
    }

    private func buildChallengeBackdrop() {
        for x in stride(from: CGFloat(0), through: 640, by: 40) {
            let v = SKShapeNode(rect: CGRect(x: x, y: 32, width: 1, height: 390))
            v.fillColor = GamePalette.yukGreen.withAlphaComponent(0.035)
            v.strokeColor = .clear
            v.zPosition = -29
            world.addChild(v)
        }
        for y in stride(from: CGFloat(42), through: 420, by: 40) {
            let h = SKShapeNode(rect: CGRect(x: 0, y: y, width: 640, height: 1))
            h.fillColor = GamePalette.warningYellow.withAlphaComponent(0.03)
            h.strokeColor = .clear
            h.zPosition = -29
            world.addChild(h)
        }

        let trainingPanel = SKShapeNode(rectOf: CGSize(width: 250, height: 118), cornerRadius: 8)
        trainingPanel.position = CGPoint(x: 320, y: 238)
        trainingPanel.fillColor = SKColor.black.withAlphaComponent(0.14)
        trainingPanel.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.10)
        trainingPanel.lineWidth = 2
        trainingPanel.zPosition = -25
        world.addChild(trainingPanel)

        let warning = label("FINAL SAFETY TEST", size: 24, color: GamePalette.yukGreen.withAlphaComponent(0.11))
        warning.position = CGPoint(x: 320, y: 254)
        warning.zPosition = -24
        world.addChild(warning)
        let sub = label("STOP • LOOK • DON'T TOUCH", size: 8, color: GamePalette.warningYellow.withAlphaComponent(0.12))
        sub.position = CGPoint(x: 320, y: 222)
        sub.zPosition = -24
        world.addChild(sub)

        for (point, color) in [
            (CGPoint(x: 92, y: 360), GamePalette.medicinePink),
            (CGPoint(x: 548, y: 360), GamePalette.cleanerBlue),
            (CGPoint(x: 92, y: 110), GamePalette.warningYellow),
            (CGPoint(x: 548, y: 110), GamePalette.dangerRed)
        ] {
            let station = SKShapeNode(rectOf: CGSize(width: 78, height: 50), cornerRadius: 6)
            station.position = point
            station.fillColor = color.withAlphaComponent(0.035)
            station.strokeColor = color.withAlphaComponent(0.10)
            station.lineWidth = 2
            station.zPosition = -25
            world.addChild(station)
            let light = SKShapeNode(circleOfRadius: 7)
            light.position = CGPoint(x: point.x, y: point.y + 8)
            light.fillColor = color.withAlphaComponent(0.10)
            light.strokeColor = .clear
            light.zPosition = -24
            world.addChild(light)
        }

        for y in [84.0, 392.0] {
            for x in stride(from: CGFloat(28), to: 620, by: 32) {
                let stripe = SKShapeNode(rectOf: CGSize(width: 20, height: 5))
                stripe.position = CGPoint(x: x, y: y)
                stripe.zRotation = -.pi / 4
                stripe.fillColor = GamePalette.warningYellow.withAlphaComponent(0.08)
                stripe.strokeColor = .clear
                stripe.zPosition = -25
                world.addChild(stripe)
            }
        }
        addBackdropSign("POISON CONTROL CHALLENGE", at: CGPoint(x: 320, y: 398), width: 208, accent: GamePalette.yukGreen)
    }

    private func addPoisonHelpPoster() {
        let poster = SKShapeNode(rectOf: CGSize(width: 142, height: 42), cornerRadius: 2)
        poster.position = CGPoint(x: 320, y: 35)
        poster.fillColor = SKColor.black.withAlphaComponent(0.72)
        poster.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.55)
        poster.lineWidth = 1
        poster.zPosition = -4
        world.addChild(poster)

        let top = label("POISON HELP", size: 8, color: GamePalette.yukGreen)
        top.position.y = 8
        poster.addChild(top)
        let phone = label("1-800-222-1222", size: 8, color: GamePalette.offWhite)
        phone.position.y = -8
        poster.addChild(phone)
    }

    private func addDecorativeWarningStripes() {
        for x in stride(from: CGFloat(0), to: 640, by: 32) {
            let stripe = SKShapeNode(rectOf: CGSize(width: 20, height: 5))
            stripe.position = CGPoint(x: x, y: 18)
            stripe.zRotation = .pi / 4
            stripe.fillColor = GamePalette.warningYellow.withAlphaComponent(0.18)
            stripe.strokeColor = .clear
            stripe.zPosition = -5
            world.addChild(stripe)
        }
    }

    private func addPlatform(_ rect: CGRect) {
        let node = SKShapeNode(rect: rect)
        node.fillColor = GamePalette.nearBlack.withAlphaComponent(0.96)
        node.strokeColor = GamePalette.yukGreen
        node.lineWidth = 2
        node.zPosition = 0
        world.addChild(node)

        let lip = SKShapeNode(rect: CGRect(x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3))
        lip.fillColor = GamePalette.warningYellow.withAlphaComponent(0.5)
        lip.strokeColor = .clear
        lip.zPosition = 1
        world.addChild(lip)

        for x in stride(from: rect.minX + 10, to: rect.maxX, by: 24) {
            let rivet = SKShapeNode(circleOfRadius: 1)
            rivet.position = CGPoint(x: x, y: rect.midY - 2)
            rivet.fillColor = GamePalette.offWhite.withAlphaComponent(0.18)
            rivet.strokeColor = .clear
            rivet.zPosition = 2
            world.addChild(rivet)
        }
    }

    private func addLadder(_ rect: CGRect) {
        let group = SKNode()
        group.zPosition = 2
        let left = SKShapeNode(rect: CGRect(x: rect.minX + 5, y: rect.minY, width: 3, height: rect.height))
        let right = SKShapeNode(rect: CGRect(x: rect.maxX - 8, y: rect.minY, width: 3, height: rect.height))
        for rail in [left, right] {
            rail.fillColor = GamePalette.phosphorGreen
            rail.strokeColor = .clear
            group.addChild(rail)
        }
        for y in stride(from: rect.minY + 6, through: rect.maxY - 2, by: 12) {
            let rung = SKShapeNode(rect: CGRect(x: rect.minX + 5, y: y, width: rect.width - 10, height: 2))
            rung.fillColor = GamePalette.phosphorGreen
            rung.strokeColor = .clear
            group.addChild(rung)
        }
        world.addChild(group)
    }

    // MARK: - Hazards / enemies

    private func addHazard(_ spec: HazardSpec) {
        let sprite = SKSpriteNode(texture: texture("\(spec.kind.texturePrefix)1"), size: CGSize(width: 34, height: 34))
        sprite.texture?.filteringMode = .nearest
        let node = HazardNode(kind: spec.kind, sprite: sprite)
        node.position = spec.position
        node.zPosition = 12
        node.name = spec.kind.rawValue
        node.addChild(sprite)

        let glow = SKShapeNode(circleOfRadius: 21)
        glow.fillColor = GamePalette.warningYellow.withAlphaComponent(0.035)
        glow.strokeColor = GamePalette.warningYellow.withAlphaComponent(0.14)
        glow.lineWidth = 1
        glow.zPosition = -1
        node.addChild(glow)

        let caption = label(spec.kind.rawValue, size: 6.5, color: GamePalette.warningYellow)
        caption.position = CGPoint(x: 0, y: -24)
        node.addChild(caption)

        let frames = [texture("\(spec.kind.texturePrefix)1"), texture("\(spec.kind.texturePrefix)2")]
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.28, resize: false, restore: false)), withKey: "hazardAnim")
        node.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.36),
            .moveBy(x: 0, y: -2, duration: 0.36)
        ])), withKey: "bob")

        hazards.append(node)
        world.addChild(node)
    }

    private func addEnemy(_ spec: EnemySpec) {
        let sprite = SKSpriteNode(texture: texture("\(spec.kind.texturePrefix)1"), size: CGSize(width: 36, height: 36))
        sprite.texture?.filteringMode = .nearest
        let enemy = EnemyNode(kind: spec.kind, sprite: sprite, minX: spec.minX, maxX: spec.maxX, speed: spec.speed)
        enemy.position = CGPoint(x: spec.startX, y: spec.y)
        enemy.direction = Bool.random() ? 1 : -1
        enemy.zPosition = 14

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 24, height: 6))
        shadow.fillColor = .black.withAlphaComponent(0.42)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -17)
        shadow.zPosition = -1
        enemy.addChild(shadow)
        enemy.addChild(sprite)

        startEnemyWalkAnimation(enemy)

        enemies.append(enemy)
        world.addChild(enemy)
    }

    private func startEnemyWalkAnimation(_ enemy: EnemyNode) {
        let frames = textures([
            "\(enemy.kind.texturePrefix)1",
            "\(enemy.kind.texturePrefix)2",
            "\(enemy.kind.texturePrefix)3",
            "\(enemy.kind.texturePrefix)4"
        ])
        enemy.sprite.removeAction(forKey: "enemyStunPulse")
        enemy.sprite.zRotation = 0
        enemy.sprite.yScale = 1
        if enemy.sprite.action(forKey: "enemyAnim") == nil {
            enemy.sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.17, resize: false, restore: false)), withKey: "enemyAnim")
        }
    }

    private func startEnemyStunnedVisual(_ enemy: EnemyNode) {
        enemy.sprite.removeAction(forKey: "enemyAnim")
        enemy.sprite.texture = texture("\(enemy.kind.texturePrefix)Stunned")
        if enemy.sprite.action(forKey: "enemyStunPulse") == nil {
            enemy.sprite.run(.repeatForever(.sequence([
                .group([.rotate(toAngle: 0.1, duration: 0.12), .scaleY(to: 0.9, duration: 0.12)]),
                .group([.rotate(toAngle: -0.1, duration: 0.12), .scaleY(to: 1.0, duration: 0.12)])
            ])), withKey: "enemyStunPulse")
        }
        if enemy.starsNode == nil {
            let stars = label("✦ ✦ ✦", size: 10, color: GamePalette.warningYellow)
            stars.position = CGPoint(x: 0, y: 23)
            stars.zPosition = 4
            stars.run(.repeatForever(.sequence([
                .rotate(byAngle: .pi * 0.2, duration: 0.18),
                .rotate(byAngle: -.pi * 0.2, duration: 0.18)
            ])))
            enemy.addChild(stars)
            enemy.starsNode = stars
        }
    }

    private func clearEnemyStunnedVisual(_ enemy: EnemyNode) {
        enemy.starsNode?.removeFromParent()
        enemy.starsNode = nil
        startEnemyWalkAnimation(enemy)
    }

    private func makeYukStickerSprite(size: CGFloat = 34) -> SKSpriteNode {
        let sticker = SKSpriteNode(texture: texture("YukSticker"), size: CGSize(width: size, height: size))
        sticker.texture?.filteringMode = .nearest
        return sticker
    }

    @discardableResult
    private func sealNearestHazard() -> Bool {
        guard mode == .playing else { return false }
        let candidates = hazards.filter { !$0.sealed }
        guard let target = candidates.min(by: { distance(player.position, $0.position) < distance(player.position, $1.position) }),
              distance(player.position, target.position) < 60 else {
            return false
        }

        slapUntil = max(slapUntil, currentTimeValue + 0.18)
        target.sealed = true
        runSound("slap.wav")

        let flying = makeYukStickerSprite(size: 18)
        flying.position = player.position
        flying.zPosition = 90
        world.addChild(flying)
        let targetPosition = target.position
        flying.run(.sequence([
            .group([
                .move(to: targetPosition, duration: 0.16),
                .scale(to: 1.8, duration: 0.16),
                .rotate(byAngle: .pi * 1.5, duration: 0.16)
            ]),
            .removeFromParent()
        ]))

        let sticker = makeYukStickerSprite(size: 32)
        sticker.position = .zero
        sticker.setScale(0.25)
        sticker.alpha = 0
        sticker.zPosition = 5
        target.addChild(sticker)
        sticker.run(.group([.fadeIn(withDuration: 0.09), .scale(to: 1.0, duration: 0.13)]))
        target.sprite.removeAction(forKey: "hazardAnim")
        target.removeAction(forKey: "bob")
        target.children.filter { $0 !== sticker }.forEach { $0.alpha = 0.17 }

        awardPoints(base: 250, reason: "YUK!", color: GamePalette.yukGreen)
        impactBurst(at: target.position, color: GamePalette.yukGreen, count: 10)

        if hazards.allSatisfy(\.sealed) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                self?.completeLevel()
            }
        }
        return true
    }

    private func throwStickerProjectile() {
        guard currentTimeValue >= actionCooldownUntil else {
            flashMessage("RECHARGING!", color: GamePalette.warningYellow)
            return
        }

        actionCooldownUntil = currentTimeValue + stickerCooldown
        slapUntil = max(slapUntil, currentTimeValue + 0.22)
        runSound("slap.wav")

        let shot = StickerProjectileNode(
            texture: texture("YukSticker"),
            size: CGSize(width: 18, height: 18),
            velocity: CGVector(dx: facing * 255, dy: 10)
        )
        shot.texture?.filteringMode = .nearest
        shot.position = CGPoint(x: player.position.x + facing * 16, y: player.position.y + 2)
        shot.zPosition = 70
        shot.zRotation = facing < 0 ? -.pi * 0.18 : .pi * 0.18
        world.addChild(shot)
        projectiles.append(shot)
        flashMessage("STICKER TOSS!", color: GamePalette.phosphorGreen)
    }

    private func updateProjectiles(dt: CGFloat) {
        for projectile in projectiles.reversed() {
            projectile.position.x += projectile.velocityVector.dx * dt
            projectile.position.y += projectile.velocityVector.dy * dt
            projectile.velocityVector.dy -= 35 * dt
            projectile.zRotation += (projectile.velocityVector.dx >= 0 ? 1 : -1) * dt * 10

            var removeProjectile = false
            if projectile.position.x < -24 || projectile.position.x > 664 || projectile.position.y < -24 || projectile.position.y > 470 {
                removeProjectile = true
            }

            if !removeProjectile {
                for enemy in enemies where currentTimeValue >= enemy.stunnedUntil {
                    if distance(projectile.position, enemy.position) < 26 {
                        stunEnemy(enemy)
                        awardPoints(base: 100, reason: "STICKER STUN", color: GamePalette.warningYellow)
                        impactBurst(at: enemy.position, color: GamePalette.warningYellow, count: 8)
                        screenShake(intensity: 2.5, duration: 0.10)
                        removeProjectile = true
                        break
                    }
                }
            }

            if removeProjectile {
                if let index = projectiles.firstIndex(where: { $0 === projectile }) {
                    projectiles.remove(at: index)
                }
                projectile.removeFromParent()
            }
        }
    }

    private func stunEnemy(_ enemy: EnemyNode) {
        enemy.stunnedUntil = currentTimeValue + enemyStunDuration
        enemy.movement = .patrol
        enemy.direction *= -1
        enemy.movementSpeed = enemy.baseSpeed * 0.35
        startEnemyStunnedVisual(enemy)
    }

    // MARK: - Input / update

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)

        if event.keyCode == 46 { // M
            musicEnabled.toggle()
            UserDefaults.standard.set(musicEnabled, forKey: "MrYukPoisonPatrolMusic")
            if musicEnabled { startMusicIfNeeded() } else { stopMusic() }
            if mode == .playing || mode == .paused {
                flashMessage(musicEnabled ? "MUSIC ON" : "MUSIC OFF", color: GamePalette.phosphorGreen)
            }
            return
        }

        if event.keyCode == 35 || event.keyCode == 53 { // P / Escape
            switch mode {
            case .playing:
                pauseGame()
            case .paused:
                resumeGame()
            default:
                break
            }
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 { // Return / keypad Enter
            switch mode {
            case .attract, .gameOver:
                startGame()
            case .interstitial:
                advanceFromInterstitial()
            case .paused:
                resumeGame()
            case .finished:
                showAttractMode()
            case .playing:
                break
            }
        }

        if event.keyCode == 15 && (mode == .playing || mode == .paused) { // R
            loadLevel(levelIndex)
        }
    }

    override func keyUp(with event: NSEvent) {
        keysDown.remove(event.keyCode)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt: CGFloat
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(currentTime - lastUpdateTime), 1.0 / 30.0)
        }
        lastUpdateTime = currentTime
        currentTimeValue = currentTime
        animationClock += dt
        noiseClock += dt

        if noiseClock >= 0.12 {
            noiseClock = 0
            refreshNoise()
        }

        guard mode == .playing else { return }

        let second = Int(max(0, currentTimeValue - levelStartTime))
        if second != lastTimerSecond {
            lastTimerSecond = second
            refreshHUD()
        }
        if comboCount > 0 && currentTimeValue > comboExpiresAt {
            comboCount = 0
            refreshHUD()
        }
        updatePlayer(dt: dt)
        updateProjectiles(dt: dt)
        updateEnemies(dt: dt, currentTime: currentTime)
        checkEnemyHits(currentTime: currentTime)
    }

    private func updatePlayer(dt: CGFloat) {
        let left = keysDown.contains(123) || keysDown.contains(0)   // ← / A
        let right = keysDown.contains(124) || keysDown.contains(2) // → / D
        let down = keysDown.contains(125) || keysDown.contains(1)  // ↓ / S
        let up = keysDown.contains(126) || keysDown.contains(13)   // ↑ / W
        let jumpDown = keysDown.contains(6)                        // Z
        let actionDown = keysDown.contains(49)                     // Space

        if isStandingOnPlatform() {
            lastGroundedAt = currentTimeValue
        }
        if jumpDown && !wasJumpDown {
            jumpBufferUntil = currentTimeValue + 0.12
        }

        if actionDown && !wasActionDown {
            if !sealNearestHazard() {
                throwStickerProjectile()
            }
        }
        wasActionDown = actionDown

        let speed: CGFloat = 145
        if left == right {
            playerVelocity.dx *= 0.72
            if abs(playerVelocity.dx) < 4 { playerVelocity.dx = 0 }
        } else {
            facing = left ? -1 : 1
            playerVelocity.dx = left ? -speed : speed
            player.xScale = facing
        }

        let ladder = activeLadder()
        if (up || down), let ladder {
            playerOnLadder = true
            player.position.x += (ladder.midX - player.position.x) * min(1, 12 * dt)
        } else if playerOnLadder && ladder == nil {
            playerOnLadder = false
        }

        if playerOnLadder, let ladder {
            if up {
                playerVelocity.dy = 118
            } else if down {
                playerVelocity.dy = -118
            } else {
                playerVelocity.dy = 0
            }

            if player.position.y > ladder.maxY + 22 && up {
                playerOnLadder = false
            } else if player.position.y < ladder.minY - 10 && down {
                playerOnLadder = false
            }
        }

        if !playerOnLadder {
            playerVelocity.dy += -650 * dt
        }

        if currentTimeValue <= jumpBufferUntil {
            if playerOnLadder {
                playerOnLadder = false
                playerVelocity.dy = 260
                playerVelocity.dx = facing * 115
                jumpBufferUntil = 0
                runSound("jump.wav")
            } else if currentTimeValue - lastGroundedAt <= 0.12 {
                playerVelocity.dy = 285
                jumpBufferUntil = 0
                runSound("jump.wav")
            }
        }
        wasJumpDown = jumpDown

        let oldPosition = player.position
        var newPosition = CGPoint(x: oldPosition.x + playerVelocity.dx * dt,
                                  y: oldPosition.y + playerVelocity.dy * dt)
        newPosition.x = min(626, max(14, newPosition.x))

        if !playerOnLadder && playerVelocity.dy <= 0 {
            let oldBottom = oldPosition.y - 16
            let newBottom = newPosition.y - 16
            for platform in platforms {
                let horizontalOverlap = (newPosition.x + 10 > platform.minX) && (newPosition.x - 10 < platform.maxX)
                if horizontalOverlap && oldBottom >= platform.maxY - 2 && newBottom <= platform.maxY {
                    newPosition.y = platform.maxY + 16
                    playerVelocity.dy = 0
                    break
                }
            }
        }

        player.position = newPosition
        updatePlayerSprite(left: left, right: right, climbing: playerOnLadder)

        if player.position.y < -24 { loseLife() }
    }

    private func updatePlayerSprite(left: Bool, right: Bool, climbing: Bool) {
        let frames: [String]
        let fps: CGFloat

        if currentTimeValue < hurtUntil {
            frames = ["PlayerHurt1", "PlayerHurt2"]
            fps = 10
        } else if currentTimeValue < slapUntil {
            frames = ["PlayerAttack1", "PlayerAttack2", "PlayerAttack1"]
            fps = 13
        } else if climbing {
            frames = ["PlayerYuk2", "PlayerYuk4"]
            fps = 6
        } else if !isStandingOnPlatform() {
            frames = playerVelocity.dy >= 0 ? ["PlayerJump"] : ["PlayerFall"]
            fps = 1
        } else if left || right {
            frames = ["PlayerYuk1", "PlayerYuk2", "PlayerYuk3", "PlayerYuk4"]
            fps = 9
        } else {
            frames = ["PlayerIdle1", "PlayerIdle2"]
            fps = 2.2
        }

        let index = min(frames.count - 1, Int(animationClock * fps) % max(frames.count, 1))
        playerSprite.texture = texture(frames[index])
        playerSprite.alpha = currentTimeValue < hurtUntil ? (Int(animationClock * 18) % 2 == 0 ? 0.55 : 1.0) : 1.0
    }

    private func activeLadder() -> CGRect? {
        let testPoint = player.position
        return ladders.first { ladder in
            abs(testPoint.x - ladder.midX) < 19 &&
            testPoint.y > ladder.minY - 16 && testPoint.y < ladder.maxY + 24
        }
    }

    private func isStandingOnPlatform() -> Bool {
        let bottom = player.position.y - 16
        return platforms.contains { platform in
            let horizontalOverlap = (player.position.x + 10 > platform.minX) && (player.position.x - 10 < platform.maxX)
            return horizontalOverlap && abs(bottom - platform.maxY) < 4
        }
    }

    // MARK: - Enemy ladder AI

    private func updateEnemies(dt: CGFloat, currentTime: TimeInterval) {
        for enemy in enemies {
            if currentTime < enemy.stunnedUntil {
                startEnemyStunnedVisual(enemy)
                continue
            } else if enemy.starsNode != nil {
                enemy.movementSpeed = enemy.baseSpeed
                clearEnemyStunnedVisual(enemy)
            }

            if currentTime >= enemy.nextDecision {
                enemy.nextDecision = currentTime + Double.random(in: enemyDecisionDelay)
                makeEnemyDecision(enemy)
            }

            switch enemy.movement {
            case .patrol:
                enemy.position.x += enemy.movementSpeed * enemy.direction * dt
                clampEnemyToCurrentPlatform(enemy)

            case .seeking(let ladder, let targetY):
                let dx = ladder.midX - enemy.position.x
                enemy.direction = dx < 0 ? -1 : 1
                enemy.position.x += enemy.movementSpeed * enemy.direction * dt
                if abs(dx) < 3.5 {
                    enemy.position.x = ladder.midX
                    enemy.movement = .climbing(ladder: ladder, targetY: targetY)
                } else {
                    clampEnemyToCurrentPlatform(enemy)
                }

            case .climbing(let ladder, let targetY):
                enemy.position.x += (ladder.midX - enemy.position.x) * min(1, 16 * dt)
                let directionY: CGFloat = targetY > enemy.position.y ? 1 : -1
                enemy.position.y += 88 * directionY * dt
                if abs(targetY - enemy.position.y) <= 3.5 ||
                    (directionY > 0 && enemy.position.y >= targetY) ||
                    (directionY < 0 && enemy.position.y <= targetY) {
                    enemy.position.y = targetY
                    enemy.movement = .patrol
                    enemy.direction = player.position.x < enemy.position.x ? -1 : 1
                    updateEnemyRangeForLane(enemy)
                }
            }

            enemy.xScale = enemy.direction
        }
    }

    private func makeEnemyDecision(_ enemy: EnemyNode) {
        guard case .patrol = enemy.movement else { return }

        let verticalGap = player.position.y - enemy.position.y
        if abs(verticalGap) < 30 {
            if abs(player.position.x - enemy.position.x) > 10 {
                enemy.direction = player.position.x < enemy.position.x ? -1 : 1
            }
            return
        }

        let possible = ladders.compactMap { ladder -> (CGRect, CGFloat, CGFloat)? in
            guard let (lowY, highY) = ladderEndpoints(ladder) else { return nil }
            let currentY = abs(enemy.position.y - lowY) < 18 ? lowY : (abs(enemy.position.y - highY) < 18 ? highY : nil)
            guard let currentY else { return nil }
            let targetY = abs(currentY - lowY) < 1 ? highY : lowY

            if verticalGap > 0 && targetY <= currentY { return nil }
            if verticalGap < 0 && targetY >= currentY { return nil }

            let cost = abs(ladder.midX - enemy.position.x) + abs(targetY - player.position.y) * 0.25
            return (ladder, targetY, cost)
        }

        if let choice = possible.min(by: { $0.2 < $1.2 }) {
            enemy.movement = .seeking(ladder: choice.0, targetY: choice.1)
            enemy.direction = choice.0.midX < enemy.position.x ? -1 : 1
        } else {
            enemy.direction = player.position.x < enemy.position.x ? -1 : 1
        }
    }

    private func ladderEndpoints(_ ladder: CGRect) -> (CGFloat, CGFloat)? {
        let candidateLevels = platforms
            .filter { ladder.midX >= $0.minX - 4 && ladder.midX <= $0.maxX + 4 }
            .map { $0.maxY + 16 }

        guard candidateLevels.count >= 2 else { return nil }

        guard let low = candidateLevels.min(by: {
            abs(($0 - 16) - ladder.minY) < abs(($1 - 16) - ladder.minY)
        }), let high = candidateLevels.min(by: {
            abs(($0 - 16) - ladder.maxY) < abs(($1 - 16) - ladder.maxY)
        }), abs(high - low) > 20 else {
            return nil
        }

        return low < high ? (low, high) : (high, low)
    }

    private func clampEnemyToCurrentPlatform(_ enemy: EnemyNode) {
        if let platform = platformForEnemy(enemy.position) {
            enemy.minX = platform.minX + 14
            enemy.maxX = platform.maxX - 14
        }

        if enemy.position.x <= enemy.minX {
            enemy.position.x = enemy.minX
            enemy.direction = 1
        } else if enemy.position.x >= enemy.maxX {
            enemy.position.x = enemy.maxX
            enemy.direction = -1
        }
    }

    private func updateEnemyRangeForLane(_ enemy: EnemyNode) {
        if let platform = platformForEnemy(enemy.position) {
            enemy.minX = platform.minX + 14
            enemy.maxX = platform.maxX - 14
            enemy.position.x = min(enemy.maxX, max(enemy.minX, enemy.position.x))
        }
    }

    private func platformForEnemy(_ point: CGPoint) -> CGRect? {
        platforms
            .filter { point.x >= $0.minX - 18 && point.x <= $0.maxX + 18 }
            .min(by: { abs(($0.maxY + 16) - point.y) < abs(($1.maxY + 16) - point.y) })
    }

    private func checkEnemyHits(currentTime: TimeInterval) {
        guard currentTime >= invulnerableUntil else { return }
        for enemy in enemies where currentTime >= enemy.stunnedUntil {
            if distance(player.position, enemy.position) < 27 {
                loseLife()
                return
            }
        }
    }

    // MARK: - Life / score / overlays

    private func loseLife() {
        guard mode == .playing else { return }
        lives -= 1
        comboCount = 0
        comboExpiresAt = 0
        hurtUntil = currentTimeValue + 0.7
        slapUntil = 0
        actionCooldownUntil = 0
        for projectile in projectiles { projectile.removeFromParent() }
        projectiles.removeAll()
        runSound("danger.wav")
        impactBurst(at: player.position, color: GamePalette.dangerRed, count: 14)
        screenShake(intensity: 7, duration: 0.22)
        staticBurst(duration: 0.16)
        refreshHUD()

        if lives <= 0 {
            updateHighScoreIfNeeded()
            stopMusic()
            mode = .gameOver
            playerSprite.removeAllActions()
            playerSprite.run(.animate(with: textures([
                "PlayerDeath1", "PlayerDeath2", "PlayerDeath3", "PlayerDeath4"
            ]), timePerFrame: 0.12, resize: false, restore: false))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { [weak self] in
                guard let self, self.mode == .gameOver else { return }
                self.showOverlay(title: "TOXIC TROUBLE!",
                                 subtitle: String(format: "GAME OVER\n\nSCORE  %06d   •   HIGH SCORE  %06d\n\nTHE BAD STUFF GOT LOOSE.\n\nPOISON HELP  1-800-222-1222\n\nPRESS RETURN TO TRY AGAIN", self.score, self.highScore),
                                 showLogo: false)
            }
            return
        }

        invulnerableUntil = lastUpdateTime + 1.8
        playerVelocity = .zero
        playerOnLadder = false
        player.position = LevelBook.levels[levelIndex].spawn
        lastGroundedAt = currentTimeValue
        jumpBufferUntil = 0
        player.run(.sequence([
            .fadeAlpha(to: 0.12, duration: 0.07), .fadeAlpha(to: 1, duration: 0.07),
            .fadeAlpha(to: 0.12, duration: 0.07), .fadeAlpha(to: 1, duration: 0.07),
            .fadeAlpha(to: 0.12, duration: 0.07), .fadeAlpha(to: 1, duration: 0.07),
            .wait(forDuration: 0.35),
            .fadeAlpha(to: 0.25, duration: 0.07), .fadeAlpha(to: 1, duration: 0.07)
        ]))
        flashMessage("BACK OFF!", color: GamePalette.dangerRed)
    }

    private func refreshHUD() {
        updateHighScoreIfNeeded()
        scoreLabel.text = String(format: "SCORE %06d", score)
        highScoreLabel.text = String(format: "HI %06d", highScore)
        livesLabel.text = "LIVES \(max(0, lives))"
        livesLabel.fontColor = lives <= 1 ? GamePalette.warningYellow : GamePalette.yukGreen

        let left = hazards.filter { !$0.sealed }.count
        targetLabel.text = (mode == .playing || mode == .paused) ? "EP \(levelIndex + 1) • HAZARDS \(left)" : "POISON PATROL"

        let elapsed = max(0, currentTimeValue - levelStartTime)
        timerLabel.text = String(format: "TIME %03d", Int(elapsed))
        if elapsed >= 70 {
            timerLabel.fontColor = GamePalette.dangerRed
        } else if elapsed >= 45 {
            timerLabel.fontColor = GamePalette.warningYellow
        } else {
            timerLabel.fontColor = GamePalette.offWhite
        }

        if comboCount > 1 && currentTimeValue <= comboExpiresAt {
            comboLabel.text = "PSA CHAIN x\(comboCount)"
            comboLabel.alpha = 1
        } else {
            comboLabel.text = ""
            comboLabel.alpha = 0
        }
    }

    private func updateHighScoreIfNeeded() {
        guard score > highScore else { return }
        highScore = score
        UserDefaults.standard.set(highScore, forKey: "MrYukPoisonPatrolHighScore")
    }

    private func awardPoints(base: Int, reason: String, color: SKColor) {
        if currentTimeValue <= comboExpiresAt && comboCount > 0 {
            comboCount = min(4, comboCount + 1)
        } else {
            comboCount = 1
        }
        comboExpiresAt = currentTimeValue + comboWindow
        let earned = base * comboCount
        score += earned
        grantExtraLifeIfNeeded()
        updateHighScoreIfNeeded()
        let chainText = comboCount > 1 ? "  x\(comboCount)" : ""
        flashMessage("\(reason) +\(earned)\(chainText)", color: color)
        refreshHUD()
    }

    private func pauseGame() {
        guard mode == .playing else { return }
        mode = .paused
        pauseStartedAt = currentTimeValue
        playerVelocity = .zero

        let root = SKNode()
        root.name = "pauseCard"
        root.zPosition = 180
        let dim = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 442))
        dim.fillColor = SKColor.black.withAlphaComponent(0.72)
        dim.strokeColor = .clear
        root.addChild(dim)

        let card = SKShapeNode(rectOf: CGSize(width: 420, height: 190), cornerRadius: 8)
        card.position = CGPoint(x: 320, y: 238)
        card.fillColor = GamePalette.nearBlack
        card.strokeColor = GamePalette.yukGreen
        card.lineWidth = 3
        root.addChild(card)

        let title = label("PSA TRANSMISSION PAUSED", size: 18, color: GamePalette.yukGreen)
        title.position = CGPoint(x: 0, y: 48)
        card.addChild(title)
        let body = label("P / ESC  RESUME     M  MUSIC     R  RESTART EPISODE", size: 8, color: GamePalette.offWhite)
        body.position = CGPoint(x: 0, y: 8)
        card.addChild(body)
        let help = label("POISON HELP  1-800-222-1222", size: 11, color: GamePalette.warningYellow)
        help.position = CGPoint(x: 0, y: -32)
        card.addChild(help)

        overlay.addChild(root)
        refreshHUD()
    }

    private func resumeGame() {
        guard mode == .paused else { return }
        overlay.childNode(withName: "pauseCard")?.removeFromParent()
        levelStartTime += max(0, currentTimeValue - pauseStartedAt)
        pauseStartedAt = 0
        mode = .playing
        refreshHUD()
    }

    private func startMusicIfNeeded() {
        guard musicEnabled, action(forKey: "musicLoop") == nil else { return }
        let loop = SKAction.repeatForever(.sequence([
            .playSoundFileNamed("theme.wav", waitForCompletion: true),
            .wait(forDuration: 0.05)
        ]))
        run(loop, withKey: "musicLoop")
    }

    private func stopMusic() {
        removeAction(forKey: "musicLoop")
    }

    private func screenShake(intensity: CGFloat, duration: TimeInterval) {
        world.removeAction(forKey: "shake")
        let steps = max(2, Int(duration / 0.025))
        var actions: [SKAction] = []
        for _ in 0..<steps {
            actions.append(.moveBy(x: CGFloat.random(in: -intensity...intensity),
                                   y: CGFloat.random(in: -intensity...intensity),
                                   duration: 0.025))
        }
        actions.append(.move(to: .zero, duration: 0.04))
        world.run(.sequence(actions), withKey: "shake")
    }

    private func impactBurst(at point: CGPoint, color: SKColor, count: Int) {
        let burst = SKNode()
        burst.position = point
        burst.zPosition = 120
        world.addChild(burst)

        let ring = SKShapeNode(circleOfRadius: 8)
        ring.strokeColor = color
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.alpha = 0.95
        burst.addChild(ring)
        ring.run(.group([.scale(to: 3.2, duration: 0.22), .fadeOut(withDuration: 0.22)]))

        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(max(count, 1)) * .pi * 2 + CGFloat.random(in: -0.18...0.18)
            let distance = CGFloat.random(in: 18...42)
            let particle = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 2...5), height: 2))
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.zRotation = angle
            burst.addChild(particle)
            particle.run(.group([
                .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.24),
                .fadeOut(withDuration: 0.24),
                .scale(to: 0.2, duration: 0.24)
            ]))
        }
        burst.run(.sequence([.wait(forDuration: 0.30), .removeFromParent()]))
    }

    private func showOverlay(title: String, subtitle: String, showLogo: Bool) {
        overlay.removeAllChildren()

        let dim = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 640, height: 480))
        dim.fillColor = SKColor.black.withAlphaComponent(0.91)
        dim.strokeColor = .clear
        dim.zPosition = 200
        overlay.addChild(dim)

        let cardHeight: CGFloat = showLogo ? 410 : 320
        let card = SKShapeNode(rectOf: CGSize(width: 566, height: cardHeight), cornerRadius: 10)
        card.position = CGPoint(x: 320, y: 244)
        card.fillColor = GamePalette.nearBlack
        card.strokeColor = GamePalette.yukGreen
        card.lineWidth = 4
        card.zPosition = 201
        overlay.addChild(card)

        let inset = SKShapeNode(rectOf: CGSize(width: 544, height: cardHeight - 22), cornerRadius: 8)
        inset.fillColor = GamePalette.nearBlack.withAlphaComponent(0.96)
        inset.strokeColor = GamePalette.phosphorGreen.withAlphaComponent(0.18)
        inset.lineWidth = 1
        card.addChild(inset)

        let isGameOver = title.uppercased().contains("TOXIC TROUBLE")
        let isFinal = title.uppercased().contains("REMEMBER MR. YUK")
        let accent = isGameOver ? GamePalette.dangerRed : GamePalette.warningYellow
        let headerText = isGameOver ? "EMERGENCY INTERRUPTION • CHANNEL 13" : (isFinal ? "PUBLIC SERVICE SIGN-OFF • CHANNEL 13" : "PUBLIC SERVICE ARCADE • CHANNEL 13")

        let headerBand = SKShapeNode(rectOf: CGSize(width: 514, height: 20), cornerRadius: 4)
        headerBand.position = CGPoint(x: 0, y: showLogo ? 184 : 138)
        headerBand.fillColor = accent.withAlphaComponent(0.14)
        headerBand.strokeColor = accent.withAlphaComponent(0.42)
        headerBand.lineWidth = 1
        card.addChild(headerBand)

        let header = label(headerText, size: 8.8, color: accent)
        header.position = CGPoint(x: 0, y: showLogo ? 184 : 138)
        card.addChild(header)

        var titleY: CGFloat = showLogo ? 44 : 74
        if showLogo {
            let logoGlow = SKShapeNode(circleOfRadius: 66)
            logoGlow.position = CGPoint(x: 0, y: 112)
            logoGlow.fillColor = GamePalette.yukGreen.withAlphaComponent(0.05)
            logoGlow.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.18)
            logoGlow.lineWidth = 1
            card.addChild(logoGlow)

            let logo = SKSpriteNode(texture: texture("MrYukReference"), size: CGSize(width: 118, height: 118))
            logo.position = CGPoint(x: 0, y: 112)
            logo.zPosition = 1
            card.addChild(logo)
            titleY = 38
        }

        let titleNode = multilineLabel(title, size: 24, color: GamePalette.yukGreen, width: 500, lineHeight: 30)
        titleNode.position = CGPoint(x: 0, y: titleY)
        card.addChild(titleNode)

        let bodyBand = SKShapeNode(rectOf: CGSize(width: 490, height: showLogo ? 150 : 136), cornerRadius: 6)
        bodyBand.position = CGPoint(x: 0, y: showLogo ? -74 : -20)
        bodyBand.fillColor = SKColor.white.withAlphaComponent(0.03)
        bodyBand.strokeColor = GamePalette.yukGreen.withAlphaComponent(0.22)
        bodyBand.lineWidth = 1
        card.addChild(bodyBand)

        let body = multilineLabel(subtitle, size: 11, color: GamePalette.offWhite, width: 458, lineHeight: 17)
        body.position = CGPoint(x: 0, y: showLogo ? -71 : -17)
        card.addChild(body)

        let footer = label("POISON HELP  •  1-800-222-1222", size: 10.2, color: GamePalette.warningYellow)
        footer.position = CGPoint(x: 0, y: showLogo ? -176 : -122)
        card.addChild(footer)
    }

    private func flashMessage(_ text: String, color: SKColor) {
        let node = label(text, size: 18, color: color)
        node.position = CGPoint(x: 320, y: 400)
        node.zPosition = 150
        node.setScale(0.8)
        overlay.addChild(node)
        node.run(.sequence([
            .group([.fadeIn(withDuration: 0.05), .scale(to: 1.06, duration: 0.08)]),
            .wait(forDuration: 0.42),
            .group([.fadeOut(withDuration: 0.18), .moveBy(x: 0, y: 18, duration: 0.18)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Utility

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func runSound(_ name: String) {
        run(.playSoundFileNamed(name, waitForCompletion: false))
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        return node
    }

    private func multilineLabel(_ text: String, size: CGFloat, color: SKColor, width: CGFloat, lineHeight: CGFloat) -> SKNode {
        let container = SKNode()
        let lines = text.components(separatedBy: "\n")
        let total = CGFloat(max(0, lines.count - 1)) * lineHeight
        for (index, line) in lines.enumerated() {
            let node = label(line, size: size, color: color)
            node.position = CGPoint(x: 0, y: total / 2 - CGFloat(index) * lineHeight)
            if node.frame.width > width && node.frame.width > 0 {
                node.xScale = width / node.frame.width
            }
            container.addChild(node)
        }
        return container
    }
}
