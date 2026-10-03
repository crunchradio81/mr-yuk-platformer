import SpriteKit

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xff) / 255.0
        let g = CGFloat((hex >> 8) & 0xff) / 255.0
        let b = CGFloat(hex & 0xff) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

enum GamePalette {
    static let yukGreen = SKColor(hex: 0x5CFF38)
    static let phosphorGreen = SKColor(hex: 0xB7FF86)
    static let warningYellow = SKColor(hex: 0xFFE85A)
    static let dangerRed = SKColor(hex: 0xFF4A4A)
    static let cleanerBlue = SKColor(hex: 0x57D9FF)
    static let medicinePink = SKColor(hex: 0xFF77AA)
    static let offWhite = SKColor(hex: 0xF2F0D8)
    static let charcoal = SKColor(hex: 0x111411)
    static let nearBlack = SKColor(hex: 0x050705)
    static let concrete = SKColor(hex: 0x3A4239)
    static let brown = SKColor(hex: 0x6A4630)
    static let tileBlue = SKColor(hex: 0x355E73)
    static let kitchenCream = SKColor(hex: 0xE7D8A5)
    static let vhsMagenta = SKColor(hex: 0xEE55C4)
    static let vhsCyan = SKColor(hex: 0x48F5F0)
}
