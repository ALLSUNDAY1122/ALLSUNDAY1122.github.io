import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyProductID = "jp.allsunday1122.healthmanager2.monthly"
    static let lifetimeProductID = "jp.allsunday1122.healthmanager2.lifetime"
    static let productIDs = [monthlyProductID, lifetimeProductID]

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

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? "App Storeで価格を確認"
    }

    var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? "App Storeで価格を確認"
    }

    var monthlyAvailable: Bool { monthlyProduct != nil }
    var lifetimeAvailable: Bool { lifetimeProduct != nil }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)
            monthlyProduct = products.first { $0.id == Self.monthlyProductID }
            lifetimeProduct = products.first { $0.id == Self.lifetimeProductID }
            if monthlyProduct == nil || lifetimeProduct == nil {
                statusMessage = "商品情報を取得できません。App Store Connect設定を確認してください。"
            } else if !isPremium {
                statusMessage = ""
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
            if transaction.productID == Self.lifetimeProductID { hasLifetime = true }
            if transaction.productID == Self.monthlyProductID { hasMonthly = true }
        }

        isPremium = hasLifetime || hasMonthly
        entitlementSource = hasLifetime ? "lifetime" : (hasMonthly ? "monthly" : "none")
    }

    func purchase(productID: String) async {
        if monthlyProduct == nil || lifetimeProduct == nil { await loadProducts() }
        let product = productID == Self.monthlyProductID ? monthlyProduct :
            (productID == Self.lifetimeProductID ? lifetimeProduct : nil)

        guard let product else {
            statusMessage = "選択した商品情報を取得できません。"
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
