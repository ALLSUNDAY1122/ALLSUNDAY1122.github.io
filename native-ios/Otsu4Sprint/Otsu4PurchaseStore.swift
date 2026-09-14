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
            await loadProduct()
            await refreshEntitlement()
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

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            premiumProduct = products.first(where: { $0.id == Self.premiumProductID })
            if premiumProduct == nil, state != .premium {
                state = .failed("商品情報を取得できませんでした")
            }
        } catch {
            if state != .premium {
                state = .failed("商品情報を取得できませんでした")
            }
        }
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

        state = entitled ? .premium : .free
    }

    func purchasePremium() async {
        guard let product = premiumProduct else {
            await loadProduct()
            guard let product = premiumProduct else { return }
            await purchase(product)
            return
        }
        await purchase(product)
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            state = .failed("購入情報を復元できませんでした")
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
            state = .failed("購入を完了できませんでした")
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
