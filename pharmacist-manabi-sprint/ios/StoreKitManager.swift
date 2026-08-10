import Foundation
import StoreKit
import SwiftUI

@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyID = "jp.allsunday1122.yakuzaishi.monthly"
    static let lifetimeID = "jp.allsunday1122.yakuzaishi.lifetime"
    static let productIDs: Set<String> = [monthlyID, lifetimeID]

    @Published private(set) var isPremium = false
    @Published private(set) var monthlyPrice = ""
    @Published private(set) var lifetimePrice = ""
    @Published private(set) var monthlyAvailable = false
    @Published private(set) var lifetimeAvailable = false
    @Published private(set) var introEligible = false
    @Published private(set) var introConfigured = false
    @Published private(set) var hasMonthlyEntitlement = false
    @Published private(set) var hasLifetimeEntitlement = false
    @Published private(set) var status = "loading"

    private var products: [String: Product] = [:]
    private var transactionTask: Task<Void, Never>?

    init() {
        transactionTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit { transactionTask?.cancel() }

    func refresh() async {
        do {
            let loaded = try await Product.products(for: Array(Self.productIDs))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            monthlyPrice = products[Self.monthlyID]?.displayPrice ?? ""
            lifetimePrice = products[Self.lifetimeID]?.displayPrice ?? ""
            monthlyAvailable = products[Self.monthlyID] != nil
            lifetimeAvailable = products[Self.lifetimeID] != nil
            if let subscription = products[Self.monthlyID]?.subscription {
                introConfigured = subscription.introductoryOffer != nil
                introEligible = await subscription.isEligibleForIntroOffer
            } else {
                introConfigured = false
                introEligible = false
            }
            status = (monthlyAvailable || lifetimeAvailable) ? "ready" : "product_unavailable"
        } catch {
            status = "product_error"
        }

        var monthly = false
        var lifetime = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            if transaction.productID == Self.monthlyID { monthly = true }
            if transaction.productID == Self.lifetimeID { lifetime = true }
        }
        hasMonthlyEntitlement = monthly
        hasLifetimeEntitlement = lifetime
        isPremium = monthly || lifetime
    }

    func purchaseMonthly() async { await purchase(id: Self.monthlyID) }
    func purchaseLifetime() async { await purchase(id: Self.lifetimeID) }

    private func purchase(id: String) async {
        if products.isEmpty { await refresh() }
        guard AppStore.canMakePayments else { status = "payments_disabled"; return }
        guard let product = products[id] else { status = "product_unavailable"; return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { status = "unverified"; return }
                await transaction.finish()
                await refresh()
                status = "purchased"
            case .pending: status = "pending"
            case .userCancelled: status = "cancelled"
            @unknown default: status = "unknown"
            }
        } catch {
            status = "purchase_error"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
            status = isPremium ? "restored" : "no_entitlement"
        } catch {
            status = "restore_error"
        }
    }

    func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            status = "manage_unavailable"
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await refresh()
        } catch {
            status = "manage_error"
        }
    }

    var statusMessage: String? {
        switch status {
        case "purchased": return "購入が完了しました。"
        case "restored": return "購入情報を復元しました。"
        case "pending": return "購入は承認待ちです。"
        case "cancelled": return nil
        case "no_entitlement": return "復元できる購入は見つかりませんでした。"
        case "product_unavailable": return "App Storeから商品情報を取得できません。"
        case "payments_disabled": return "この端末では購入が制限されています。"
        case "purchase_error", "product_error", "restore_error": return "App Storeとの通信に失敗しました。時間をおいて再度お試しください。"
        default: return nil
        }
    }
}
