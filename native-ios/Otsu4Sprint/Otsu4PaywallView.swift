import SwiftUI

struct Otsu4PaywallView: View {
    @ObservedObject var purchaseStore: Otsu4PurchaseStore
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("乙4 プレミアム")
                        .font(.title2.bold())

                    Text("無料版で学習感を確認したあと、必要なときだけ全問題と本番演習を解放できます。")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        benefit("独自問題360問をすべて利用")
                        benefit("苦手・未出題を全範囲から自動復習")
                        benefit("本番35問・120分モード")
                        benefit("数字・指定数量の集中演習")
                        benefit("科目別の詳細な学習記録")
                    }
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button {
                        Task { await purchaseStore.purchasePremium() }
                    } label: {
                        HStack {
                            Text(purchaseButtonTitle)
                            Spacer()
                            if case .purchasing = purchaseStore.state {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || purchaseStore.premiumProduct == nil)

                    Button("購入を復元") {
                        Task { await purchaseStore.restorePurchases() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isBusy)

                    stateMessage

                    Text("買い切り型です。購入状態はApp Storeの取引情報から判定し、端末内キャッシュだけでは解放しません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: dismiss)
                }
            }
        }
        .onChange(of: purchaseStore.isPremium) { _, purchased in
            if purchased { dismiss() }
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
        }
    }

    private var purchaseButtonTitle: String {
        let price = purchaseStore.displayPrice
        return price == "—" ? "商品情報を確認中" : "買い切りで解放  \(price)"
    }

    private var isBusy: Bool {
        switch purchaseStore.state {
        case .loading, .purchasing:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private var stateMessage: some View {
        switch purchaseStore.state {
        case .pending:
            Text("購入は保留中です。承認後にApp Storeの取引情報へ反映されると自動で解放します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        case .premium:
            Text("購入済みです。")
                .font(.footnote)
                .foregroundStyle(.green)
        default:
            EmptyView()
        }
    }
}
