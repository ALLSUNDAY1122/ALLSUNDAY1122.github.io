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
    enum Status: Equatable { case unconfigured, loading, ready, purchasing, restoring, unavailable, failed }

    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var status: Status = .unconfigured
    @Published private(set) var message: String?

    let productID: String?
    private var updatesTask: Task<Void, Never>?

    init(productID: String? = nil) {
        let trimmed = productID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productID = (trimmed?.isEmpty == false) ? trimmed : nil
        status = self.productID == nil ? .unconfigured : .loading
    }

    deinit { updatesTask?.cancel() }

    var isConfigured: Bool { productID != nil }
    var displayPrice: String? { product?.displayPrice }

    func prepare() async {
        guard let productID else {
            status = .unconfigured
            return
        }

        updatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard !Task.isCancelled else { return }
                switch verification {
                case .verified(let transaction):
                    guard transaction.productID == productID else { continue }
                    await self?.refreshEntitlements()
                    await transaction.finish()
                case .unverified:
                    continue
                }
            }
        }

        status = .loading
        do {
            let products = try await Product.products(for: [productID])
            guard let item = products.first(where: { $0.id == productID }),
                  item.type == .nonConsumable else {
                status = .unavailable
                message = "App Store Connectの非消耗型商品を確認できません。"
                return
            }
            product = item
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
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    guard transaction.productID == productID else {
                        status = .failed
                        message = "購入商品の識別情報が一致しません。"
                        return
                    }
                    let outcome: PremiumAccessPolicy.Outcome = transaction.revocationDate == nil ? .verifiedActive : .verifiedRevoked
                    isPremium = PremiumAccessPolicy.grantsAccess(for: outcome)
                    await transaction.finish()
                    await refreshEntitlements()
                    status = .ready
                case .unverified:
                    isPremium = PremiumAccessPolicy.grantsAccess(for: .unverified)
                    status = .ready
                    message = "購入情報を検証できないため機能は解放していません。"
                }
            case .pending:
                isPremium = PremiumAccessPolicy.grantsAccess(for: .pending)
                status = .ready
                message = "購入は保留中です。承認後に再確認します。"
            case .userCancelled:
                isPremium = PremiumAccessPolicy.grantsAccess(for: .cancelled)
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
        guard let productID else {
            isPremium = false
            return
        }
        var active = false
        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
                guard transaction.productID == productID else { continue }
                if PremiumAccessPolicy.grantsAccess(for: transaction.revocationDate == nil ? .verifiedActive : .verifiedRevoked) {
                    active = true
                }
            case .unverified:
                continue
            }
        }
        isPremium = active
    }
}
