import SpriteKit

/// A bead/rope palette. Procedural colors come from these.
struct Palette {
    let id: String
    let name: String
    let beadColors: [SKColor]
    let ropeColor: SKColor
    let background: SKColor
    /// Lifetime-cut milestone to unlock for free, or nil if default / pro-only.
    let unlockAtCuts: Int?
    let proOnly: Bool

    var paletteCount: Int { beadColors.count }
}

/// A blade skin.
struct BladeSkin {
    let id: String
    let name: String
    let color: SKColor
    let unlockAtCuts: Int?
    let proOnly: Bool
}

enum Cosmetics {
    static let palettes: [Palette] = [
        Palette(id: "neon", name: "Neon",
                beadColors: [c(0x00E5FF), c(0xFF2D95), c(0xB14BFF), c(0x39FF14), c(0xFFD400)],
                ropeColor: c(0x2A2A33), background: c(0x0B0B10),
                unlockAtCuts: nil, proOnly: false),
        Palette(id: "candy", name: "Candy",
                beadColors: [c(0xFF6B6B), c(0xFFD93D), c(0x6BCB77), c(0x4D96FF), c(0xFF8FB1)],
                ropeColor: c(0x2A2A33), background: c(0x14101A),
                unlockAtCuts: 200, proOnly: false),
        Palette(id: "ink", name: "Monochrome Ink",
                beadColors: [c(0xF2F2F2), c(0xBFBFBF), c(0x8C8C8C), c(0x595959), c(0xE0E0E0)],
                ropeColor: c(0x222222), background: c(0x000000),
                unlockAtCuts: 1000, proOnly: false),
        Palette(id: "pastel", name: "Pastel ASMR",
                beadColors: [c(0xFFADAD), c(0xFFD6A5), c(0xCAFFBF), c(0x9BF6FF), c(0xBDB2FF)],
                ropeColor: c(0x33303A), background: c(0x1B1820),
                unlockAtCuts: 5000, proOnly: false),
        Palette(id: "sunset", name: "Sunset (Pro)",
                beadColors: [c(0xFF512F), c(0xF09819), c(0xFFD200), c(0xFF6E7F), c(0xBC4E9C)],
                ropeColor: c(0x2A1A26), background: c(0x120A12),
                unlockAtCuts: nil, proOnly: true),
        Palette(id: "ocean", name: "Abyss (Pro)",
                beadColors: [c(0x00F5D4), c(0x00BBF9), c(0x9B5DE5), c(0x0096C7), c(0x48CAE4)],
                ropeColor: c(0x10202A), background: c(0x05121A),
                unlockAtCuts: nil, proOnly: true),
    ]

    static let blades: [BladeSkin] = [
        BladeSkin(id: "scalpel", name: "Scalpel", color: c(0xFFFFFF), unlockAtCuts: nil, proOnly: false),
        BladeSkin(id: "laser", name: "Laser Line", color: c(0xFF2D55), unlockAtCuts: 500, proOnly: false),
        BladeSkin(id: "gold", name: "Gold Edge", color: c(0xFFD400), unlockAtCuts: 2500, proOnly: false),
        BladeSkin(id: "katana", name: "Katana (Pro)", color: c(0xC0F7FF), unlockAtCuts: nil, proOnly: true),
        BladeSkin(id: "glass", name: "Glass Shard (Pro)", color: c(0x9BF6FF), unlockAtCuts: nil, proOnly: true),
    ]

    static func palette(id: String) -> Palette {
        palettes.first { $0.id == id } ?? palettes[0]
    }
    static func blade(id: String) -> BladeSkin {
        blades.first { $0.id == id } ?? blades[0]
    }

    static func c(_ hex: UInt32) -> SKColor {
        SKColor(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: 1.0)
    }
}
