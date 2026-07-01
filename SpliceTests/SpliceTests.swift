import XCTest
@testable import Splice

final class SpliceTests: XCTestCase {

    // MARK: - Seeded RNG determinism
    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 12345)
        var b = SeededGenerator(seed: 12345)
        for _ in 0..<1000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        var same = 0
        for _ in 0..<100 where a.next() == b.next() { same += 1 }
        XCTAssertLessThan(same, 5)
    }

    func testNextUnitInRange() {
        var g = SeededGenerator(seed: 99)
        for _ in 0..<10000 {
            let u = g.nextUnit()
            XCTAssertGreaterThanOrEqual(u, 0)
            XCTAssertLessThan(u, 1)
        }
    }

    // MARK: - Daily seed
    func testDailySeedFormat() {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 25
        let date = Calendar(identifier: .gregorian).date(from: c)!
        XCTAssertEqual(SeedFactory.dailySeed(for: date), 20260625)
    }

    // MARK: - Difficulty curve
    func testWindowMonotonicDecreasing() {
        var prev = Difficulty.windowMs(forScore: 0)
        XCTAssertEqual(prev, 220, accuracy: 0.5) // 70 + 150*exp(0) = 220
        for s in stride(from: 1, through: 200, by: 1) {
            let w = Difficulty.windowMs(forScore: s)
            XCTAssertLessThanOrEqual(w, prev + 0.001)
            prev = w
        }
    }

    func testWindowClamp() {
        XCTAssertGreaterThanOrEqual(Difficulty.windowMs(forScore: 100000), 70)
        XCTAssertLessThanOrEqual(Difficulty.windowMs(forScore: 0), 220)
    }

    func testSpeedRisesWithScore() {
        let s0 = Difficulty.scrollSpeed(forScore: 0)
        let s50 = Difficulty.scrollSpeed(forScore: 50)
        XCTAssertGreaterThan(s50, s0)
    }

    func testGapShrinksWithCombo() {
        let g0 = Difficulty.gapWidth(forScore: 10, combo: 0)
        let g10 = Difficulty.gapWidth(forScore: 10, combo: 10)
        XCTAssertLessThan(g10, g0)
    }

    // MARK: - Rope model determinism
    func testRopeColorsDeterministic() {
        let r1 = RopeModel(seed: 777, paletteCount: 5)
        let r2 = RopeModel(seed: 777, paletteCount: 5)
        for i in 0..<200 {
            XCTAssertEqual(r1.colorIndex(forBead: i), r2.colorIndex(forBead: i))
        }
    }

    func testNoAdjacentSameColor() {
        let r = RopeModel(seed: 42, paletteCount: 5)
        var prev = r.colorIndex(forBead: 0)
        for i in 1..<500 {
            let c = r.colorIndex(forBead: i)
            XCTAssertNotEqual(c, prev)
            prev = c
        }
    }

    func testNearestGapIndex() {
        let r = RopeModel(seed: 1, paletteCount: 5, pitch: 100)
        // gap0 center at 50, gap1 at 150
        XCTAssertEqual(r.nearestGapIndex(toOffset: 50), 0)
        XCTAssertEqual(r.nearestGapIndex(toOffset: 149), 1)
        XCTAssertEqual(r.nearestGapIndex(toOffset: 251), 2)
    }

    // MARK: - Cut judge
    func testDeadCenterIsPerfectSplice() {
        let r = RopeModel(seed: 1, paletteCount: 5, pitch: 100)
        let gapCenter = r.gapCenterOffset(3) // 350
        let result = CutJudge.judge(rope: r, bladeOffset: gapCenter,
                                    gapWidth: 40, scrollSpeed: 500)
        if case .splice(let delta, let perfect, let idx) = result {
            XCTAssertEqual(delta, 0, accuracy: 0.001)
            XCTAssertTrue(perfect)
            XCTAssertEqual(idx, 3)
        } else {
            XCTFail("Expected splice")
        }
    }

    func testFarOffIsNick() {
        let r = RopeModel(seed: 1, paletteCount: 5, pitch: 100)
        let gapCenter = r.gapCenterOffset(2) // 250
        // 45px off with a 20px gap and slow speed should nick
        let result = CutJudge.judge(rope: r, bladeOffset: gapCenter + 45,
                                    gapWidth: 20, scrollSpeed: 100)
        if case .nick = result { } else { XCTFail("Expected nick") }
    }

    func testDeltaMsConversion() {
        let ms = CutJudge.deltaMs(deltaPx: 50, scrollSpeed: 500)
        XCTAssertEqual(ms, 100, accuracy: 0.01) // 50px / 500px/s = 0.1s = 100ms
    }

    // MARK: - Cosmetic gating
    func testProPaletteLockedUntilPurchase() {
        let pro = Cosmetics.palettes.first { $0.proOnly }!
        let store = GameStore.shared
        store.proUnlocked = false
        XCTAssertFalse(store.isPaletteUnlocked(pro))
        store.proUnlocked = true
        XCTAssertTrue(store.isPaletteUnlocked(pro))
        store.proUnlocked = false
    }

    func testEarnedPaletteUnlocksAtMilestone() {
        let earned = Cosmetics.palettes.first { ($0.unlockAtCuts ?? 0) > 0 && !$0.proOnly }!
        let store = GameStore.shared
        let original = store.lifetimeCuts
        store.lifetimeCuts = 0
        XCTAssertFalse(store.isPaletteUnlocked(earned))
        store.lifetimeCuts = earned.unlockAtCuts!
        XCTAssertTrue(store.isPaletteUnlocked(earned))
        store.lifetimeCuts = original
    }
}
