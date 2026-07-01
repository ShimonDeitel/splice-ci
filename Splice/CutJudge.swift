import CoreGraphics
import Foundation

enum CutResult: Equatable {
    case splice(deltaPx: CGFloat, perfect: Bool, gapIndex: Int)
    case nick(deltaPx: CGFloat, gapIndex: Int, beadIndex: Int)
}

/// Pure hit-test. Given the rope offset at the touch instant (interpolated to the touch
/// timestamp), the live gap width, scroll speed, and timing tolerances, decide SPLICE vs NICK.
enum CutJudge {

    /// coyote: a gap that just crossed still counts for this long.
    static let coyoteMs: Double = 50
    /// buffer: a tap this far before a gap arrives latches to it.
    static let bufferMs: Double = 80
    /// perfect window: |delta| within this fraction of half-gap flashes gold.
    static let perfectFraction: CGFloat = 0.15

    /// rope: the bead/gap layout. bladeOffset: the rope-offset that is currently under the blade.
    /// (i.e. the rope has scrolled so that this offset aligns with the fixed blade line.)
    static func judge(rope: RopeModel,
                      bladeOffset: CGFloat,
                      gapWidth: CGFloat,
                      scrollSpeed: CGFloat) -> CutResult {

        let n = rope.nearestGapIndex(toOffset: bladeOffset)
        let gapCenter = rope.gapCenterOffset(n)
        let deltaPx = abs(gapCenter - bladeOffset)

        // Convert timing tolerances (coyote/buffer) into spatial tolerance via speed.
        let speed = max(scrollSpeed, 1)
        let coyotePx = CGFloat(coyoteMs / 1000.0) * speed
        let bufferPx = CGFloat(bufferMs / 1000.0) * speed
        let grace = max(coyotePx, bufferPx)

        let halfGap = gapWidth / 2.0
        let allowance = halfGap + grace * 0.5  // forgiveness, but small so skill dominates

        if deltaPx <= allowance {
            let perfect = deltaPx <= halfGap * perfectFraction
            return .splice(deltaPx: deltaPx, perfect: perfect, gapIndex: n)
        } else {
            // Nicked a bead: determine which bead the blade is overlapping.
            // Beads sit between gaps; bead index = n if blade is before the gap center, else n+1.
            let beadIdx = bladeOffset < gapCenter ? n : n + 1
            return .nick(deltaPx: deltaPx, gapIndex: n, beadIndex: beadIdx)
        }
    }

    /// Map a pixel delta to a millisecond readout for the UI.
    static func deltaMs(deltaPx: CGFloat, scrollSpeed: CGFloat) -> Double {
        let speed = max(Double(scrollSpeed), 1)
        return Double(deltaPx) / speed * 1000.0
    }
}
