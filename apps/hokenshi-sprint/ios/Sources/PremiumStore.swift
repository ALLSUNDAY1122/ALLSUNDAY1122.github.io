import Foundation
import StoreKit

/// 買い切り（全問解放）専用の StoreKit 2 ストア。
/// 商品は1件のみ: jp.allsunday1122.hokenshisprint.premium.lifetime（非消耗型、¥800）。
@MainActor
final class PremiumStore: ObservableObject {
    static let lifetimeID = "jp.allsunday1122.hokenshisprint.premium.lifetime"

    @Published private(set) var isPremium = false
    @Published private(set) var product: Product?
    @Published private(set) var busy = false
    @Published private(set) var checked = false
    @Published private(set) var message = ""

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.lifetimeID else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if transaction.productID == Self.lifetimeID, transaction.productType == .nonConsumable {
                owned = true
            }
        }
        isPremium = owned
        checked = true
    }

    func refresh() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.lifetimeID])
            product = fetched.first { $0.id == Self.lifetimeID && $0.type == .nonConsumable }
        } catch {
            product = nil
        }
    }

    func purchase() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        await refreshEntitlements()
        guard !isPremium else {
            message = "すでに購入済みです。全問をご利用いただけます。"
            return
        }
        if product == nil { await loadProducts() }
        guard let product else {
            message = "商品情報を取得できません。時間をおいて再試行してください。"
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result, transaction.productID == Self.lifetimeID else {
                    message = "購入を確認できませんでした。"
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                message = isPremium ? "購入が確認されました。全546問が解放されました。" : "購入状態を確認できません。復元をお試しください。"
            case .pending:
                message = "購入の承認待ちです。"
            case .userCancelled:
                message = "購入をキャンセルしました。"
            @unknown default:
                message = "購入状態を確認できません。"
            }
        } catch {
            message = "購入に失敗しました。再試行してください。"
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPremium ? "購入を復元しました。" : "有効な購入は見つかりませんでした。"
        } catch {
            message = "復元できませんでした。再試行してください。"
        }
    }
}
