import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREMIUM")
                            .font(.caption.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(SprintTheme.accent)
                        Text("すべてのテーマを解放")
                            .font(.largeTitle.weight(.bold))
                        Text("テーマ01〜06は無料。テーマ07以降はプレミアムで利用できます。")
                            .foregroundStyle(SprintTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("月額プレミアム").font(.headline)
                        Text(store.hasOneWeekFreeTrial ? "初回1週間無料トライアル" : "月額プラン")
                        Text(store.monthlyProduct?.displayPrice ?? "200円")
                            .font(.subheadline)
                            .foregroundStyle(SprintTheme.muted)
                        Button {
                            Task { await store.purchase(store.monthlyProduct) }
                        } label: {
                            HStack {
                                Spacer()
                                Text(store.monthlyProduct == nil ? "商品情報を読み込み中…" : "1週間無料で始める")
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SprintTheme.accent)
                        .foregroundStyle(SprintTheme.background)
                        .disabled(store.monthlyProduct == nil || store.isPurchasing)
                    }
                    .padding(16)
                    .background(SprintTheme.panel, in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("買い切りプレミアム").font(.headline)
                        Text("一度の購入で継続して利用できます。")
                            .font(.subheadline)
                            .foregroundStyle(SprintTheme.muted)
                        Button {
                            Task { await store.purchase(store.lifetimeProduct) }
                        } label: {
                            HStack {
                                Spacer()
                                Text("買い切りで解放（\(store.lifetimeProduct?.displayPrice ?? "980円")）")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(SprintTheme.accent)
                        .disabled(store.lifetimeProduct == nil || store.isPurchasing)
                    }
                    .padding(16)
                    .background(SprintTheme.panel, in: RoundedRectangle(cornerRadius: 18))

                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        HStack {
                            Spacer()
                            if store.isPurchasing { ProgressView().tint(.white) }
                            Text("購入を復元")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isPurchasing)

                    if let message = store.purchaseMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(SprintTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/english-listening-sprint/privacy.html")!)
                        Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.footnote)
                    .tint(SprintTheme.accent)
                }
                .padding(20)
            }
            .background(SprintTheme.background)
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            await store.loadProducts()
            await store.refreshEntitlements(retries: 3)
        }
    }
}
