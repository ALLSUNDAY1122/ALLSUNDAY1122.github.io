import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyProductID = "jp.allsunday1122.healthmanager1.monthly"
    static let lifetimeProductID = "jp.allsunday1122.healthmanager1.lifetime"
    static let productIDs = [monthlyProductID, lifetimeProductID]

    // HM1 is currently sold only in Japan. App Store Connect is canonical at
    // JPY 200/month and JPY 800 lifetime. Keep the in-app presentation aligned
    // with those JPN price points even if TestFlight temporarily serves stale
    // Product.displayPrice metadata; the Apple purchase sheet remains the
    // transaction authority.
    static let monthlyJapanDisplayPrice = "¥200"
    static let lifetimeJapanDisplayPrice = "¥800"

    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var entitlementSource = "none"
    @Published private(set) var monthlyIntroEligible = false
    @Published private(set) var monthlyHasSevenDayFreeTrial = false
    @Published private(set) var statusMessage = ""

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(update)
                    await self.refreshEntitlement()
                    await transaction.finish()
                } catch {
                    self.statusMessage = "購入情報を確認できませんでした。"
                }
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var monthlyDisplayPrice: String {
        Self.monthlyJapanDisplayPrice
    }

    var lifetimeDisplayPrice: String {
        Self.lifetimeJapanDisplayPrice
    }

    var monthlyAvailable: Bool { monthlyProduct != nil }
    var lifetimeAvailable: Bool { lifetimeProduct != nil }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)
            monthlyProduct = products.first { $0.id == Self.monthlyProductID }
            lifetimeProduct = products.first { $0.id == Self.lifetimeProductID }

            if let subscription = monthlyProduct?.subscription {
                monthlyIntroEligible = await subscription.isEligibleForIntroOffer
                if let offer = subscription.introductoryOffer,
                   offer.paymentMode == .freeTrial {
                    let p = offer.period
                    monthlyHasSevenDayFreeTrial =
                        (p.unit == .week && p.value == 1) ||
                        (p.unit == .day && p.value == 7)
                } else {
                    monthlyHasSevenDayFreeTrial = false
                }
            } else {
                monthlyIntroEligible = false
                monthlyHasSevenDayFreeTrial = false
            }

            if monthlyProduct == nil || lifetimeProduct == nil {
                statusMessage = "一部の商品情報を取得できません。App Store Connect設定を確認してください。"
            }
        } catch {
            statusMessage = "商品情報を取得できませんでした。"
        }
    }

    func refreshEntitlement() async {
        var hasMonthly = false
        var hasLifetime = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  transaction.revocationDate == nil else { continue }

            if transaction.productID == Self.lifetimeProductID {
                hasLifetime = true
            }
            if transaction.productID == Self.monthlyProductID {
                hasMonthly = true
            }
        }

        isPremium = hasLifetime || hasMonthly
        entitlementSource = hasLifetime ? "lifetime" : (hasMonthly ? "monthly" : "none")
    }

    func purchase(productID: String) async {
        if monthlyProduct == nil || lifetimeProduct == nil {
            await loadProducts()
        }

        let product: Product?
        switch productID {
        case Self.monthlyProductID:
            product = monthlyProduct
        case Self.lifetimeProductID:
            product = lifetimeProduct
        default:
            product = nil
        }

        guard let product else {
            statusMessage = "選択した商品情報を取得できません。"
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await refreshEntitlement()
                await transaction.finish()
                statusMessage = isPremium ? "プレミアムが有効になりました。" : "購入資格を確認できませんでした。"
            case .pending:
                statusMessage = "購入は保留中です。承認後に自動で反映されます。"
            case .userCancelled:
                statusMessage = ""
            @unknown default:
                statusMessage = "購入状態を確認できませんでした。"
            }
        } catch {
            statusMessage = "購入処理に失敗しました。"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            statusMessage = isPremium ? "購入を復元しました。" : "復元できる購入はありませんでした。"
        } catch {
            statusMessage = "購入の復元に失敗しました。"
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
