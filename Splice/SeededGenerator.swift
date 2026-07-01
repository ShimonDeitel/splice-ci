import Foundation

/// Deterministic SplitMix64 RNG. Same seed -> same stream on every device.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid a zero state producing a degenerate stream.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    mutating func nextUnit() -> Double {
        // Use the top 53 bits for a clean double.
        return Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    /// Uniform double in [lower, upper).
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        return range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    /// Uniform int in [0, count).
    mutating func nextInt(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(next() % UInt64(count))
    }
}

enum SeedFactory {
    /// Daily seed = Int(yyyymmdd) so everyone gets the same rope each calendar day.
    static func dailySeed(for date: Date = Date()) -> UInt64 {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 2026
        let m = c.month ?? 1
        let d = c.day ?? 1
        return UInt64(y * 10000 + m * 100 + d)
    }
}
