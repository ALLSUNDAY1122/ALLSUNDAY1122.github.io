import Foundation
import SwiftUI
import StoreKit

@MainActor
final class PremiumStore: ObservableObject {
    static let lifetimeID = "jp.allsunday1122.electrician2sprint.premium.lifetime"
    static let monthlyID = "jp.allsunday1122.electrician2sprint.premium.monthly"
    static let ids = [lifetimeID, monthlyID]

    @Published private(set) var lifetime = false
    @Published private(set) var monthlyExpiry: Date?
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var busy = false
    @Published private(set) var checked = false
    @Published private(set) var message = ""
    var isPremium: Bool { lifetime || (monthlyExpiry.map { $0 > Date() } ?? false) }

    private var updates: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var generation = 0

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Self.ids.contains(transaction.productID) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    deinit {
        updates?.cancel()
        expiryTask?.cancel()
    }

    func refreshEntitlements() async {
        generation += 1
        let token = generation
        var owned = false
        var expiry: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if transaction.productID == Self.lifetimeID, transaction.productType == .nonConsumable {
                owned = true
            } else if transaction.productID == Self.monthlyID,
                      transaction.productType == .autoRenewable,
                      let end = transaction.expirationDate, end > Date(),
                      expiry == nil || end > expiry! {
                expiry = end
            }
        }
        guard token == generation else { return }
        lifetime = owned
        monthlyExpiry = expiry
        checked = true
        expiryTask?.cancel()
        if let expiry, !owned {
            expiryTask = Task { [weak self] in
                let seconds = max(0, expiry.timeIntervalSinceNow)
                do { try await Task.sleep(nanoseconds: UInt64(min(seconds + 0.1, 86400) * 1_000_000_000)) }
                catch { return }
                await self?.refreshEntitlements()
            }
        }
    }

    func refresh() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.ids)
            products = Dictionary(uniqueKeysWithValues: fetched.filter {
                ($0.id == Self.lifetimeID && $0.type == .nonConsumable) ||
                ($0.id == Self.monthlyID && $0.type == .autoRenewable &&
                 $0.subscription?.subscriptionPeriod.unit == .month &&
                 $0.subscription?.subscriptionPeriod.value == 1)
            }.map { ($0.id, $0) })
        } catch {
            products = [:]
        }
    }

    private func refreshUntilPremium(maxAttempts: Int = 6) async {
        for _ in 0..<maxAttempts {
            await refreshEntitlements()
            if isPremium { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
    }

    func purchase(_ id: String) async {
        guard !busy, Self.ids.contains(id) else { return }
        busy = true
        defer { busy = false }
        await refreshEntitlements()
        guard !lifetime, !(id == Self.monthlyID && isPremium) else {
            message = "すでに利用中です。"; return
        }
        if products[id] == nil { await loadProducts() }
        guard let product = products[id] else {
            message = "商品情報を取得できません。時間をおいて再試行してください。"; return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result, transaction.productID == id else {
                    message = "購入を確認できませんでした。"; return
                }
                await transaction.finish()
                await refreshUntilPremium()
                message = isPremium ? "購入が確認されました。" : "購入状態を確認できません。復元をお試しください。"
            case .pending: message = "購入の承認待ちです。"
            case .userCancelled: message = "購入をキャンセルしました。"
            @unknown default: message = "購入状態を確認できません。"
            }
        } catch { message = "購入に失敗しました。再試行してください。" }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshUntilPremium(maxAttempts: 4)
            message = isPremium ? "購入を復元しました。" : "有効な購入は見つかりませんでした。"
        } catch { message = "復元できませんでした。再試行してください。" }
    }
}
