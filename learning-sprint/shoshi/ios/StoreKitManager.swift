import Foundation
import StoreKit
import SwiftUI

@MainActor
final class StoreKitManager: ObservableObject {
    static let productID = "jp.allsunday1122.shoshi.premium"

    @Published private(set) var isPremium = false
    @Published private(set) var displayPrice = ""
    @Published private(set) var status = "loading"

    private var product: Product?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                if transaction.revocationDate == nil { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    var canPurchase: Bool { product != nil && !isPremium && status != "pending" }

    func refresh() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            displayPrice = product?.displayPrice ?? ""
        } catch {
            product = nil
            displayPrice = ""
            status = "error"
        }

        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
        if status != "error" { status = product == nil ? "product_unavailable" : "known" }
    }

    func purchase() async {
        if product == nil { await refresh() }
        guard let product else { status = "product_unavailable"; return }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { status = "unverified"; return }
                await transaction.finish()
                await refresh()
            case .pending: status = "pending"
            case .userCancelled: status = "cancelled"
            @unknown default: status = "unknown"
            }
        } catch { status = "error" }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch { status = "error" }
    }
}
