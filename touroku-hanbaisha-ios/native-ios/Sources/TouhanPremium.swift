import SwiftUI
import StoreKit

@MainActor
final class TouhanPremium: ObservableObject {
    static let monthly = "com.allsunday1122.tourokuhanbaisha.premium.monthly"
    static let lifetime = "com.allsunday1122.tourokuhanbaisha.premium.lifetime"
    @Published private(set) var unlocked = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var trialEligible = false
    @Published var message = ""
    @Published var busy = false
    private var updates: Task<Void, Never>?
    private var expiry: Task<Void, Never>?
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let t) = result, [Self.monthly, Self.lifetime].contains(t.productID) {
                        await self.refresh()
                        await t.finish()
                    }
                }
            }
        }
        await refresh()
        await load()
    }
    func load() async {
        do {
            products = try await Product.products(for: [Self.monthly, Self.lifetime])
            trialEligible = false
            if let p = products.first(where: {$0.id == Self.monthly}), let s = p.subscription,
               let offer = s.introductoryOffer, offer.paymentMode == .freeTrial,
               offer.period.unit == .week, offer.period.value == 1, offer.periodCount == 1 {
                trialEligible = await s.isEligibleForIntroOffer
            }
            if products.count != 2 { message = "一部の商品を取得できません。通信環境を確認してください。" }
        } catch { message = "商品を取得できません。通信環境を確認してください。" }
    }
    func refresh() async {
        var entitled = false
        var nearest: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil, !t.isUpgraded else { continue }
            if t.productID == Self.lifetime && t.productType == .nonConsumable { entitled = true }
            if t.productID == Self.monthly && t.productType == .autoRenewable,
               let end = t.expirationDate, end > Date() {
                entitled = true
                if nearest == nil || end < nearest! { nearest = end }
            }
        }
        unlocked = entitled
        expiry?.cancel()
        if let end = nearest {
            expiry = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(1, end.timeIntervalSinceNow))) } catch { return }
                await self?.refresh()
            }
        }
    }
    func purchase(_ product: Product) async {
        guard !busy, !unlocked, [Self.monthly, Self.lifetime].contains(product.id) else { return }
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result, t.productID == product.id else {
                    message = "購入を確認できませんでした。"; return
                }
                await refresh(); await t.finish()
                message = unlocked ? "全599問を利用できます。" : "購入状態を確認してください。"
            case .pending: message = "購入承認を待っています。"
            case .userCancelled: message = "購入をキャンセルしました。"
            @unknown default: message = "購入状態を確認してください。"
            }
        } catch { message = "購入に失敗しました。再度お試しください。" }
    }
    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = unlocked ? "購入を復元しました。" : "有効な購入はありません。" }
        catch { message = "購入を復元できませんでした。" }
    }
}
struct TouhanPaywall: View {
    @ObservedObject var premium: TouhanPremium
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("全599問で学習").font(.title.bold())
                    Text("各章10問、合計50問は無料。追加549問を解放します。学習記録は購入しなくても利用できます。")
                    if premium.unlocked { Text("全問利用中").font(.headline) }
                    ForEach(premium.products.sorted { $0.id < $1.id }, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.id == TouhanPremium.monthly ? "月額プラン" : "買い切りプラン").font(.headline)
                            Text(p.displayPrice + (p.id == TouhanPremium.monthly ? " / 月" : "（一度のみ）"))
                            if p.id == TouhanPremium.monthly {
                                if premium.trialEligible { Text("対象者は初回1週間無料。その後は月額料金で自動更新。") }
                                Text("自動更新。解約はAppleアカウントのサブスクリプション設定から。")
                            }
                            Button("購入する") { Task { await premium.purchase(p) } }.buttonStyle(.borderedProminent).disabled(premium.busy || premium.unlocked)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    if premium.products.isEmpty { Button("商品を再取得") { Task { await premium.load() } } }
                    Button("購入を復元") { Task { await premium.restore() } }.disabled(premium.busy)
                    Link("サブスクリプション管理", destination: URL(string:"https://apps.apple.com/account/subscriptions")!)
                    Link("プライバシーポリシー", destination: URL(string:"https://allsunday1122.github.io/touroku-hanbaisha-sprint/privacy.html")!)
                    Link("利用規約（Apple標準EULA）", destination: URL(string:"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text(premium.message).accessibilityIdentifier("purchaseStatus")
                }.padding()
            }.navigationTitle("プレミアム").toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
