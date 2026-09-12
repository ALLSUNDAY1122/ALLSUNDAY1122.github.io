import SwiftUI
import LearningSprintCore

private struct KanriPurchaseStatusModifier: ViewModifier {
    let state: PurchaseController.PurchaseState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let status = statusMessage {
                HStack(spacing: 10) {
                    Image(systemName: status.icon)
                    Text(status.text).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(status.foreground)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                .padding(.top, 8)
                .accessibilityIdentifier("purchaseStatusBanner")
                .accessibilityLabel(status.text)
            }
        }
    }

    private var statusMessage: (text: String, icon: String, foreground: Color)? {
        switch state {
        case .purchasing:
            return ("購入処理中です", "hourglass", LearningSprintTheme.indigo)
        case .pending:
            return ("購入は承認待ちです。承認後に自動で反映します", "clock", LearningSprintTheme.indigo)
        case .cancelled:
            return ("購入をキャンセルしました。無料60問のまま利用できます", "xmark.circle", LearningSprintTheme.ink2)
        case .unavailable(let message):
            return (message, "wifi.exclamationmark", LearningSprintTheme.vermilion)
        case .failed(let message):
            return ("購入を完了できませんでした：\(message)", "exclamationmark.triangle", LearningSprintTheme.vermilion)
        case .loading, .ready, .purchased:
            return nil
        }
    }
}

extension View {
    func kanriPurchaseStatus(_ state: PurchaseController.PurchaseState) -> some View {
        modifier(KanriPurchaseStatusModifier(state: state))
    }
}
