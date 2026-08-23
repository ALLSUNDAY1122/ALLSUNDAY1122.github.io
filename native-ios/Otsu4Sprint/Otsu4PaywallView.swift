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
                        .foregroundStyle(Otsu4Theme.ink)

                    Text("無料版で学習感を確認したあと、必要なときだけ全720問と本番演習を解放できます。")
                        .foregroundStyle(Otsu4Theme.ink2)

                    VStack(alignment: .leading, spacing: 12) {
                        benefit("独自問題720問をすべて利用")
                        benefit("分野別で全問題を通して学習")
                        benefit("苦手・未出題を全範囲から自動復習")
                        benefit("本番35問・120分モードを6回分")
                        benefit("科目別・問題別の学習記録")
                    }
                    .padding(16)
                    .background(Otsu4Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Otsu4Theme.line, lineWidth: 1)
                    )

                    Button {
                        Task { await purchaseStore.purchasePremium() }
                    } label: {
                        HStack {
                            Text(purchaseButtonTitle)
                                .fontWeight(.bold)
                            Spacer()
                            if purchaseStore.isBusy {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Otsu4Theme.shu)
                    .disabled(purchaseStore.isBusy)

                    if purchaseStore.premiumProduct == nil && !purchaseStore.isBusy {
                        Button {
                            Task { await purchaseStore.retryProductLoad() }
                        } label: {
                            Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Otsu4Theme.ai)
                    }

                    Button("購入を復元") {
                        Task { await purchaseStore.restorePurchases() }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Otsu4Theme.ai)
                    .disabled(purchaseStore.isBusy)

                    stateMessage

                    Text("買い切り型です。購入状態はApp Storeの取引情報から判定し、端末内キャッシュだけでは解放しません。")
                        .font(.footnote)
                        .foregroundStyle(Otsu4Theme.ink2)
                }
                .padding(20)
            }
            .background(Otsu4Theme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: dismiss)
                }
            }
        }
        .task {
            if purchaseStore.premiumProduct == nil && !purchaseStore.isPremium {
                await purchaseStore.loadProduct()
            }
        }
        .onChange(of: purchaseStore.isPremium) { _, purchased in
            if purchased { dismiss() }
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Otsu4Theme.midori)
            Text(text)
                .foregroundStyle(Otsu4Theme.ink)
        }
    }

    private var purchaseButtonTitle: String {
        if let product = purchaseStore.premiumProduct {
            return "買い切りで解放  \(product.displayPrice)"
        }
        if case .failed = purchaseStore.state {
            return "商品情報を再取得して購入"
        }
        return "商品情報を確認中"
    }

    @ViewBuilder
    private var stateMessage: some View {
        switch purchaseStore.state {
        case .pending:
            Text("購入は保留中です。承認後にApp Storeの取引情報へ反映されると自動で解放します。")
                .font(.footnote)
                .foregroundStyle(Otsu4Theme.ink2)
        case .failed(let message):
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Otsu4Theme.shu)
        case .premium:
            Text("購入済みです。")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Otsu4Theme.midori)
        default:
            EmptyView()
        }
    }
}
