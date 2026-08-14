import SwiftUI
import LearningSprintCore

@MainActor
public struct JosanshiPremiumPaywallView: View {
    @ObservedObject private var model: JosanshiDashboardModel

    public init(model: JosanshiDashboardModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Premium")
                            .font(LearningSprintTheme.sans(12, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                        Text("助産師国家試験を、最後まで。")
                            .font(LearningSprintTheme.serif(27, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.ink)
                        Text("サブスクではなく、一度の購入でこのアプリのPremium機能を利用できます。")
                            .font(LearningSprintTheme.sans(14))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("無料で使えること", systemImage: "checkmark.circle")
                            .font(LearningSprintTheme.serif(18, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.indigo)
                        ForEach(JosanshiMonetizationConfiguration.freeFeatures, id: \.self) { feature in
                            featureRow(feature, locked: false)
                        }
                        Text("無料問題は4分野×15問＝\(JosanshiMonetizationConfiguration.freeQuestionTarget)問。今日のスプリントで繰り返せます。")
                            .font(LearningSprintTheme.sans(12))
                            .foregroundStyle(LearningSprintTheme.ink3)
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Premiumで開放", systemImage: "lock.open.fill")
                            .font(LearningSprintTheme.serif(18, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.vermilion)
                        ForEach(JosanshiMonetizationConfiguration.premiumFeatures, id: \.self) { feature in
                            featureRow(feature, locked: true)
                        }
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    purchaseStatus

                    Button {
                        Task { await model.purchasePremium() }
                    } label: {
                        HStack {
                            Spacer()
                            Text(purchaseButtonTitle)
                                .font(LearningSprintTheme.sans(16, weight: .bold))
                            Spacer()
                        }
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                    .disabled(isPurchaseBusy || model.purchaseController == nil)
                    .accessibilityIdentifier("purchase-premium")

                    Button {
                        Task { await model.restorePremium() }
                    } label: {
                        Text("購入を復元")
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(LearningSprintTheme.indigo)
                    .disabled(isPurchaseBusy || model.purchaseController == nil)
                    .accessibilityIdentifier("restore-premium")

                    Text("購入はApple IDに紐づきます。同じApple IDでは「購入を復元」から権利を確認できます。価格はApp Storeから取得した表示を優先します。")
                        .font(LearningSprintTheme.sans(11))
                        .foregroundStyle(LearningSprintTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(LearningSprintPaperBackground())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { model.dismissPaywall() }
                }
            }
        }
        .interactiveDismissDisabled(isPurchaseBusy)
        .onChange(of: model.isPremium) { _, entitled in
            if entitled { model.dismissPaywall() }
        }
    }

    private func featureRow(_ text: String, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: locked ? "checkmark.circle.fill" : "checkmark")
                .foregroundStyle(locked ? LearningSprintTheme.vermilion : LearningSprintTheme.green)
                .frame(width: 18)
            Text(text)
                .font(LearningSprintTheme.sans(14))
                .foregroundStyle(LearningSprintTheme.ink)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var purchaseStatus: some View {
        switch model.purchaseState {
        case .loading:
            Label("App Storeから商品情報を確認しています", systemImage: "arrow.triangle.2.circlepath")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink2)
        case .pending:
            Label("購入は承認待ちです。承認後に自動反映されます。", systemImage: "clock")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink2)
        case .purchased:
            Label("Premium購入済み", systemImage: "checkmark.seal.fill")
                .font(LearningSprintTheme.sans(13, weight: .bold))
                .foregroundStyle(LearningSprintTheme.green)
        case .cancelled:
            Text("購入はキャンセルされました。料金は発生しません。")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink2)
        case .unavailable(let message), .failed(let message):
            Text(message)
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.vermilion)
        case .ready, .purchasing:
            EmptyView()
        case .none:
            Text("App Store商品は実機・Sandbox/TestFlightで確認します。")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink3)
        }
    }

    private var isPurchaseBusy: Bool {
        switch model.purchaseState {
        case .loading, .purchasing, .pending:
            return true
        default:
            return false
        }
    }

    private var purchaseButtonTitle: String {
        if model.isPremium { return "購入済み" }
        if case .purchasing = model.purchaseState { return "購入処理中…" }
        if let price = model.purchasePriceText { return "Premiumを購入 ・ \(price)" }
        return "Premiumを購入"
    }
}
