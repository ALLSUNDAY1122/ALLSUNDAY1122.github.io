import LearningSprintCore
import SwiftUI

struct RigakuPurchaseSettingsSection: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    var body: some View {
        if appModel.purchaseConfigured {
            Section("月額プラン") {
                if appModel.premiumAccess {
                    Label("全600問・ベース模試・全苦手復習を利用可能", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(LearningSprintTheme.green)
                } else if let price = appModel.purchaseDisplayPrice {
                    Button("月額プランを開始（\(price)）") {
                        Task { await appModel.purchasePremium() }
                    }
                } else {
                    Text("App Storeから価格を確認しています。")
                        .font(.caption)
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Text("無料版は8分野から選んだ60問を利用できます。月額プランでは全600問、第58〜60回ベース模試、全苦手復習を解放します。")
                    .font(.caption)
                    .foregroundStyle(LearningSprintTheme.ink2)

                Button("購入を復元") {
                    Task { await appModel.restorePurchases() }
                }

                if let state = appModel.purchaseStateLabel {
                    Text(state)
                        .font(.caption)
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Text("価格はApp Storeの表示価格のみを使用します。購読の管理・解約はApple Accountのサブスクリプション設定から行えます。")
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
