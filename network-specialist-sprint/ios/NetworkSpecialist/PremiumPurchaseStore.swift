import Foundation
import Combine
import StoreKit

enum PremiumAccessPolicy {
    enum Outcome: Equatable {
        case verifiedActive
        case verifiedRevoked
        case unverified
        case pending
        case cancelled
    }

    static func grantsAccess(for outcome: Outcome) -> Bool {
        outcome == .verifiedActive
    }
}

@MainActor
final class PremiumPurchaseStore: ObservableObject {
    enum Status: Equatable {
        case unconfigured
        case loading
        case ready
        case purchasing
        case restoring
        case unavailable
        case failed
    }

    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var status: Status
    @Published private(set) var message: String?

    let productID: String?
    private var transactionUpdatesTask: Task<Void, Never>?
    private var hasPrepared = false
    private let uiTestForcesPremium: Bool
    private let uiTestBypassesStoreKit: Bool

    init(bundle: Bundle = .main, productID: String? = nil, processInfo: ProcessInfo = .processInfo) {
        let explicitID = Self.normalized(productID)
        let plistID = Self.normalized(bundle.object(forInfoDictionaryKey: "PremiumProductID") as? String)
        let resolved = explicitID ?? plistID
        #if DEBUG
        let forcedPremium = processInfo.arguments.contains("-UITestPremium")
        let forcedFree = processInfo.arguments.contains("-UITestFree")
        #else
        let forcedPremium = false
        let forcedFree = false
        #endif
        self.productID = resolved
        self.uiTestForcesPremium = forcedPremium
        self.uiTestBypassesStoreKit = forcedPremium || forcedFree
        self.isPremium = forcedPremium
        self.status = (forcedPremium || forcedFree) ? .ready : (resolved == nil ? .unconfigured : .loading)
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isConfigured: Bool { productID != nil }
    var displayPrice: String? { product?.displayPrice }

    func prepare() async {
        guard !uiTestBypassesStoreKit else { return }
        guard !hasPrepared else { return }
        hasPrepared = true
        guard let productID else {
            status = .unconfigured
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handleTransactionUpdate(verification)
            }
        }

        status = .loading
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first(where: { $0.id == productID }),
                  product.type == .nonConsumable else {
                self.product = nil
                status = .unavailable
                message = "App Store Connectの非消耗型商品を確認できません。"
                return
            }
            self.product = product
            await refreshEntitlements()
            status = .ready
        } catch {
            status = .failed
            message = error.localizedDescription
        }
    }

    func purchase() async {
        guard let productID, let product, product.id == productID else {
            status = isConfigured ? .unavailable : .unconfigured
            return
        }

        status = .purchasing
        message = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    guard transaction.productID == productID else {
                        status = .failed
                        message = "購入商品の識別情報が一致しません。"
                        return
                    }
                    if PremiumAccessPolicy.grantsAccess(for: transaction.revocationDate == nil ? .verifiedActive : .verifiedRevoked) {
                        isPremium = true
                    } else {
                        isPremium = false
                    }
                    await transaction.finish()
                    await refreshEntitlements()
                    status = .ready
                case .unverified:
                    _ = PremiumAccessPolicy.grantsAccess(for: .unverified)
                    status = .ready
                    message = "購入情報を検証できなかったため、機能は解放していません。"
                }
            case .pending:
                _ = PremiumAccessPolicy.grantsAccess(for: .pending)
                status = .ready
                message = "購入は保留中です。承認後に自動で再確認します。"
            case .userCancelled:
                _ = PremiumAccessPolicy.grantsAccess(for: .cancelled)
                status = .ready
            @unknown default:
                status = .failed
                message = "未対応の購入状態です。"
            }
        } catch {
            status = .failed
            message = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isConfigured else {
            status = .unconfigured
            return
        }
        status = .restoring
        message = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            status = .ready
            message = isPremium ? "購入状態を復元しました。" : "復元できる購入はありませんでした。"
        } catch {
            status = .failed
            message = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        guard !uiTestForcesPremium else {
            isPremium = true
            return
        }
        guard !uiTestBypassesStoreKit else {
            isPremium = false
            return
        }
        guard let productID else {
            isPremium = false
            return
        }

        var entitled = false
        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
                guard transaction.productID == productID else { continue }
                if transaction.revocationDate == nil {
                    entitled = true
                }
            case .unverified:
                continue
            }
        }
        isPremium = entitled
    }

    func clearMessage() {
        message = nil
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        guard let productID else { return }
        switch verification {
        case .verified(let transaction):
            guard transaction.productID == productID else { return }
            await refreshEntitlements()
            await transaction.finish()
        case .unverified:
            return
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
