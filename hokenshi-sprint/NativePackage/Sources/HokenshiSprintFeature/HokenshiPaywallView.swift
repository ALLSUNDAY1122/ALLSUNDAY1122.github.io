#if canImport(SwiftUI)
import SwiftUI
import LearningSprintCore

public struct HokenshiPaywallView: View {
    @ObservedObject private var purchase: PurchaseController
    private let onClose: () -> Void

    public init(purchase: PurchaseController, onClose: @escaping () -> Void) {
        self.purchase = purchase
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("プレミアム")
                                .font(LearningSprintTheme.sans(12, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.vermilion)
                            Text("330問をすべて解放")
                                .font(LearningSprintTheme.serif(28, weight: .bold))
                        }
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.bold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("閉じる")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        premiumRow("全10分野・監査済み330問")
                        premiumRow("独自模試3回分・午前55／午後55／通し110")
                        premiumRow("苦手復習・履歴・途中再開・JSONバックアップ")
                        premiumRow("買い切り。定期購読ではありません")
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("無料版では第1回の各10分野から3問ずつ、合計30問を利用できます。")
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(LearningSprintTheme.ink2)
                        .lineSpacing(4)

                    if purchase.isPremium {
                        Label("プレミアム解放済み", systemImage: "checkmark.seal.fill")
                            .font(LearningSprintTheme.sans(16, weight: .bold))
                            .foregroundStyle(LearningSprintTheme.green)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(LearningSprintTheme.greenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Button {
                            Task { await purchase.purchase() }
                        } label: {
                            VStack(spacing: 3) {
                                Text("プレミアムを解放")
                                    .font(LearningSprintTheme.sans(16, weight: .bold))
                                Text(purchase.displayPrice ?? "価格を取得中")
                                    .font(LearningSprintTheme.sans(12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(LearningSprintTheme.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy || purchase.product == nil)
                        .opacity(purchase.product == nil ? 0.55 : 1)
                        .accessibilityIdentifier("hokenshi.paywall.purchase")

                        if purchase.product == nil && !isBusy {
                            Button {
                                Task { await purchase.refresh() }
                            } label: {
                                Text("製品情報を再読み込み")
                                    .font(LearningSprintTheme.sans(13, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("hokenshi.paywall.retry")
                        }
                    }

                    Button {
                        Task { await purchase.restore() }
                    } label: {
                        Text("購入を復元")
                            .font(LearningSprintTheme.sans(14, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                    .accessibilityIdentifier("hokenshi.paywall.restore")

                    if let message = statusMessage {
                        Text(message)
                            .font(LearningSprintTheme.sans(12, weight: .semibold))
                            .foregroundStyle(statusIsError ? LearningSprintTheme.vermilion : LearningSprintTheme.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("購入処理と復元はAppleのStoreKitを使用します。表示価格はApp Storeから取得した価格だけを表示します。")
                        .font(LearningSprintTheme.sans(11))
                        .foregroundStyle(LearningSprintTheme.ink3)
                        .lineSpacing(3)
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(18)
                .padding(.bottom, 30)
            }
        }
        .task { await purchase.refresh() }
        .accessibilityIdentifier("hokenshi.paywall")
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
        case .purchased: return "購入済みです。全問題を利用できます。"
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

    private func premiumRow(_ text: String) -> some View {
        Label {
            Text(text)
                .font(LearningSprintTheme.sans(13, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.ink)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LearningSprintTheme.green)
        }
    }
}
#endif
