import Foundation
import SwiftUI
import LearningSprintCore

struct PaywallView: View {
    @EnvironmentObject var purchase: PurchaseController
    @Environment(\.dismiss) private var dismiss

    private let lifetimeID = "jp.allsunday1122.hokenshisprint.premium.lifetime"
    // Guideline 3.1.2: tappable Privacy Policy and Terms of Use (EULA) on the paywall.
    static let privacyPolicyURL = URL(string: "https://allsunday1122.github.io/hokenshi-sprint/privacy.html")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var stateMessage: String? {
        switch purchase.state {
        case .pending: return "購入承認を待っています。"
        case .cancelled: return "購入はキャンセルされました。"
        case .unavailable(let text): return text
        case .failed(let text): return text
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Image(systemName: "graduationcap.fill").font(.system(size: 42)).foregroundStyle(KSTheme.ai)
                            Text("学びスプリント プレミアム").font(.title2.bold()).foregroundStyle(KSTheme.ink)
                            Text("必要なところだけ、短く繰り返す。収録全問と本番形式を解放します。").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(KSTheme.secondary)
                        }.padding(.top, 20)
                        KSCard(content: VStack(alignment: .leading, spacing: 12) {
                            Label("全546問（第112〜108回）を解放", systemImage: "lock.open.fill")
                            Label("午前・午後の本番形式（模擬試験）", systemImage: "doc.text.fill")
                            Label("科目・分野から学習", systemImage: "square.grid.2x2.fill")
                            Label("苦手を3回連続正解まで自動追跡", systemImage: "repeat.circle.fill")
                            Label("詳細な学習記録", systemImage: "chart.bar.fill")
                        }.font(.subheadline).foregroundStyle(KSTheme.ink))

                        if purchase.isPremium {
                            Label("利用中です", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(KSTheme.green)
                        } else {
                            Button {
                                Task { await purchase.purchase(productID: lifetimeID) }
                            } label: {
                                VStack(spacing: 3) {
                                    Text(purchase.state == .purchasing ? "購入処理中…" : "買い切りプラン").font(.headline)
                                    Text(purchase.displayPrice(for: lifetimeID).map { "買い切り \($0)" } ?? "価格を取得中").font(.caption)
                                }.frame(maxWidth: .infinity).padding(.vertical, 13)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KSTheme.ai)
                            .disabled(purchase.product(for: lifetimeID) == nil || purchase.state == .purchasing)
                        }

                        Button("購入を復元") { Task { await purchase.restore() } }
                            .font(.subheadline.bold()).foregroundStyle(KSTheme.ai)
                            .accessibilityIdentifier("restore-purchases")
                        if let stateMessage { Text(stateMessage).font(.caption).foregroundStyle(KSTheme.shu).multilineTextAlignment(.center) }
                    }.padding(18)
                }
                legalFooter
            }
            .background(KSTheme.paper.ignoresSafeArea())
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("買い切りプランは1回のみの購入で、自動更新はありません。価格はApp Storeから取得した表示を使用します。")
                .font(.caption2).foregroundStyle(KSTheme.tertiary).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link("プライバシーポリシー", destination: Self.privacyPolicyURL)
                    .accessibilityIdentifier("privacy-policy-link")
                Link("利用規約", destination: Self.termsOfUseURL)
                    .accessibilityIdentifier("terms-of-use-link")
            }
            .font(.caption.bold())
            .foregroundStyle(KSTheme.ai)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(KSTheme.paper)
    }
}
