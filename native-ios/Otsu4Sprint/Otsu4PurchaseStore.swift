import Foundation
import Combine
import StoreKit

@MainActor
final class Otsu4PurchaseStore: ObservableObject {
    static let premiumProductID = "jp.allsunday1122.otsu4.premium"

    enum PurchaseState: Equatable {
        case loading
        case free
        case premium
        case purchasing
        case pending
        case failed(String)
    }

    @Published private(set) var state: PurchaseState = .loading
    @Published private(set) var premiumProduct: Product?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()
        Task {
            await refreshEntitlement()
            if !isPremium {
                await loadProduct()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var isPremium: Bool {
        state == .premium
    }

    var displayPrice: String {
        premiumProduct?.displayPrice ?? "—"
    }

    var canPurchase: Bool {
        premiumProduct != nil && !isBusy
    }

    var isBusy: Bool {
        switch state {
        case .loading, .purchasing:
            return true
        default:
            return false
        }
    }

    func loadProduct() async {
        guard state != .premium else { return }
        state = .loading

        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
                premiumProduct = nil
                state = .failed("App Storeの商品情報を取得できませんでした。通信状態を確認して再読み込みしてください。")
                return
            }
            premiumProduct = product
            if state != .premium {
                state = .free
            }
        } catch {
            premiumProduct = nil
            if state != .premium {
                state = .failed("App Storeの商品情報を取得できませんでした。通信状態を確認して再読み込みしてください。")
            }
        }
    }

    func retryProductLoad() async {
        await loadProduct()
    }

    func refreshEntitlement() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.premiumProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.isUpgraded == false else { continue }
            entitled = true
            break
        }

        if entitled {
            state = .premium
        } else if case .failed = state {
            // Keep the actionable StoreKit error visible instead of masking it as .free.
        } else if state != .purchasing {
            state = .free
        }
    }

    func purchasePremium() async {
        if premiumProduct == nil {
            await loadProduct()
        }
        guard let product = premiumProduct else { return }
        await purchase(product)
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPremium, premiumProduct == nil {
                await loadProduct()
            }
        } catch {
            state = .failed("購入情報を復元できませんでした。App Storeへサインインしていることを確認してください。")
        }
    }

    private func purchase(_ product: Product) async {
        state = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    state = .failed("購入情報を確認できませんでした")
                    return
                }
                guard transaction.productID == Self.premiumProductID,
                      transaction.revocationDate == nil,
                      transaction.isUpgraded == false else {
                    state = .failed("購入商品を確認できませんでした")
                    return
                }
                await transaction.finish()
                await refreshEntitlement()

            case .pending:
                state = .pending

            case .userCancelled:
                await refreshEntitlement()

            @unknown default:
                await refreshEntitlement()
            }
        } catch {
            state = .failed("購入を完了できませんでした。時間をおいて再度お試しください。")
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                guard transaction.productID == Self.premiumProductID else {
                    await transaction.finish()
                    continue
                }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }
}
