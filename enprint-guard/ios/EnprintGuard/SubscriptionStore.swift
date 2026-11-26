import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionStore: ObservableObject {
    static let monthlyID = "jp.allsunday1122.enprintguard.premium.monthly"
    static let annualID = "jp.allsunday1122.enprintguard.premium.annual"
    static let productIDs = [monthlyID, annualID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published var message: String?

    func load() async {
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.id < $1.id }
            await refreshEntitlements()
        } catch {
            message = "購入情報を取得できませんでした。時間をおいて再試行してください。"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                message = "購入は承認待ちです。"
            case .userCancelled:
                break
            @unknown default:
                message = "購入状態を確認できませんでした。"
            }
        } catch {
            message = "購入を完了できませんでした。"
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
            message = isPremium ? "購入を復元しました。" : "復元できる購入が見つかりませんでした。"
        } catch {
            message = "購入を復元できませんでした。"
        }
    }

    private func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                active = true
            }
        }
        isPremium = active
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}
