import SwiftUI

struct RigakuPurchaseSettingsSection: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    var body: some View {
        if appModel.purchaseConfigured {
            Section("App内課金") {
                if appModel.premiumAccess {
                    Label("プレミアム利用可能", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(LearningSprintTheme.green)
                } else if let price = appModel.purchaseDisplayPrice {
                    Button("プレミアムを購入（\(price)）") {
                        Task { await appModel.purchasePremium() }
                    }
                } else {
                    Text("価格を確認しています。")
                        .font(.caption)
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Button("購入を復元") {
                    Task { await appModel.restorePurchases() }
                }

                if let state = appModel.purchaseStateLabel {
                    Text(state)
                        .font(.caption)
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Text("価格はApp Storeから取得した表示価格のみを使用します。")
                    .font(.caption)
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
        }
    }
}

struct RigakuLegalSettingsSection: View {
    var body: some View {
        Section("サポート・プライバシー") {
            Link("サポート", destination: RigakuAppConfiguration.supportURL)
            Link("プライバシーポリシー", destination: RigakuAppConfiguration.privacyURL)
            Link("利用条件", destination: RigakuAppConfiguration.termsURL)
            Text("本アプリは国家試験の学習補助用であり、診断・治療・リハビリテーション実施の判断には使用できません。")
                .font(.caption)
                .foregroundStyle(LearningSprintTheme.ink2)
        }
    }
}
