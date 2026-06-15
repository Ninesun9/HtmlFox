import Foundation
import StoreKit

/// Owns the app's monetization state: a single non-consumable "Pro" unlock plus a
/// local 3-day free trial. Pro features (editing + export) are available when the
/// user is either within the trial window or has purchased the unlock.
@MainActor
final class PurchaseManager: ObservableObject {
    static let productID = "com.htmlfox.ios.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchased = false
    @Published private(set) var isLoadingProduct = false
    @Published var purchaseError: String?

    private let trialDuration: TimeInterval = 3 * 24 * 60 * 60
    private let firstLaunchKey = "htmlfox.firstLaunchDate"
    private let firstLaunchDate: Date
    private var updatesTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: firstLaunchKey) as? Date {
            firstLaunchDate = stored
        } else {
            let now = Date()
            defaults.set(now, forKey: firstLaunchKey)
            firstLaunchDate = now
        }

        updatesTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshPurchasedState()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Access state

    private var trialEndDate: Date {
        firstLaunchDate.addingTimeInterval(trialDuration)
    }

    var isInTrial: Bool {
        !isPurchased && Date() < trialEndDate
    }

    /// Whole days left in the trial (rounded up); 0 once expired.
    var trialDaysRemaining: Int {
        guard !isPurchased else { return 0 }
        let remaining = trialEndDate.timeIntervalSinceNow
        return remaining > 0 ? Int(ceil(remaining / 86_400)) : 0
    }

    /// True when the user may use editing and export.
    var canUseProFeatures: Bool {
        isPurchased || isInTrial
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    // MARK: - StoreKit

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Initiates purchase. Returns true if the unlock is now owned.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            await loadProduct()
            guard product != nil else {
                purchaseError = String(localized: "The store is unavailable. Please try again later.")
                return false
            }
            return await purchase()
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = verifiedTransaction(verification) {
                    await transaction.finish()
                    await refreshPurchasedState()
                    return isPurchased
                }
                purchaseError = String(localized: "Could not verify the purchase.")
                return false
            case .pending:
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    /// Restores a previous purchase made with the same Apple ID.
    @discardableResult
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = error.localizedDescription
        }
        await refreshPurchasedState()
        return isPurchased
    }

    private func refreshPurchasedState() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(result) else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = await self.verifiedTransaction(update) {
                    await transaction.finish()
                    await self.refreshPurchasedState()
                }
            }
        }
    }

    private func verifiedTransaction(_ result: VerificationResult<Transaction>) -> Transaction? {
        if case .verified(let transaction) = result {
            return transaction
        }
        return nil
    }
}
