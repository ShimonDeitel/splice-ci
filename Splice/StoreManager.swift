import StoreKit

/// StoreKit 2 manager for the single non-consumable `splice_pro`.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let proProductID = "splice_pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool = GameStore.shared.proUnlocked
    @Published private(set) var purchasing = false
    @Published private(set) var statusMessage: String = ""

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            self.product = products.first
        } catch {
            statusMessage = "Could not load store."
        }
    }

    func purchase() async {
        guard let product = product else {
            statusMessage = "Store unavailable."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await unlockPro()
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            statusMessage = "Purchase failed."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPro ? "Pro restored." : "Nothing to restore."
        } catch {
            statusMessage = "Restore failed."
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        if owned { await unlockPro() }
        else {
            isPro = GameStore.shared.proUnlocked // keep any prior local unlock
        }
    }

    private func unlockPro() async {
        GameStore.shared.proUnlocked = true
        isPro = true
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == Self.proProductID,
                       transaction.revocationDate == nil {
                        await self?.unlockPro()
                    }
                    await transaction.finish()
                }
            }
        }
    }
}
