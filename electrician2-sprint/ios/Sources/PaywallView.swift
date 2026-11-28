import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    static let privacyPolicyURL = URL(string: "https://allsunday1122.github.io/electrician2-sprint/privacy.html")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var monthlyProduct: Product? { premium.products[PremiumStore.monthlyID] }
    private var hasFreeTrial: Bool {
        guard let offer = monthlyProduct?.subscription?.introductoryOffer else { return false }
        return offer.paymentMode == .freeTrial
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.fill").font(.system(size: 42)).foregroundStyle(ETheme.gold)
                            Text("プレミアム").font(.system(size: 24, weight: .bold, design: .serif)).foregroundStyle(ETheme.ink)
                            Text("公式過去問600問（12回分）のすべてと、本番形式・分野別・苦手つぶしの全問題を解放します。無料では令和8年度上期の50問を収録しています。")
                                .font(.system(size: 13)).multilineTextAlignment(.center).foregroundStyle(ETheme.ink2)
                        }.padding(.top, 20)

                        Panel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("全600問・12回分を解放", systemImage: "doc.text.fill")
                                Label("本番形式（50問×12回）", systemImage: "timer")
                                Label("分野別・苦手つぶしの全問題", systemImage: "repeat.circle.fill")
                                Label("詳細な学習記録", systemImage: "chart.bar.fill")
                            }.font(.system(size: 14, weight: .semibold)).foregroundStyle(ETheme.ink)
                        }

                        if premium.isPremium {
                            Label("プレミアム利用中です", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(ETheme.green)
                        } else {
                            VStack(spacing: 10) {
                                Button {
                                    Task { await premium.purchase(PremiumStore.monthlyID) }
                                } label: {
                                    VStack(spacing: 3) {
                                        Text(premium.busy ? "購入処理中…" : "月額プラン").font(.system(size: 16, weight: .heavy))
                                        Text(monthlyCaption).font(.system(size: 12))
                                    }.frame(maxWidth: .infinity).padding(.vertical, 13)
                                }
                                .buttonStyle(.borderedProminent).tint(ETheme.blue)
                                .disabled(premium.busy || monthlyProduct == nil)

                                Button {
                                    Task { await premium.purchase(PremiumStore.lifetimeID) }
                                } label: {
                                    VStack(spacing: 3) {
                                        Text(premium.busy ? "購入処理中…" : "買い切りプラン").font(.system(size: 16, weight: .heavy))
                                        Text(lifetimeCaption).font(.system(size: 12))
                                    }.frame(maxWidth: .infinity).padding(.vertical, 13)
                                }
                                .buttonStyle(.bordered).tint(ETheme.blue)
                                .disabled(premium.busy || premium.products[PremiumStore.lifetimeID] == nil)
                            }
                        }

                        Button("購入を復元") { Task { await premium.restore() } }
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(ETheme.blue)
                            .accessibilityIdentifier("restore-purchases")
                        if !premium.message.isEmpty {
                            Text(premium.message).font(.system(size: 12)).foregroundStyle(ETheme.muted).multilineTextAlignment(.center)
                        }
                    }.padding(18).frame(maxWidth: 520).frame(maxWidth: .infinity)
                }
                legalFooter
            }
            .background(ETheme.paper.ignoresSafeArea())
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
            .task { await premium.refresh() }
        }
    }

    private var monthlyCaption: String {
        guard let price = monthlyProduct?.displayPrice else { return "価格を取得中" }
        return hasFreeTrial ? "最初の1週間無料・その後 月額 \(price)" : "月額 \(price)"
    }
    private var lifetimeCaption: String {
        guard let price = premium.products[PremiumStore.lifetimeID]?.displayPrice else { return "価格を取得中" }
        return "買い切り \(price)（一度だけの支払い）"
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("月額プランは1か月ごとの自動更新です。無料トライアル終了後は自動で課金されます。更新の停止・解約はiOSの設定 > Apple ID > サブスクリプションから行えます。買い切りプランは1回の購入です。")
                .font(.system(size: 10)).foregroundStyle(ETheme.muted).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link("プライバシーポリシー", destination: Self.privacyPolicyURL)
                    .accessibilityIdentifier("privacy-policy-link")
                Link("利用規約", destination: Self.termsOfUseURL)
                    .accessibilityIdentifier("terms-of-use-link")
            }
            .font(.system(size: 12, weight: .bold)).foregroundStyle(ETheme.blue)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
        .frame(maxWidth: .infinity).background(ETheme.paper)
    }
}
