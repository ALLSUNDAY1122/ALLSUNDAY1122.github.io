import Foundation
import SwiftUI
import StoreKit

@MainActor
final class PremiumStore: ObservableObject {
    static let lifetimeID = "jp.allsunday1122.itpassportstudy.premium.lifetime"
    static let monthlyID = "jp.allsunday1122.itpassportstudy.premium.monthly"
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
                await refreshEntitlements()
                await transaction.finish()
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
            await refreshEntitlements()
            message = isPremium ? "購入を復元しました。" : "有効な購入は見つかりませんでした。"
        } catch { message = "復元できませんでした。再試行してください。" }
    }
}

struct PremiumSettingsView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Premium状態") {
                    Text(!premium.checked ? "購入状態を確認中" :
                        premium.lifetime ? "Premium・買い切り利用中" :
                        premium.isPremium ? "Premium・月額利用中" : "無料プラン")
                    Text(premium.isPremium ? "全500問を利用できます。" : "2026年度100問を無料で利用できます。")
                    if let expiry = premium.monthlyExpiry {
                        Text("月額の現在の有効期限：\(expiry.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                Section("全500問を解放") {
                    purchaseButton("買い切り", id: PremiumStore.lifetimeID, disabled: premium.lifetime)
                    purchaseButton("月額（1か月）", id: PremiumStore.monthlyID, disabled: premium.isPremium)
                    Text("月額は自動更新されます。更新・解約はAppleのサブスクリプション管理から行えます。買い切り購入で既存の月額契約が自動解約されることはありません。")
                        .font(.footnote)
                    Link("サブスクリプション管理", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Link("利用規約（Apple標準EULA）", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                Section {
                    Button("購入を復元") { Task { await premium.restore() } }.disabled(premium.busy)
                    Button("商品情報を再取得") { Task { await premium.refresh() } }.disabled(premium.busy)
                    if premium.busy { ProgressView() }
                    if !premium.message.isEmpty { Text(premium.message).font(.footnote) }
                }
            }
            .navigationTitle("設定")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .task { await premium.refresh() }
        }
    }

    private func purchaseButton(_ title: String, id: String, disabled: Bool) -> some View {
        Button {
            Task { await premium.purchase(id) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(premium.products[id]?.displayPrice ?? "取得できません")
            }
        }
        .disabled(disabled || premium.busy || !premium.checked || premium.products[id] == nil)
    }
}
