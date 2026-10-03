import CoreGraphics

struct PlatformSpec {
    let rect: CGRect
}

struct LadderSpec {
    let rect: CGRect
}

enum HazardKind: String {
    case medicine = "PILLS"
    case cleaner = "CLEANER"
    case spray = "SPRAY"
    case chemical = "CHEMICAL"

    var texturePrefix: String {
        switch self {
        case .medicine: return "HazardMedicine"
        case .cleaner: return "HazardCleaner"
        case .spray: return "HazardSpray"
        case .chemical: return "HazardChemical"
        }
    }
}

struct HazardSpec {
    let position: CGPoint
    let kind: HazardKind
}

enum EnemyKind: String {
    case pills
    case cleaner
    case spray
    case chemical

    var texturePrefix: String {
        switch self {
        case .pills: return "PillMonster"
        case .cleaner: return "CleanerMonster"
        case .spray: return "SprayMonster"
        case .chemical: return "ChemicalMonster"
        }
    }
}

struct EnemySpec {
    let kind: EnemyKind
    let y: CGFloat
    let minX: CGFloat
    let maxX: CGFloat
    let startX: CGFloat
    let speed: CGFloat
}

enum StageTheme {
    case bathroom
    case garage
    case basement
    case kitchen
    case laundry
    case garden
    case guestHouse
    case challenge
}

struct LevelDefinition {
    let title: String
    let channelTag: String
    let psaLine: String
    let psaDetail: String
    let theme: StageTheme
    let spawn: CGPoint
    let platforms: [PlatformSpec]
    let ladders: [LadderSpec]
    let hazards: [HazardSpec]
    let enemies: [EnemySpec]
}

enum LevelBook {
    static let levels: [LevelDefinition] = [
        LevelDefinition(
            title: "MEDICINE CABINET MELTDOWN",
            channelTag: "BATHROOM SAFETY",
            psaLine: "MEDICINE IS NOT CANDY.",
            psaDetail: "KEEP MEDICINE UP, AWAY, AND IN ITS ORIGINAL CONTAINER.",
            theme: .bathroom,
            spawn: CGPoint(x: 60, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 34, y: 142, width: 250, height: 14)),
                PlatformSpec(rect: CGRect(x: 350, y: 142, width: 256, height: 14)),
                PlatformSpec(rect: CGRect(x: 110, y: 244, width: 420, height: 14)),
                PlatformSpec(rect: CGRect(x: 32, y: 344, width: 224, height: 14)),
                PlatformSpec(rect: CGRect(x: 330, y: 344, width: 274, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 120, y: 58, width: 26, height: 90)),
                LadderSpec(rect: CGRect(x: 492, y: 58, width: 26, height: 90)),
                LadderSpec(rect: CGRect(x: 204, y: 156, width: 26, height: 94)),
                LadderSpec(rect: CGRect(x: 408, y: 156, width: 26, height: 94)),
                LadderSpec(rect: CGRect(x: 176, y: 258, width: 26, height: 92)),
                LadderSpec(rect: CGRect(x: 470, y: 258, width: 26, height: 92))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 205, y: 176), kind: .medicine),
                HazardSpec(position: CGPoint(x: 540, y: 176), kind: .medicine),
                HazardSpec(position: CGPoint(x: 160, y: 278), kind: .medicine),
                HazardSpec(position: CGPoint(x: 470, y: 278), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 102, y: 378), kind: .spray),
                HazardSpec(position: CGPoint(x: 520, y: 378), kind: .medicine)
            ],
            enemies: [
                EnemySpec(kind: .pills, y: 170, minX: 365, maxX: 592, startX: 430, speed: 58),
                EnemySpec(kind: .cleaner, y: 272, minX: 128, maxX: 516, startX: 330, speed: 70)
            ]
        ),
        LevelDefinition(
            title: "GARAGE OF BAD IDEAS",
            channelTag: "GARAGE SAFETY",
            psaLine: "LOCK CHEMICALS UP AND OUT OF REACH.",
            psaDetail: "NEVER STORE CLEANERS OR CHEMICALS IN FOOD OR DRINK CONTAINERS.",
            theme: .garage,
            spawn: CGPoint(x: 580, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 42, y: 128, width: 186, height: 14)),
                PlatformSpec(rect: CGRect(x: 286, y: 128, width: 314, height: 14)),
                PlatformSpec(rect: CGRect(x: 70, y: 220, width: 440, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 312, width: 240, height: 14)),
                PlatformSpec(rect: CGRect(x: 332, y: 312, width: 284, height: 14)),
                PlatformSpec(rect: CGRect(x: 140, y: 398, width: 360, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 90, y: 58, width: 26, height: 76)),
                LadderSpec(rect: CGRect(x: 526, y: 58, width: 26, height: 76)),
                LadderSpec(rect: CGRect(x: 174, y: 142, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 414, y: 142, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 112, y: 234, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 492, y: 234, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 224, y: 326, width: 26, height: 78)),
                LadderSpec(rect: CGRect(x: 410, y: 326, width: 26, height: 78))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 76, y: 162), kind: .chemical),
                HazardSpec(position: CGPoint(x: 350, y: 162), kind: .spray),
                HazardSpec(position: CGPoint(x: 548, y: 162), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 120, y: 254), kind: .chemical),
                HazardSpec(position: CGPoint(x: 434, y: 254), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 184, y: 346), kind: .spray),
                HazardSpec(position: CGPoint(x: 530, y: 346), kind: .chemical),
                HazardSpec(position: CGPoint(x: 312, y: 430), kind: .cleaner)
            ],
            enemies: [
                EnemySpec(kind: .spray, y: 156, minX: 300, maxX: 586, startX: 380, speed: 72),
                EnemySpec(kind: .chemical, y: 248, minX: 82, maxX: 498, startX: 245, speed: 78),
                EnemySpec(kind: .cleaner, y: 340, minX: 346, maxX: 598, startX: 430, speed: 64)
            ]
        ),
        LevelDefinition(
            title: "BASEMENT TOXIC SHUFFLE",
            channelTag: "STORAGE SAFETY",
            psaLine: "WHEN IN DOUBT, DON'T TASTE OR TOUCH.",
            psaDetail: "ASK AN ADULT. KEEP HOUSEHOLD PRODUCTS LABELED AND SECURE.",
            theme: .basement,
            spawn: CGPoint(x: 64, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 24, y: 116, width: 274, height: 14)),
                PlatformSpec(rect: CGRect(x: 356, y: 116, width: 260, height: 14)),
                PlatformSpec(rect: CGRect(x: 82, y: 196, width: 476, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 278, width: 206, height: 14)),
                PlatformSpec(rect: CGRect(x: 286, y: 278, width: 330, height: 14)),
                PlatformSpec(rect: CGRect(x: 100, y: 360, width: 430, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 156, y: 58, width: 26, height: 64)),
                LadderSpec(rect: CGRect(x: 470, y: 58, width: 26, height: 64)),
                LadderSpec(rect: CGRect(x: 112, y: 130, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 500, y: 130, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 190, y: 210, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 388, y: 210, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 150, y: 292, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 464, y: 292, width: 26, height: 74))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 80, y: 150), kind: .medicine),
                HazardSpec(position: CGPoint(x: 232, y: 150), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 410, y: 150), kind: .chemical),
                HazardSpec(position: CGPoint(x: 552, y: 150), kind: .spray),
                HazardSpec(position: CGPoint(x: 132, y: 230), kind: .chemical),
                HazardSpec(position: CGPoint(x: 320, y: 230), kind: .medicine),
                HazardSpec(position: CGPoint(x: 500, y: 230), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 84, y: 312), kind: .spray),
                HazardSpec(position: CGPoint(x: 552, y: 312), kind: .chemical),
                HazardSpec(position: CGPoint(x: 316, y: 394), kind: .medicine)
            ],
            enemies: [
                EnemySpec(kind: .pills, y: 144, minX: 370, maxX: 602, startX: 440, speed: 78),
                EnemySpec(kind: .cleaner, y: 224, minX: 96, maxX: 544, startX: 248, speed: 88),
                EnemySpec(kind: .chemical, y: 306, minX: 300, maxX: 602, startX: 470, speed: 76),
                EnemySpec(kind: .spray, y: 388, minX: 112, maxX: 516, startX: 380, speed: 82)
            ]
        ),
        LevelDefinition(
            title: "KITCHEN CABINET CAPER",
            channelTag: "KITCHEN SAFETY",
            psaLine: "CLEANERS DON'T BELONG WITH FOOD.",
            psaDetail: "KEEP DANGEROUS PRODUCTS LOCKED, LABELED, AND AWAY FROM KIDS.",
            theme: .kitchen,
            spawn: CGPoint(x: 560, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 24, y: 136, width: 220, height: 14)),
                PlatformSpec(rect: CGRect(x: 302, y: 136, width: 314, height: 14)),
                PlatformSpec(rect: CGRect(x: 84, y: 228, width: 476, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 320, width: 282, height: 14)),
                PlatformSpec(rect: CGRect(x: 364, y: 320, width: 252, height: 14)),
                PlatformSpec(rect: CGRect(x: 132, y: 398, width: 374, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 102, y: 58, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 512, y: 58, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 178, y: 150, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 440, y: 150, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 136, y: 242, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 474, y: 242, width: 26, height: 84)),
                LadderSpec(rect: CGRect(x: 246, y: 334, width: 26, height: 70)),
                LadderSpec(rect: CGRect(x: 398, y: 334, width: 26, height: 70))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 70, y: 170), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 208, y: 170), kind: .medicine),
                HazardSpec(position: CGPoint(x: 356, y: 170), kind: .spray),
                HazardSpec(position: CGPoint(x: 556, y: 170), kind: .chemical),
                HazardSpec(position: CGPoint(x: 130, y: 262), kind: .medicine),
                HazardSpec(position: CGPoint(x: 322, y: 262), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 510, y: 262), kind: .spray),
                HazardSpec(position: CGPoint(x: 96, y: 354), kind: .chemical),
                HazardSpec(position: CGPoint(x: 448, y: 354), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 318, y: 430), kind: .medicine)
            ],
            enemies: [
                EnemySpec(kind: .cleaner, y: 164, minX: 316, maxX: 602, startX: 470, speed: 74),
                EnemySpec(kind: .pills, y: 256, minX: 98, maxX: 546, startX: 270, speed: 84),
                EnemySpec(kind: .spray, y: 348, minX: 378, maxX: 602, startX: 520, speed: 80),
                EnemySpec(kind: .chemical, y: 426, minX: 144, maxX: 494, startX: 350, speed: 72)
            ]
        ),
        LevelDefinition(
            title: "LAUNDRY ROOM LOCKUP",
            channelTag: "LAUNDRY SAFETY",
            psaLine: "NEVER MIX HOUSEHOLD CLEANERS.",
            psaDetail: "USE PRODUCTS ONLY AS DIRECTED. KEEP THEM IN THEIR ORIGINAL CONTAINERS AND OUT OF REACH.",
            theme: .laundry,
            spawn: CGPoint(x: 62, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 34, y: 126, width: 230, height: 14)),
                PlatformSpec(rect: CGRect(x: 324, y: 126, width: 282, height: 14)),
                PlatformSpec(rect: CGRect(x: 88, y: 208, width: 464, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 290, width: 250, height: 14)),
                PlatformSpec(rect: CGRect(x: 334, y: 290, width: 282, height: 14)),
                PlatformSpec(rect: CGRect(x: 122, y: 372, width: 390, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 116, y: 58, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 512, y: 58, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 190, y: 140, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 430, y: 140, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 128, y: 222, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 474, y: 222, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 220, y: 304, width: 26, height: 74)),
                LadderSpec(rect: CGRect(x: 404, y: 304, width: 26, height: 74))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 86, y: 160), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 222, y: 160), kind: .chemical),
                HazardSpec(position: CGPoint(x: 376, y: 160), kind: .spray),
                HazardSpec(position: CGPoint(x: 548, y: 160), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 138, y: 242), kind: .chemical),
                HazardSpec(position: CGPoint(x: 316, y: 242), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 502, y: 242), kind: .medicine),
                HazardSpec(position: CGPoint(x: 82, y: 324), kind: .spray),
                HazardSpec(position: CGPoint(x: 526, y: 324), kind: .chemical),
                HazardSpec(position: CGPoint(x: 316, y: 406), kind: .cleaner)
            ],
            enemies: [
                EnemySpec(kind: .cleaner, y: 154, minX: 338, maxX: 592, startX: 456, speed: 74),
                EnemySpec(kind: .chemical, y: 236, minX: 102, maxX: 538, startX: 252, speed: 82),
                EnemySpec(kind: .spray, y: 318, minX: 348, maxX: 602, startX: 500, speed: 78),
                EnemySpec(kind: .pills, y: 400, minX: 136, maxX: 498, startX: 360, speed: 76)
            ]
        ),
        LevelDefinition(
            title: "GARDEN SHED PANIC",
            channelTag: "YARD & SHED SAFETY",
            psaLine: "YARD CHEMICALS STAY LOCKED AND LABELED.",
            psaDetail: "KEEP PESTICIDES, FUELS, AND OTHER HOUSEHOLD CHEMICALS IN THEIR ORIGINAL CONTAINERS AND AWAY FROM KIDS.",
            theme: .garden,
            spawn: CGPoint(x: 574, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 24, y: 132, width: 204, height: 14)),
                PlatformSpec(rect: CGRect(x: 286, y: 132, width: 330, height: 14)),
                PlatformSpec(rect: CGRect(x: 70, y: 220, width: 500, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 308, width: 288, height: 14)),
                PlatformSpec(rect: CGRect(x: 370, y: 308, width: 246, height: 14)),
                PlatformSpec(rect: CGRect(x: 112, y: 396, width: 416, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 90, y: 58, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 520, y: 58, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 170, y: 146, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 454, y: 146, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 118, y: 234, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 502, y: 234, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 236, y: 322, width: 26, height: 80)),
                LadderSpec(rect: CGRect(x: 414, y: 322, width: 26, height: 80))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 72, y: 166), kind: .chemical),
                HazardSpec(position: CGPoint(x: 192, y: 166), kind: .spray),
                HazardSpec(position: CGPoint(x: 330, y: 166), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 548, y: 166), kind: .chemical),
                HazardSpec(position: CGPoint(x: 126, y: 254), kind: .spray),
                HazardSpec(position: CGPoint(x: 316, y: 254), kind: .chemical),
                HazardSpec(position: CGPoint(x: 520, y: 254), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 92, y: 342), kind: .chemical),
                HazardSpec(position: CGPoint(x: 452, y: 342), kind: .spray),
                HazardSpec(position: CGPoint(x: 318, y: 430), kind: .chemical)
            ],
            enemies: [
                EnemySpec(kind: .spray, y: 160, minX: 300, maxX: 602, startX: 430, speed: 78),
                EnemySpec(kind: .chemical, y: 248, minX: 84, maxX: 556, startX: 210, speed: 84),
                EnemySpec(kind: .cleaner, y: 336, minX: 384, maxX: 602, startX: 500, speed: 80),
                EnemySpec(kind: .spray, y: 424, minX: 126, maxX: 514, startX: 360, speed: 82)
            ]
        ),
        LevelDefinition(
            title: "SOMEONE ELSE'S HOUSE",
            channelTag: "VISITING SAFETY",
            psaLine: "UNKNOWN PRODUCTS ARE NOT TOYS.",
            psaDetail: "AT SOMEONE ELSE'S HOUSE, ASK BEFORE YOU TOUCH PILLS, CLEANERS, SPRAYS, OR CHEMICALS.",
            theme: .guestHouse,
            spawn: CGPoint(x: 64, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 24, y: 118, width: 272, height: 14)),
                PlatformSpec(rect: CGRect(x: 354, y: 118, width: 262, height: 14)),
                PlatformSpec(rect: CGRect(x: 86, y: 194, width: 470, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 270, width: 210, height: 14)),
                PlatformSpec(rect: CGRect(x: 292, y: 270, width: 324, height: 14)),
                PlatformSpec(rect: CGRect(x: 76, y: 346, width: 250, height: 14)),
                PlatformSpec(rect: CGRect(x: 384, y: 346, width: 232, height: 14)),
                PlatformSpec(rect: CGRect(x: 154, y: 410, width: 338, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 150, y: 58, width: 26, height: 66)),
                LadderSpec(rect: CGRect(x: 492, y: 58, width: 26, height: 66)),
                LadderSpec(rect: CGRect(x: 112, y: 132, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 500, y: 132, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 194, y: 208, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 402, y: 208, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 150, y: 284, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 492, y: 284, width: 26, height: 68)),
                LadderSpec(rect: CGRect(x: 250, y: 360, width: 26, height: 56)),
                LadderSpec(rect: CGRect(x: 420, y: 360, width: 26, height: 56))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 72, y: 152), kind: .medicine),
                HazardSpec(position: CGPoint(x: 244, y: 152), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 404, y: 152), kind: .spray),
                HazardSpec(position: CGPoint(x: 558, y: 152), kind: .chemical),
                HazardSpec(position: CGPoint(x: 132, y: 228), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 316, y: 228), kind: .medicine),
                HazardSpec(position: CGPoint(x: 508, y: 228), kind: .spray),
                HazardSpec(position: CGPoint(x: 84, y: 304), kind: .chemical),
                HazardSpec(position: CGPoint(x: 348, y: 304), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 554, y: 304), kind: .medicine),
                HazardSpec(position: CGPoint(x: 132, y: 380), kind: .spray),
                HazardSpec(position: CGPoint(x: 468, y: 380), kind: .chemical)
            ],
            enemies: [
                EnemySpec(kind: .pills, y: 146, minX: 368, maxX: 602, startX: 448, speed: 82),
                EnemySpec(kind: .cleaner, y: 222, minX: 100, maxX: 542, startX: 286, speed: 88),
                EnemySpec(kind: .chemical, y: 298, minX: 306, maxX: 602, startX: 454, speed: 82),
                EnemySpec(kind: .spray, y: 374, minX: 398, maxX: 602, startX: 526, speed: 86),
                EnemySpec(kind: .pills, y: 438, minX: 168, maxX: 478, startX: 328, speed: 80)
            ]
        ),
        LevelDefinition(
            title: "POISON CONTROL CHALLENGE",
            channelTag: "FINAL SAFETY TEST",
            psaLine: "STOP. LOOK. DON'T TOUCH. GET HELP.",
            psaDetail: "IF YOU THINK SOMEONE MAY HAVE BEEN POISONED, CALL POISON HELP AT 1-800-222-1222. FOR A LIFE-THREATENING EMERGENCY, CALL 911.",
            theme: .challenge,
            spawn: CGPoint(x: 320, y: 75),
            platforms: [
                PlatformSpec(rect: CGRect(x: 24, y: 44, width: 592, height: 16)),
                PlatformSpec(rect: CGRect(x: 24, y: 124, width: 196, height: 14)),
                PlatformSpec(rect: CGRect(x: 278, y: 124, width: 338, height: 14)),
                PlatformSpec(rect: CGRect(x: 78, y: 204, width: 484, height: 14)),
                PlatformSpec(rect: CGRect(x: 24, y: 284, width: 256, height: 14)),
                PlatformSpec(rect: CGRect(x: 338, y: 284, width: 278, height: 14)),
                PlatformSpec(rect: CGRect(x: 88, y: 364, width: 204, height: 14)),
                PlatformSpec(rect: CGRect(x: 350, y: 364, width: 210, height: 14)),
                PlatformSpec(rect: CGRect(x: 214, y: 416, width: 212, height: 14))
            ],
            ladders: [
                LadderSpec(rect: CGRect(x: 92, y: 58, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 518, y: 58, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 168, y: 138, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 438, y: 138, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 116, y: 218, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 500, y: 218, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 220, y: 298, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 408, y: 298, width: 26, height: 72)),
                LadderSpec(rect: CGRect(x: 256, y: 378, width: 26, height: 44)),
                LadderSpec(rect: CGRect(x: 372, y: 378, width: 26, height: 44))
            ],
            hazards: [
                HazardSpec(position: CGPoint(x: 70, y: 158), kind: .medicine),
                HazardSpec(position: CGPoint(x: 182, y: 158), kind: .chemical),
                HazardSpec(position: CGPoint(x: 324, y: 158), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 548, y: 158), kind: .spray),
                HazardSpec(position: CGPoint(x: 126, y: 238), kind: .spray),
                HazardSpec(position: CGPoint(x: 264, y: 238), kind: .medicine),
                HazardSpec(position: CGPoint(x: 410, y: 238), kind: .chemical),
                HazardSpec(position: CGPoint(x: 522, y: 238), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 82, y: 318), kind: .chemical),
                HazardSpec(position: CGPoint(x: 238, y: 318), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 390, y: 318), kind: .medicine),
                HazardSpec(position: CGPoint(x: 552, y: 318), kind: .spray),
                HazardSpec(position: CGPoint(x: 140, y: 398), kind: .cleaner),
                HazardSpec(position: CGPoint(x: 506, y: 398), kind: .chemical)
            ],
            enemies: [
                EnemySpec(kind: .pills, y: 152, minX: 292, maxX: 602, startX: 396, speed: 86),
                EnemySpec(kind: .cleaner, y: 232, minX: 92, maxX: 548, startX: 232, speed: 92),
                EnemySpec(kind: .spray, y: 312, minX: 352, maxX: 602, startX: 470, speed: 88),
                EnemySpec(kind: .chemical, y: 392, minX: 102, maxX: 278, startX: 184, speed: 86),
                EnemySpec(kind: .pills, y: 392, minX: 364, maxX: 548, startX: 458, speed: 88)
            ]
        )
    ]
}
