import Foundation
import StoreKit

@MainActor
public final class PurchaseController: ObservableObject {
    public enum PurchaseState: Equatable, Sendable {
        case loading
        case ready
        case purchasing
        case pending
        case purchased
        case cancelled
        case unavailable(String)
        case failed(String)
    }

    @Published public private(set) var product: Product?
    @Published public private(set) var isPremium = false
    @Published public private(set) var state: PurchaseState = .loading

    public let productID: String
    private var transactionTask: Task<Void, Never>?

    public init(productID: String) {
        self.productID = productID
        transactionTask = observeTransactions()
        Task { await refresh() }
    }

    deinit {
        transactionTask?.cancel()
    }

    public var displayPrice: String? {
        product?.displayPrice
    }

    public func refresh() async {
        await refreshEntitlement()
        await loadProduct()
    }

    public func purchase() async {
        guard let product else {
            state = .unavailable("価格を取得できません")
            return
        }
        state = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    await restoreVerifiedState(or: .failed("購入情報を検証できません"))
                    return
                }
                guard transaction.productID == productID,
                      transaction.revocationDate == nil,
                      transaction.isUpgraded == false else {
                    await transaction.finish()
                    await restoreVerifiedState(or: .failed("購入権利を確認できません"))
                    return
                }
                isPremium = true
                state = .purchased
                await transaction.finish()
            case .pending:
                await restoreVerifiedState(or: .pending)
            case .userCancelled:
                await restoreVerifiedState(or: .cancelled)
            @unknown default:
                await restoreVerifiedState(or: .failed("購入状態を確認できません"))
            }
        } catch {
            await restoreVerifiedState(or: .failed(error.localizedDescription))
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            state = isPremium ? .purchased : .ready
        } catch {
            await restoreVerifiedState(or: .failed(error.localizedDescription))
        }
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first(where: { $0.id == productID }) else {
                self.product = nil
                if !isPremium { state = .unavailable("価格を取得できません") }
                return
            }
            self.product = product
            if !isPremium { state = .ready }
        } catch {
            product = nil
            if !isPremium { state = .unavailable("価格を取得できません") }
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.productID == productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.isUpgraded == false else { continue }
            entitled = true
        }
        isPremium = entitled
        if entitled { state = .purchased }
    }

    private func restoreVerifiedState(or fallback: PurchaseState) async {
        await refreshEntitlement()
        state = isPremium ? .purchased : fallback
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await verification in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = verification else { continue }
                guard let self, transaction.productID == self.productID else { continue }
                if transaction.revocationDate == nil && !transaction.isUpgraded {
                    self.isPremium = true
                    self.state = .purchased
                } else {
                    self.isPremium = false
                    self.state = .ready
                }
                await transaction.finish()
            }
        }
    }
}
