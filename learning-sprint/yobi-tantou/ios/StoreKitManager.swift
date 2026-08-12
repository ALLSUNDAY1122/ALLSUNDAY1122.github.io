import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var statusMessage: String?

    var configuredProductID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PremiumProductID") as? String,
              !value.isEmpty,
              !value.contains("$(") else { return nil }
        return value
    }

    var isConfigured: Bool { configuredProductID != nil }

    func refresh() async {
        await refreshEntitlements()
        guard let id = configuredProductID else {
            product = nil
            statusMessage = "IAP Product ID は要確認です。"
            return
        }
        do {
            product = try await Product.products(for: [id]).first
            if product == nil { statusMessage = "StoreKit商品を取得できませんでした。" }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else {
            statusMessage = "課金設定が未確定です。"
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                statusMessage = "購入は保留中です。"
            case .userCancelled:
                break
            @unknown default:
                statusMessage = "購入状態を確認できませんでした。"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        guard let id = configuredProductID else {
            isPremium = false
            return
        }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? verified(result), transaction.productID == id, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "StoreKitトランザクションを検証できませんでした。" }
}
