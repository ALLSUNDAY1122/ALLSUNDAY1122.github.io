import Foundation
import StoreKit

enum StoreProductIDPolicy {
    static func normalized(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("$("),
              !trimmed.uppercased().contains("UNSET") else { return nil }
        return trimmed
    }
}

enum StoreProductTypePolicy {
    static let requiredType: Product.ProductType = .autoRenewable

    static func accepts(_ type: Product.ProductType) -> Bool {
        type == requiredType
    }
}

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var statusMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var configuredProductID: String? {
        StoreProductIDPolicy.normalized(Bundle.main.object(forInfoDictionaryKey: "PremiumProductID"))
    }

    var isConfigured: Bool { configuredProductID != nil }

    func refresh() async {
        startObservingTransactionUpdates()
        statusMessage = nil
        await refreshEntitlements()
        guard let id = configuredProductID else {
            product = nil
            statusMessage = "IAP Product ID はApp Store Connect登録待ちです。"
            return
        }
        do {
            guard let candidate = try await Product.products(for: [id]).first else {
                product = nil
                statusMessage = "StoreKit商品を取得できませんでした。"
                return
            }
            guard StoreProductTypePolicy.accepts(candidate.type) else {
                product = nil
                statusMessage = "月額の自動更新サブスクリプション商品ではありません。"
                return
            }
            product = candidate
        } catch {
            product = nil
            statusMessage = error.localizedDescription
        }
    }

    func purchase() async {
        guard isConfigured, let product else {
            statusMessage = "課金設定が未確定です。"
            return
        }
        guard StoreProductTypePolicy.accepts(product.type) else {
            statusMessage = "月額の自動更新サブスクリプション商品ではありません。"
            return
        }
        statusMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                guard transaction.productID == configuredProductID else {
                    statusMessage = "購入商品の識別子が一致しません。"
                    await transaction.finish()
                    await refreshEntitlements()
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                statusMessage = "購入は保留中です。"
            case .userCancelled:
                statusMessage = nil
            @unknown default:
                statusMessage = "購入状態を確認できませんでした。"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard isConfigured else {
            statusMessage = "IAP Product ID が未設定のため復元できません。"
            return
        }
        statusMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func startObservingTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.statusMessage = StoreError.failedVerification.localizedDescription
                }
            }
        }
    }

    private func refreshEntitlements() async {
        guard let id = configuredProductID else {
            isPremium = false
            return
        }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? verified(result),
               transaction.productID == id,
               transaction.revocationDate == nil {
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
