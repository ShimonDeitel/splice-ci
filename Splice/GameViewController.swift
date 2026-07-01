import UIKit
import SpriteKit

final class GameViewController: UIViewController, GameSceneDelegate {

    private var skView: SKView!
    private var scene: GameScene!

    override func viewDidLoad() {
        super.viewDidLoad()
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120  // ProMotion
        view.addSubview(skView)

        scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.sceneDelegate = self
        skView.presentScene(scene)

        GameCenter.shared.authenticate()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: - GameSceneDelegate
    func gameSceneDidEnd(score: Int, bestCombo: Int, deltaText: String, isNewBest: Bool, snapshot: UIImage?) {
        // No-op: death UI is drawn inside the scene. Hook for analytics if desired.
    }

    func gameSceneRequestShare(score: Int, bestCombo: Int, deltaText: String, isNewBest: Bool, snapshot: UIImage?) {
        let bg = GameStore.shared.currentPalette.background
        let card = ShareCard.make(snapshot: snapshot, score: score, bestCombo: bestCombo,
                                  deltaText: deltaText, isNewBest: isNewBest, background: bg)
        let caption = "Same daily rope. Beat me.  Splice — score \(score)."
        let av = UIActivityViewController(activityItems: [card, caption], applicationActivities: nil)
        av.popoverPresentationController?.sourceView = view
        av.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(av, animated: true)
    }

    func gameSceneRequestMenu() {
        scene.showMenu()
    }
}
