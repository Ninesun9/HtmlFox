import Foundation
import Security
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

    /// Bumped whenever `isInTrial` / `trialDaysRemaining` may have changed without a
    /// matching `@Published` mutation (e.g. midnight rollover). Views that surface
    /// trial state can observe this to recompute.
    @Published private(set) var trialTick: Int = 0

    private let trialDuration: TimeInterval = 3 * 24 * 60 * 60
    private let firstLaunchDate: Date
    private var updatesTask: Task<Void, Never>?

    init() {
        firstLaunchDate = TrialAnchorStore.loadOrCreate()

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

    /// Called by the app when becoming active so trial-derived UI re-evaluates
    /// without needing the user to interact. Cheap — just bumps a counter.
    func refreshTrialState() {
        trialTick &+= 1
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
        if product == nil {
            await loadProduct()
        }

        guard let product else {
            purchaseError = String(localized: "The store is unavailable. Please try again later.")
            return false
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
            case .pending, .userCancelled:
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

/// Persists the trial anchor in the Keychain so reinstalling the app does not
/// hand the user a fresh trial. Falls back to UserDefaults if the Keychain is
/// unavailable (e.g. on a simulator without the proper entitlements).
private enum TrialAnchorStore {
    private static let service = "com.htmlfox.ios"
    private static let account = "trial.firstLaunchDate"
    private static let userDefaultsKey = "htmlfox.firstLaunchDate"

    static func loadOrCreate() -> Date {
        if let existing = load() {
            return existing
        }
        let now = Date()
        save(now)
        return now
    }

    private static func load() -> Date? {
        if let date = readFromKeychain() {
            return date
        }
        // Migrate any pre-existing UserDefaults anchor into the Keychain so users
        // who installed prior versions keep their original trial start date.
        if let stored = UserDefaults.standard.object(forKey: userDefaultsKey) as? Date {
            writeToKeychain(stored)
            return stored
        }
        return nil
    }

    private static func save(_ date: Date) {
        writeToKeychain(date)
        UserDefaults.standard.set(date, forKey: userDefaultsKey)
    }

    private static func readFromKeychain() -> Date? {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let interval = TimeInterval(String(data: data, encoding: .utf8) ?? "")
        else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    private static func writeToKeychain(_ date: Date) {
        guard let data = String(date.timeIntervalSince1970).data(using: .utf8) else { return }

        var query = baseQuery()
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private static func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}
