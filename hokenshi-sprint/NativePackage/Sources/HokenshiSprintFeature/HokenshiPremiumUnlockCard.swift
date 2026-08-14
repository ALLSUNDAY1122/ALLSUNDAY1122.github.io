#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiPremiumUnlockCard: View {
    @ObservedObject private var purchase: PurchaseController

    public init(purchase: PurchaseController) {
        self.purchase = purchase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("プレミアム")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text(purchase.isPremium ? "330問すべて利用できます" : "残り300問＋模試3回を解放")
                        .font(LearningSprintTheme.serif(18, weight: .semibold))
                }
                Spacer()
                Image(systemName: purchase.isPremium ? "checkmark.seal.fill" : "lock.open.fill")
                    .foregroundStyle(purchase.isPremium ? LearningSprintTheme.green : LearningSprintTheme.gold)
            }

            Text("無料版は10分野×3問＝30問。プレミアムは買い切りで、定期購読ではありません。")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink2)
                .lineSpacing(3)

            if purchase.isPremium {
                Label("解放済み", systemImage: "checkmark.circle.fill")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.green)
            } else {
                Button {
                    Task { await purchase.purchase() }
                } label: {
                    VStack(spacing: 2) {
                        Text("プレミアムを解放")
                            .font(LearningSprintTheme.sans(14, weight: .bold))
                        Text(purchase.displayPrice ?? "App Storeで価格を確認")
                            .font(LearningSprintTheme.sans(11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(LearningSprintTheme.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityIdentifier("hokenshi.premium.purchase")
            }

            Button {
                Task { await purchase.restore() }
            } label: {
                Text("購入を復元")
                    .font(LearningSprintTheme.sans(12, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .accessibilityIdentifier("hokenshi.premium.restore")

            if let statusMessage {
                Text(statusMessage)
                    .font(LearningSprintTheme.sans(11, weight: .semibold))
                    .foregroundStyle(statusIsError ? LearningSprintTheme.vermilion : LearningSprintTheme.ink3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LearningSprintTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task { await purchase.refresh() }
        .accessibilityIdentifier("hokenshi.premium.card")
    }

    private var isBusy: Bool {
        switch purchase.state {
        case .loading, .purchasing: return true
        default: return false
        }
    }

    private var statusMessage: String? {
        switch purchase.state {
        case .loading: return "App Storeの製品情報を確認しています。"
        case .purchasing: return "購入を処理しています。"
        case .pending: return "購入は承認待ちです。"
        case .purchased: return "購入済みです。"
        case .cancelled: return "購入はキャンセルされました。"
        case .unavailable(let message), .failed(let message): return message
        case .ready: return nil
        }
    }

    private var statusIsError: Bool {
        switch purchase.state {
        case .unavailable, .failed: return true
        default: return false
        }
    }
}
#endif
