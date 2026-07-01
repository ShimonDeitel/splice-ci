import Foundation

/// UserDefaults-backed persistence + cosmetic unlock logic.
final class GameStore {
    static let shared = GameStore()
    private let d = UserDefaults.standard

    private enum Key {
        static let highScore = "splice.highScore"
        static let bestCombo = "splice.bestCombo"
        static let lifetimeCuts = "splice.lifetimeCuts"
        static let streak = "splice.streak"
        static let lastPlayed = "splice.lastPlayedDate"
        static let proUnlocked = "splice.proUnlocked"
        static let selectedPalette = "splice.selectedPalette"
        static let selectedBlade = "splice.selectedBlade"
        static let todayHigh = "splice.todayHigh"
        static let todayDate = "splice.todayDate"
    }

    var highScore: Int {
        get { d.integer(forKey: Key.highScore) }
        set { d.set(newValue, forKey: Key.highScore) }
    }
    var bestCombo: Int {
        get { d.integer(forKey: Key.bestCombo) }
        set { d.set(newValue, forKey: Key.bestCombo) }
    }
    var lifetimeCuts: Int {
        get { d.integer(forKey: Key.lifetimeCuts) }
        set { d.set(newValue, forKey: Key.lifetimeCuts) }
    }
    var streak: Int {
        get { d.integer(forKey: Key.streak) }
        set { d.set(newValue, forKey: Key.streak) }
    }
    var proUnlocked: Bool {
        get { d.bool(forKey: Key.proUnlocked) }
        set { d.set(newValue, forKey: Key.proUnlocked) }
    }
    var selectedPaletteID: String {
        get { d.string(forKey: Key.selectedPalette) ?? "neon" }
        set { d.set(newValue, forKey: Key.selectedPalette) }
    }
    var selectedBladeID: String {
        get { d.string(forKey: Key.selectedBlade) ?? "scalpel" }
        set { d.set(newValue, forKey: Key.selectedBlade) }
    }

    /// Today's best for the daily seed leaderboard.
    func todayHigh(forSeed seed: UInt64) -> Int {
        if d.object(forKey: Key.todayDate) as? UInt64 != seed { return 0 }
        let stored = d.object(forKey: Key.todayDate)
        if let s = stored as? NSNumber, s.uint64Value == seed {
            return d.integer(forKey: Key.todayHigh)
        }
        return 0
    }

    func recordTodayHigh(_ score: Int, seed: UInt64) {
        let prev = todayHigh(forSeed: seed)
        if score > prev {
            d.set(NSNumber(value: seed), forKey: Key.todayDate)
            d.set(score, forKey: Key.todayHigh)
        }
    }

    /// Called once per launch / per finished run to maintain a guilt-light streak.
    func updateStreakOnPlay(date: Date = Date()) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: date)
        if let last = d.object(forKey: Key.lastPlayed) as? Date {
            let lastDay = cal.startOfDay(for: last)
            if let diff = cal.dateComponents([.day], from: lastDay, to: today).day {
                if diff == 0 {
                    // same day, no change
                } else if diff == 1 {
                    streak += 1
                } else {
                    streak = 1
                }
            }
        } else {
            streak = 1
        }
        d.set(today, forKey: Key.lastPlayed)
    }

    /// Records the end of a run; returns true if it was a new best score.
    @discardableResult
    func recordRun(score: Int, combo: Int, seed: UInt64) -> Bool {
        lifetimeCuts += score
        var isBest = false
        if score > highScore { highScore = score; isBest = true }
        if combo > bestCombo { bestCombo = combo }
        recordTodayHigh(score, seed: seed)
        return isBest
    }

    // MARK: - Cosmetic gating

    func isPaletteUnlocked(_ p: Palette) -> Bool {
        if p.proOnly { return proUnlocked }
        if let m = p.unlockAtCuts { return lifetimeCuts >= m }
        return true
    }
    func isBladeUnlocked(_ b: BladeSkin) -> Bool {
        if b.proOnly { return proUnlocked }
        if let m = b.unlockAtCuts { return lifetimeCuts >= m }
        return true
    }

    var unlockedPalettes: [Palette] { Cosmetics.palettes.filter { isPaletteUnlocked($0) } }
    var unlockedBlades: [BladeSkin] { Cosmetics.blades.filter { isBladeUnlocked($0) } }

    var currentPalette: Palette {
        let p = Cosmetics.palette(id: selectedPaletteID)
        return isPaletteUnlocked(p) ? p : Cosmetics.palettes[0]
    }
    var currentBlade: BladeSkin {
        let b = Cosmetics.blade(id: selectedBladeID)
        return isBladeUnlocked(b) ? b : Cosmetics.blades[0]
    }
}
