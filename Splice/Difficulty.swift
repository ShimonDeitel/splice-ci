import CoreGraphics
import Foundation

/// The single difficulty knob. score -> effectiveWindowMs, and scrollSpeed + gapWidth
/// are both derived from it so they move in lockstep.
enum Difficulty {
    static let windowFloorMs: Double = 70
    static let windowCeilMs: Double = 220
    static let decayConstant: Double = 40

    /// window = clamp(70 + 150 * exp(-score/40), 70, 220) ms
    static func windowMs(forScore score: Int) -> Double {
        let raw = windowFloorMs + 150.0 * exp(-Double(score) / decayConstant)
        return min(max(raw, windowFloorMs), windowCeilMs)
    }

    /// Scroll speed in points/sec, derived from the same curve.
    /// As the window shrinks, the rope scrolls faster. We invert the window:
    /// generous window -> slow, tight window -> fast.
    static func scrollSpeed(forScore score: Int) -> CGFloat {
        let w = windowMs(forScore: score)
        // Map window [70,220] -> speed [maxSpeed, minSpeed]
        let minSpeed: CGFloat = 320
        let maxSpeed: CGFloat = 920
        let t = (w - windowFloorMs) / (windowCeilMs - windowFloorMs) // 1 at start, 0 at floor
        return maxSpeed - CGFloat(t) * (maxSpeed - minSpeed)
    }

    /// Gap width in points. window(ms) * speed(px/s) / 1000 gives the spatial window;
    /// gap is that window so the time-tolerance equals the window. Combo shrinks it further.
    static func gapWidth(forScore score: Int, combo: Int) -> CGFloat {
        let w = windowMs(forScore: score)
        let speed = scrollSpeed(forScore: score)
        let spatial = CGFloat(w / 1000.0) * speed
        // Combo tightens the noose: up to ~30% extra shrink, saturating.
        let comboShrink = CGFloat(1.0 - min(Double(combo), 12.0) / 12.0 * 0.30)
        return max(spatial * comboShrink, 8.0)
    }

    /// Bead width grows a touch with score for variety but stays readable.
    static func beadWidth(forScore score: Int) -> CGFloat {
        return 64
    }
}
