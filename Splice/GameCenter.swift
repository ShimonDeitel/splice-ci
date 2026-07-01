import GameKit
import UIKit

/// Silent Game Center auth + leaderboard submission. No wall: if auth fails, the game
/// is fully playable, submission is simply skipped.
final class GameCenter {
    static let shared = GameCenter()

    static let highScoreBoard = "splice_highscore"
    static let todayBoard = "splice_today"

    private(set) var authenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let vc = viewController {
                // Present silently only if we can; otherwise skip.
                Self.topViewController()?.present(vc, animated: true)
                return
            }
            self?.authenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    func submit(score: Int, combo: Int) {
        guard authenticated, GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [Self.highScoreBoard, Self.todayBoard])
        }
    }

    /// Fetches the player's rank on the all-time board, if available.
    func fetchRank(completion: @escaping (Int?) -> Void) {
        guard authenticated, GKLocalPlayer.local.isAuthenticated else { completion(nil); return }
        Task {
            do {
                let boards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.highScoreBoard])
                guard let board = boards.first else { completion(nil); return }
                let (local, _) = try await board.loadEntries(for: [GKLocalPlayer.local],
                                                             timeScope: .allTime)
                await MainActor.run { completion(local?.rank) }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }

    static func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(presented) }
        return root
    }
}
