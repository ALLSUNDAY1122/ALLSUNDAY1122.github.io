import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyProductID = "jp.allsunday1122.healthmanager2.monthly"
    static let lifetimeProductID = "jp.allsunday1122.healthmanager2.lifetime"
    static let productIDs = [monthlyProductID, lifetimeProductID]

    // HM2 is sold in Japan at these canonical App Store Connect price points.
    // Keep the paywall presentation stable even when TestFlight temporarily
    // serves stale storefront metadata. The Apple purchase sheet remains the
    // authority for the actual transaction.
    static let monthlyJapanDisplayPrice = "¥200/月"
    static let lifetimeJapanDisplayPrice = "¥800"

    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var entitlementSource = "none"
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

    deinit { updatesTask?.cancel() }

    private var reviewMonthlyPriceOverride: String? {
#if DEBUG
        let value = ProcessInfo.processInfo.environment["HM2_REVIEW_MONTHLY_PRICE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
#else
        return nil
#endif
    }

    private var reviewLifetimePriceOverride: String? {
#if DEBUG
        let value = ProcessInfo.processInfo.environment["HM2_REVIEW_LIFETIME_PRICE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
#else
        return nil
#endif
    }

    var monthlyDisplayPrice: String {
        reviewMonthlyPriceOverride ?? Self.monthlyJapanDisplayPrice
    }

    var lifetimeDisplayPrice: String {
        reviewLifetimePriceOverride ?? Self.lifetimeJapanDisplayPrice
    }

    var monthlyAvailable: Bool { reviewMonthlyPriceOverride != nil || monthlyProduct != nil }
    var lifetimeAvailable: Bool { reviewLifetimePriceOverride != nil || lifetimeProduct != nil }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)

            // Match both ID and StoreKit product type. This prevents a malformed
            // App Store Connect response/configuration from ever wiring the
            // monthly button to the lifetime product (or vice versa).
            monthlyProduct = products.first {
                $0.id == Self.monthlyProductID && $0.type == .autoRenewable
            }
            lifetimeProduct = products.first {
                $0.id == Self.lifetimeProductID && $0.type == .nonConsumable
            }

            if monthlyProduct == nil || lifetimeProduct == nil {
                if reviewMonthlyPriceOverride == nil || reviewLifetimePriceOverride == nil {
                    statusMessage = "商品情報の種類または価格設定を確認できません。App Store Connect設定を確認してください。"
                }
            } else if !isPremium {
                statusMessage = ""
            }
        } catch {
            if reviewMonthlyPriceOverride == nil || reviewLifetimePriceOverride == nil {
                statusMessage = "商品情報を取得できませんでした。"
            }
        }
    }

    func refreshEntitlement() async {
        var hasMonthly = false
        var hasLifetime = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.lifetimeProductID { hasLifetime = true }
            if transaction.productID == Self.monthlyProductID { hasMonthly = true }
        }

        isPremium = hasLifetime || hasMonthly
        entitlementSource = hasLifetime ? "lifetime" : (hasMonthly ? "monthly" : "none")
    }

    func purchase(productID: String) async {
        if monthlyProduct == nil || lifetimeProduct == nil { await loadProducts() }

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

        // Fail closed if a product ever arrives with an unexpected StoreKit type.
        if productID == Self.monthlyProductID && product.type != .autoRenewable {
            statusMessage = "月額商品の設定を確認できません。"
            return
        }
        if productID == Self.lifetimeProductID && product.type != .nonConsumable {
            statusMessage = "買い切り商品の設定を確認できません。"
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await refreshEntitlement()
                await transaction.finish()
                statusMessage = isPremium ? "プレミアムを利用できます。" : "購入資格を確認できませんでした。"
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
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }

    enum StoreError: Error { case failedVerification }
}
