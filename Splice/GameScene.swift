import SpriteKit
import UIKit

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidEnd(score: Int, bestCombo: Int, deltaText: String, isNewBest: Bool, snapshot: UIImage?)
    func gameSceneRequestShare(score: Int, bestCombo: Int, deltaText: String, isNewBest: Bool, snapshot: UIImage?)
    func gameSceneRequestMenu()
}

final class GameScene: SKScene {

    weak var sceneDelegate: GameSceneDelegate?

    // MARK: - State
    private enum Phase { case menu, playing, dead }
    private var phase: Phase = .menu

    private var rope: RopeModel!
    private var seed: UInt64 = 0

    /// rope offset (points) currently under the blade. Advances by scrollSpeed*dt.
    private var ropeOffset: CGFloat = 0
    private var lastUpdate: TimeInterval = 0

    private var score = 0
    private var combo = 0
    private var runBestCombo = 0
    private var bufferedTapTime: TimeInterval?   // input buffering
    private var lastGapPassTime: TimeInterval = -1 // for coyote bookkeeping
    private var deadAt: TimeInterval = 0
    private var fatalDeltaText = "—"
    private var isNewBest = false
    private var deathSnapshot: UIImage?

    // hit-stop
    private var hitStopUntil: TimeInterval = 0
    private var slowMoUntil: TimeInterval = 0

    // MARK: - Nodes
    private let worldNode = SKNode()
    private let beadContainer = SKNode()
    private var bladeNode: SKShapeNode!
    private var bladeGlow: SKShapeNode!
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let deltaLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let promptLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let bestLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    // death UI
    private var deathLayer: SKNode?

    // bead pool
    private var beadPool: [SKShapeNode] = []
    private var activeBeads: [Int: SKShapeNode] = [:] // bead index -> node

    private var palette: Palette = Cosmetics.palettes[0]
    private var bladeSkin: BladeSkin = Cosmetics.blades[0]

    private var bladeScreenX: CGFloat { size.width * 0.5 }
    private let ropeY_FromCenter: CGFloat = 0
    private let beadHeight: CGFloat = 56

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = palette.background
        scaleMode = .resizeFill
        addChild(worldNode)
        worldNode.addChild(beadContainer)
        setupBlade()
        setupLabels()
        prewarmPool()
        showMenu()
        // Debug: auto-start a run for screenshot verification (set SPLICE_AUTOSTART=1).
        if ProcessInfo.processInfo.environment["SPLICE_AUTOSTART"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.startGame()
            }
        }
    }

    func applyCosmetics() {
        palette = GameStore.shared.currentPalette
        bladeSkin = GameStore.shared.currentBlade
        backgroundColor = palette.background
        bladeNode?.strokeColor = bladeSkin.color
        bladeNode?.fillColor = bladeSkin.color
        bladeGlow?.strokeColor = bladeSkin.color
    }

    private func setupBlade() {
        let bladeH: CGFloat = beadHeight + 64
        let path = CGPath(rect: CGRect(x: -2.5, y: -bladeH/2, width: 5, height: bladeH), transform: nil)
        bladeNode = SKShapeNode(path: path)
        bladeNode.fillColor = bladeSkin.color
        bladeNode.strokeColor = bladeSkin.color
        bladeNode.lineWidth = 0
        bladeNode.zPosition = 50

        bladeGlow = SKShapeNode(path: CGPath(rect: CGRect(x: -1.5, y: -bladeH/2 - 18, width: 3, height: bladeH + 36), transform: nil))
        bladeGlow.strokeColor = bladeSkin.color
        bladeGlow.lineWidth = 1
        bladeGlow.alpha = 0.35
        bladeGlow.zPosition = 49

        worldNode.addChild(bladeGlow)
        worldNode.addChild(bladeNode)
        positionBlade()
    }

    private func positionBlade() {
        guard bladeNode != nil else { return }
        bladeNode.position = CGPoint(x: bladeScreenX, y: 0)
        bladeGlow.position = CGPoint(x: bladeScreenX, y: 0)
    }

    private func setupLabels() {
        scoreLabel.fontSize = 140
        scoreLabel.fontColor = .white
        scoreLabel.zPosition = 60
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)

        comboLabel.fontSize = 40
        comboLabel.fontColor = SKColor.white.withAlphaComponent(0.85)
        comboLabel.zPosition = 60
        comboLabel.verticalAlignmentMode = .center
        addChild(comboLabel)

        deltaLabel.fontSize = 30
        deltaLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        deltaLabel.zPosition = 60
        deltaLabel.verticalAlignmentMode = .center
        addChild(deltaLabel)

        titleLabel.text = "SPLICE"
        titleLabel.fontSize = 96
        titleLabel.fontColor = .white
        titleLabel.zPosition = 60
        titleLabel.verticalAlignmentMode = .center
        addChild(titleLabel)

        promptLabel.text = "TAP TO CUT THE GAP"
        promptLabel.fontSize = 34
        promptLabel.fontColor = SKColor.white.withAlphaComponent(0.75)
        promptLabel.zPosition = 60
        promptLabel.verticalAlignmentMode = .center
        addChild(promptLabel)

        bestLabel.fontSize = 28
        bestLabel.fontColor = SKColor.white.withAlphaComponent(0.55)
        bestLabel.zPosition = 60
        bestLabel.verticalAlignmentMode = .center
        addChild(bestLabel)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        worldNode.position = CGPoint(x: 0, y: size.height * 0.5)
        beadContainer.position = .zero
        positionBlade()
        positionUI()
    }

    private func positionUI() {
        scoreLabel.position = CGPoint(x: size.width/2, y: size.height * 0.78)
        comboLabel.position = CGPoint(x: size.width/2, y: size.height * 0.68)
        deltaLabel.position = CGPoint(x: size.width/2, y: size.height * 0.34)
        titleLabel.position = CGPoint(x: size.width/2, y: size.height * 0.68)
        promptLabel.position = CGPoint(x: size.width/2, y: size.height * 0.40)
        bestLabel.position = CGPoint(x: size.width/2, y: size.height * 0.32)
    }

    // MARK: - Pool
    private func prewarmPool() {
        for _ in 0..<28 {
            let n = SKShapeNode(rectOf: CGSize(width: 60, height: beadHeight), cornerRadius: beadHeight/2)
            n.lineWidth = 0
            n.isHidden = true
            n.zPosition = 10
            beadPool.append(n)
            beadContainer.addChild(n)
        }
    }
    private func dequeueBead() -> SKShapeNode {
        for n in beadPool where n.isHidden {
            n.isHidden = false
            return n
        }
        let n = SKShapeNode(rectOf: CGSize(width: 60, height: beadHeight), cornerRadius: beadHeight/2)
        n.lineWidth = 0
        n.zPosition = 10
        beadPool.append(n)
        beadContainer.addChild(n)
        return n
    }

    // MARK: - Menu / Start
    func showMenu() {
        phase = .menu
        applyCosmetics()
        clearDeath()
        beadContainer.removeAllChildren()
        beadPool.removeAll()
        activeBeads.removeAll()
        prewarmPool()
        scoreLabel.isHidden = true
        comboLabel.isHidden = true
        deltaLabel.isHidden = true
        titleLabel.isHidden = false
        promptLabel.isHidden = false
        bestLabel.isHidden = false
        bladeNode.isHidden = false
        bladeGlow.isHidden = false
        let s = GameStore.shared
        bestLabel.text = "BEST \(s.highScore)   ·   STREAK \(s.streak)   ·   CUTS \(s.lifetimeCuts)"
        positionUI()

        // Show a static teaser rope behind the menu.
        seed = SeedFactory.dailySeed()
        rope = RopeModel(seed: seed, paletteCount: palette.paletteCount)
        ropeOffset = rope.pitch * 0.5
        renderRope(staticPreview: true)
        idleBladePulse()
    }

    private func idleBladePulse() {
        bladeNode.removeAction(forKey: "pulse")
        let pulse = SKAction.sequence([
            .scale(to: 1.15, duration: 0.7),
            .scale(to: 1.0, duration: 0.7)
        ])
        bladeNode.run(.repeatForever(pulse), withKey: "pulse")
    }

    func startGame() {
        phase = .playing
        bladeNode.removeAction(forKey: "pulse")
        bladeNode.setScale(1.0)
        applyCosmetics()
        clearDeath()
        score = 0; combo = 0; runBestCombo = 0
        bufferedTapTime = nil
        scoreLabel.isHidden = false
        comboLabel.isHidden = false
        deltaLabel.isHidden = false
        titleLabel.isHidden = true
        promptLabel.isHidden = true
        bestLabel.isHidden = true
        scoreLabel.text = "0"
        comboLabel.text = ""
        deltaLabel.text = ""
        speed = 1.0
        physicsWorld.speed = 1.0
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)

        seed = SeedFactory.dailySeed()
        rope = RopeModel(seed: seed, paletteCount: palette.paletteCount)
        ropeOffset = -size.width * 0.5  // start with the first gap approaching from the right
        lastUpdate = 0
        GameStore.shared.updateStreakOnPlay()
        SpliceAudio.shared.start()
        renderRope()
    }

    // MARK: - Touch (fire on DOWN)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let now = event?.timestamp ?? CACurrentMediaTime()
        switch phase {
        case .menu:
            startGame()
        case .playing:
            handleTap(at: now)
        case .dead:
            // ignore taps for 350ms after death, then whole screen = retry
            if CACurrentMediaTime() - deadAt >= 0.35 {
                startGame()
            }
        }
    }

    private func handleTap(at touchTime: TimeInterval) {
        // Interpolate the rope offset to the exact touch timestamp instead of waiting
        // for the next frame: offset(t) = ropeOffset + speed * (touchTime - lastUpdate)
        let speedNow = Difficulty.scrollSpeed(forScore: score)
        let dt = max(0, touchTime - lastUpdate)
        let interpolatedOffset = ropeOffset + speedNow * CGFloat(dt)

        let gapW = Difficulty.gapWidth(forScore: score, combo: combo)
        let result = CutJudge.judge(rope: rope,
                                    bladeOffset: interpolatedOffset,
                                    gapWidth: gapW,
                                    scrollSpeed: speedNow)
        switch result {
        case .splice(let deltaPx, let perfect, let gapIndex):
            performSplice(deltaPx: deltaPx, perfect: perfect, gapIndex: gapIndex, speed: speedNow)
        case .nick(let deltaPx, let gapIndex, let beadIndex):
            performNick(deltaPx: deltaPx, gapIndex: gapIndex, beadIndex: beadIndex, speed: speedNow)
        }
    }

    // MARK: - Splice
    private func performSplice(deltaPx: CGFloat, perfect: Bool, gapIndex: Int, speed: CGFloat) {
        score += 1
        combo += 1
        runBestCombo = max(runBestCombo, combo)

        let ms = CutJudge.deltaMs(deltaPx: deltaPx, scrollSpeed: speed)
        if perfect {
            deltaLabel.text = "DEAD CENTER"
            deltaLabel.fontColor = SKColor(red: 1, green: 0.83, blue: 0, alpha: 1)
        } else {
            deltaLabel.text = String(format: "off by %.0fpx", deltaPx)
            deltaLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        }

        scoreLabel.text = "\(score)"
        comboLabel.text = combo >= 2 ? "x\(combo)" : ""

        // Score bump.
        scoreLabel.removeAllActions()
        scoreLabel.setScale(1.0)
        scoreLabel.run(.sequence([.scale(to: 1.18, duration: 0.05), .scale(to: 1.0, duration: 0.08)]))

        // Blade punch.
        bladeNode.removeAllActions()
        bladeNode.setScale(1.0)
        bladeNode.run(.sequence([.scale(to: 1.25, duration: 0.05), .scale(to: 1.0, duration: 0.06)]))

        // Color flash at the blade.
        flashBlade(color: perfect ? SKColor(red: 1, green: 0.83, blue: 0, alpha: 1) : palette.beadColors[gapIndex % palette.paletteCount])

        // Particles + recoil severed segment.
        spawnShards(gapIndex: gapIndex, perfect: perfect)
        recoilSeveredSegment(gapIndex: gapIndex)

        // Audio + haptics.
        SpliceAudio.shared.snip(combo: combo)
        Haptics.shared.splice(combo: combo)

        // Near-miss slow-mo: very close to the edge.
        let gapW = Difficulty.gapWidth(forScore: score, combo: combo)
        if deltaPx > gapW * 0.42 {
            triggerSlowMo(duration: 0.12)
        }

        // Advance the rope so the cut gap is now behind the blade.
        ropeOffset = rope.gapCenterOffset(gapIndex) + 1
    }

    // MARK: - Nick (death)
    private func performNick(deltaPx: CGFloat, gapIndex: Int, beadIndex: Int, speed: CGFloat) {
        let ms = CutJudge.deltaMs(deltaPx: deltaPx, scrollSpeed: speed)
        fatalDeltaText = String(format: "off by %.0fpx", deltaPx)

        // 90ms hit-stop.
        hitStopUntil = CACurrentMediaTime() + 0.09
        self.speed = 0.0

        Haptics.shared.nick()
        SpliceAudio.shared.nick()
        shake(px: 2)

        let beadColor = palette.beadColors[beadIndex % palette.paletteCount]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self = self else { return }
            self.speed = 1.0
            self.splatter(color: beadColor)
            self.desaturateRope()
            self.endRun()
        }
    }

    private func endRun() {
        phase = .dead
        deadAt = CACurrentMediaTime()
        let store = GameStore.shared
        isNewBest = store.recordRun(score: score, combo: runBestCombo, seed: seed)
        GameCenter.shared.submit(score: score, combo: runBestCombo)

        if isNewBest {
            fullScreenFlash()
            SpliceAudio.shared.newBest()
            Haptics.shared.newBest()
            triggerSlowMo(duration: 0.25)
            shake(px: 2)
        }

        // Capture a freeze-frame for sharing.
        deathSnapshot = snapshotScene()

        sceneDelegate?.gameSceneDidEnd(score: score, bestCombo: runBestCombo,
                                       deltaText: fatalDeltaText, isNewBest: isNewBest,
                                       snapshot: deathSnapshot)
        showDeathUI()
    }

    // MARK: - Update loop
    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard phase == .playing else {
            if phase == .menu { renderRope(staticPreview: true) }
            return
        }
        if lastUpdate == 0 { lastUpdate = currentTime; return }

        // hit-stop / slow-mo restoration handled by scene.speed & timers
        let now = CACurrentMediaTime()
        if now < hitStopUntil { return }
        if now < slowMoUntil {
            // slow-mo active; scene.speed already 0.25
        } else if self.speed != 1.0 && phase == .playing {
            self.speed = 1.0
        }

        let rawDt = currentTime - lastUpdate
        let dt = CGFloat(min(rawDt, 1.0/30.0)) // clamp big hitches
        let spd = Difficulty.scrollSpeed(forScore: score)
        ropeOffset += spd * dt * CGFloat(self.speed)

        renderRope()
    }

    // MARK: - Render
    private func renderRope(staticPreview: Bool = false) {
        guard let rope = rope else { return }
        let bx = bladeScreenX
        // The rope offset under the blade is `ropeOffset`. A bead/gap at rope-position p
        // is drawn at screenX = bx + (p - ropeOffset).
        let pitch = rope.pitch
        let halfW = size.width

        // Which gap is under the blade currently.
        let centerGap = rope.nearestGapIndex(toOffset: ropeOffset)
        let span = Int(halfW / pitch) + 3

        var used = Set<Int>()
        for gi in (centerGap - span)...(centerGap + span) {
            // bead gi sits to the LEFT of gap gi; draw bead gi centered between gap (gi-1) and gap gi.
            let beadCenterPos = CGFloat(gi) * pitch  // bead gi center
            let screenX = bx + (beadCenterPos - ropeOffset)
            if screenX < -pitch || screenX > size.width + pitch { continue }
            let node = activeBeads[gi] ?? {
                let n = dequeueBead()
                activeBeads[gi] = n
                return n
            }()
            let ci = rope.colorIndex(forBead: gi)
            let beadW = Difficulty.beadWidth(forScore: score)
            // gap shrinks bead visible width slightly for the "tightening" look
            let gapW = Difficulty.gapWidth(forScore: score, combo: combo)
            let visibleW = max(pitch - gapW, 18)
            node.path = CGPath(roundedRect: CGRect(x: -visibleW/2, y: -beadHeight/2, width: visibleW, height: beadHeight),
                               cornerWidth: beadHeight/2, cornerHeight: beadHeight/2, transform: nil)
            node.fillColor = palette.beadColors[ci % palette.paletteCount]
            // tautness vibration: x-jitter proportional to combo
            let jitterAmp = CGFloat(min(combo, 12)) * 0.6
            let jitter = staticPreview ? 0 : sin(CGFloat(CACurrentMediaTime() * 30) + CGFloat(gi)) * jitterAmp
            node.position = CGPoint(x: screenX, y: jitter)
            node.isHidden = false
            used.insert(gi)
        }
        // Recycle beads no longer visible.
        for (gi, node) in activeBeads where !used.contains(gi) {
            node.isHidden = true
            activeBeads.removeValue(forKey: gi)
        }
    }

    // MARK: - Effects
    private func flashBlade(color: SKColor) {
        let h = beadHeight + 64
        let flash = SKShapeNode(rectOf: CGSize(width: 8, height: h))
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.position = CGPoint(x: bladeScreenX, y: 0)
        flash.zPosition = 48
        flash.alpha = 0.9
        worldNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func spawnShards(gapIndex: Int, perfect: Bool) {
        let count = perfect ? 14 : 9
        let c1 = palette.beadColors[gapIndex % palette.paletteCount]
        let c2 = palette.beadColors[(gapIndex + 1) % palette.paletteCount]
        for i in 0..<count {
            let shard = SKShapeNode(rectOf: CGSize(width: 4, height: 10), cornerRadius: 1)
            shard.fillColor = i % 2 == 0 ? c1 : c2
            shard.strokeColor = .clear
            shard.position = CGPoint(x: bladeScreenX, y: CGFloat.random(in: -beadHeight/2...beadHeight/2))
            shard.zPosition = 55
            worldNode.addChild(shard)
            let ang = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
            let dist = CGFloat.random(in: 40...130)
            let dx = cos(ang) * dist, dy = sin(ang) * dist
            shard.run(.group([
                .move(by: CGVector(dx: dx, dy: dy), duration: 0.4),
                .rotate(byAngle: CGFloat.random(in: -6...6), duration: 0.4),
                .fadeOut(withDuration: 0.4)
            ])) { shard.removeFromParent() }
        }
    }

    private func recoilSeveredSegment(gapIndex: Int) {
        // The severed LEFT segment becomes a transient physics body that recoils off-frame.
        let seg = SKShapeNode(rectOf: CGSize(width: 70, height: beadHeight), cornerRadius: beadHeight/2)
        seg.fillColor = palette.beadColors[gapIndex % palette.paletteCount]
        seg.strokeColor = .clear
        seg.position = CGPoint(x: bladeScreenX - 50, y: 0)
        seg.zPosition = 40
        worldNode.addChild(seg)
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 70, height: beadHeight))
        body.affectedByGravity = true
        body.collisionBitMask = 0
        seg.physicsBody = body
        body.applyImpulse(CGVector(dx: -8, dy: 4))
        body.applyAngularImpulse(0.04)
        seg.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func splatter(color: SKColor) {
        for _ in 0..<26 {
            let blob = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...16))
            blob.fillColor = color
            blob.strokeColor = .clear
            blob.alpha = CGFloat.random(in: 0.7...1.0)
            blob.position = CGPoint(x: bladeScreenX, y: CGFloat.random(in: -30...30))
            blob.zPosition = 70
            worldNode.addChild(blob)
            let ang = CGFloat.random(in: 0...(2*CGFloat.pi))
            let dist = CGFloat.random(in: 30...180)
            blob.run(.group([
                .move(by: CGVector(dx: cos(ang)*dist, dy: sin(ang)*dist), duration: 0.5),
                .scale(to: CGFloat.random(in: 0.4...1.4), duration: 0.5),
                .fadeOut(withDuration: 0.9)
            ])) { blob.removeFromParent() }
        }
    }

    private func desaturateRope() {
        for (_, node) in activeBeads {
            node.run(.colorize(with: .gray, colorBlendFactor: 0.6, duration: 0.2))
            let gray = SKColor(white: 0.4, alpha: 1)
            node.fillColor = gray
        }
    }

    private func triggerSlowMo(duration: TimeInterval) {
        slowMoUntil = CACurrentMediaTime() + duration
        self.speed = 0.25
        run(.sequence([.wait(forDuration: duration)])) { [weak self] in
            if self?.phase == .playing { self?.speed = 1.0 }
        }
    }

    private func fullScreenFlash() {
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width/2, y: 0)
        flash.zPosition = 200
        flash.alpha = 0.9
        worldNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func shake(px: CGFloat) {
        worldNode.removeAction(forKey: "shake")
        let baseY = size.height * 0.5
        let seq = SKAction.sequence([
            .moveBy(x: px, y: 0, duration: 0.02),
            .moveBy(x: -px*2, y: 0, duration: 0.02),
            .moveBy(x: px, y: 0, duration: 0.02)
        ])
        worldNode.run(seq, withKey: "shake")
        _ = baseY
    }

    // MARK: - Snapshot
    private func snapshotScene() -> UIImage? {
        guard let view = self.view else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
    }

    // MARK: - Death UI
    private func showDeathUI() {
        clearDeath()
        let layer = SKNode()
        layer.zPosition = 300
        addChild(layer)
        deathLayer = layer

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = SKColor.black.withAlphaComponent(0.55)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: size.width/2, y: size.height/2)
        layer.addChild(dim)

        let result = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        result.text = isNewBest ? "NEW BEST" : "NICKED"
        result.fontSize = 46
        result.fontColor = isNewBest ? SKColor(red: 1, green: 0.83, blue: 0, alpha: 1)
                                     : SKColor(red: 1, green: 0.27, blue: 0.33, alpha: 1)
        result.position = CGPoint(x: size.width/2, y: size.height * 0.70)
        layer.addChild(result)

        let big = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        big.text = "\(score)"
        big.fontSize = 180
        big.fontColor = .white
        big.position = CGPoint(x: size.width/2, y: size.height * 0.56)
        big.verticalAlignmentMode = .center
        layer.addChild(big)
        big.setScale(0.3)
        big.run(.sequence([.scale(to: 1.12, duration: 0.18), .scale(to: 1.0, duration: 0.10)]))

        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = "BEST COMBO  \(runBestCombo)    ·    \(fatalDeltaText)"
        sub.fontSize = 26
        sub.fontColor = SKColor.white.withAlphaComponent(0.8)
        sub.position = CGPoint(x: size.width/2, y: size.height * 0.46)
        layer.addChild(sub)

        let store = GameStore.shared
        let hi = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        hi.text = "ALL-TIME \(store.highScore)    ·    TODAY \(store.todayHigh(forSeed: seed))"
        hi.fontSize = 22
        hi.fontColor = SKColor.white.withAlphaComponent(0.55)
        hi.position = CGPoint(x: size.width/2, y: size.height * 0.41)
        layer.addChild(hi)

        // rank if available
        GameCenter.shared.fetchRank { [weak self] rank in
            guard let self = self, let rank = rank, let layer = self.deathLayer else { return }
            let r = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            r.text = "GLOBAL RANK #\(rank)"
            r.fontSize = 22
            r.fontColor = SKColor.white.withAlphaComponent(0.55)
            r.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.37)
            layer.addChild(r)
        }

        // Buttons appear after 350ms.
        layer.run(.sequence([.wait(forDuration: 0.35)])) { [weak self] in
            guard let self = self, let layer = self.deathLayer else { return }
            let retry = self.makeButton(text: "TAP ANYWHERE TO RETRY",
                                        at: CGPoint(x: self.size.width/2, y: self.size.height * 0.24),
                                        fontSize: 28)
            layer.addChild(retry)

            let share = self.makeButton(text: "SHARE", at: CGPoint(x: self.size.width * 0.30, y: self.size.height * 0.14), fontSize: 26, name: "share")
            share.fillColor = SKColor(white: 1, alpha: 0.14)
            layer.addChild(share)

            let menu = self.makeButton(text: "MENU", at: CGPoint(x: self.size.width * 0.70, y: self.size.height * 0.14), fontSize: 26, name: "menu")
            menu.fillColor = SKColor(white: 1, alpha: 0.14)
            layer.addChild(menu)
        }
    }

    private func makeButton(text: String, at pos: CGPoint, fontSize: CGFloat, name: String? = nil) -> SKShapeNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        let pad: CGFloat = 28
        let w = label.frame.width + pad * 2
        let h = label.frame.height + pad
        let btn = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: h/2)
        btn.fillColor = .clear
        btn.strokeColor = SKColor.white.withAlphaComponent(0.3)
        btn.lineWidth = 1
        btn.position = pos
        btn.addChild(label)
        if let name = name { btn.name = "btn_\(name)" }
        return btn
    }

    private func clearDeath() {
        deathLayer?.removeFromParent()
        deathLayer = nil
    }

    // Intercept share/menu button taps before generic retry.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .dead, CACurrentMediaTime() - deadAt >= 0.35 else { return }
        guard let t = touches.first, let layer = deathLayer else { return }
        let p = t.location(in: self)
        let nodes = self.nodes(at: p)
        for n in nodes {
            if n.name == "btn_share" || n.parent?.name == "btn_share" {
                sceneDelegate?.gameSceneRequestShare(score: score, bestCombo: runBestCombo,
                                                     deltaText: fatalDeltaText, isNewBest: isNewBest,
                                                     snapshot: deathSnapshot)
                return
            }
            if n.name == "btn_menu" || n.parent?.name == "btn_menu" {
                showMenu()
                return
            }
        }
        _ = layer
    }
}
