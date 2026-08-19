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
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isPremium = false
    @Published public private(set) var state: PurchaseState = .loading

    public let productID: String
    public let productIDs: [String]
    private var transactionTask: Task<Void, Never>?

    public init(productID: String) {
        self.productID = productID
        self.productIDs = [productID]
        transactionTask = observeTransactions()
        Task { await refresh() }
    }

    public init(productIDs: [String]) {
        let normalized = Array(NSOrderedSet(array: productIDs)) as? [String] ?? productIDs
        precondition(!normalized.isEmpty, "At least one StoreKit product ID is required")
        self.productIDs = normalized
        self.productID = normalized[0]
        transactionTask = observeTransactions()
        Task { await refresh() }
    }

    deinit {
        transactionTask?.cancel()
    }

    public var displayPrice: String? {
        product?.displayPrice
    }

    public func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    public func displayPrice(for id: String) -> String? {
        product(for: id)?.displayPrice
    }

    public func refresh() async {
        await refreshEntitlement()
        await loadProducts()
    }

    public func purchase() async {
        await purchase(productID: productID)
    }

    public func purchase(productID id: String) async {
        guard productIDs.contains(id), let selectedProduct = product(for: id) else {
            state = .unavailable("価格を取得できません")
            return
        }
        state = .purchasing
        do {
            let result = try await selectedProduct.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    await restoreVerifiedState(or: .failed("購入情報を検証できません"))
                    return
                }
                guard productIDs.contains(transaction.productID),
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

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { lhs, rhs in
                let li = productIDs.firstIndex(of: lhs.id) ?? Int.max
                let ri = productIDs.firstIndex(of: rhs.id) ?? Int.max
                return li < ri
            }
            product = products.first(where: { $0.id == productID })
            guard !products.isEmpty else {
                product = nil
                if !isPremium { state = .unavailable("価格を取得できません") }
                return
            }
            if !isPremium { state = .ready }
        } catch {
            products = []
            product = nil
            if !isPremium { state = .unavailable("価格を取得できません") }
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
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
                guard let self, self.productIDs.contains(transaction.productID) else { continue }
                await self.refreshEntitlement()
                self.state = self.isPremium ? .purchased : .ready
                await transaction.finish()
            }
        }
    }
}
