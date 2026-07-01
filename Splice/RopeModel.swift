import CoreGraphics
import Foundation

/// A single bead in the rope.
struct Bead {
    let index: Int
    let width: CGFloat
    let colorIndex: Int
}

/// A gap between two beads (the thing you must cut through).
struct Gap {
    let index: Int          // gap N sits after bead N
    let centerOffset: CGFloat // distance from rope origin to this gap's center, in points
    let width: CGFloat
}

/// Deterministic infinite stream of beads + gaps from a seeded RNG.
/// Layout is along a single axis (the "rope offset"). Beads and gaps alternate:
/// bead0 | gap0 | bead1 | gap1 | ...
/// The gap widths come from the difficulty curve at cut time; here we lay out a
/// stable bead sequence and uniform nominal spacing, and the live gap width is applied
/// at render/judge time. We keep bead CENTERS deterministic by using a fixed pitch.
final class RopeModel {
    private(set) var seed: UInt64
    private var rng: SeededGenerator
    let paletteCount: Int

    /// Fixed pitch between consecutive gap centers. This is the spatial period of the rope.
    /// We keep it constant so the rope offset -> gap mapping is O(1) and deterministic.
    let pitch: CGFloat

    private var beadColors: [Int] = []   // colorIndex per bead, lazily extended

    init(seed: UInt64, paletteCount: Int, pitch: CGFloat = 96) {
        self.seed = seed
        self.rng = SeededGenerator(seed: seed)
        self.paletteCount = max(1, paletteCount)
        self.pitch = pitch
    }

    func reset(seed: UInt64) {
        self.seed = seed
        self.rng = SeededGenerator(seed: seed)
        beadColors.removeAll(keepingCapacity: true)
    }

    /// Deterministic color for bead i, avoiding identical adjacent colors.
    func colorIndex(forBead i: Int) -> Int {
        guard i >= 0 else { return 0 }
        while beadColors.count <= i {
            let n = beadColors.count
            var c = rng.nextInt(paletteCount)
            if n > 0, c == beadColors[n - 1] {
                c = (c + 1) % paletteCount
            }
            beadColors.append(c)
        }
        return beadColors[i]
    }

    /// Center offset (in points along the rope) of gap N. gap N sits between bead N and N+1.
    /// gap0 center is at one pitch from origin; consistent constant spacing.
    func gapCenterOffset(_ n: Int) -> CGFloat {
        return CGFloat(n) * pitch + pitch * 0.5
    }

    /// Index of the gap whose center is nearest a given rope offset.
    func nearestGapIndex(toOffset offset: CGFloat) -> Int {
        let raw = (offset - pitch * 0.5) / pitch
        return max(0, Int(raw.rounded()))
    }
}
