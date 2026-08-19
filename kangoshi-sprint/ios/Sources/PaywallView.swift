import SwiftUI
import LearningSprintCore

struct PaywallView: View {
    @EnvironmentObject var purchase: PurchaseController
    @Environment(\.dismiss) private var dismiss

    private let monthlyID = "jp.allsunday1122.kangoshi.monthly"
    private let lifetimeID = "jp.allsunday1122.kangoshi.lifetime"

    private var stateMessage: String? {
        switch purchase.state {
        case .pending: return "購入承認を待っています。"
        case .cancelled: return "購入はキャンセルされました。"
        case .unavailable(let text), .failed(let text): return text
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill").font(.system(size: 42)).foregroundStyle(KSTheme.ai)
                        Text("学びスプリント プレミアム").font(.title2.bold()).foregroundStyle(KSTheme.ink)
                        Text("必要なところだけ、短く繰り返す。全720問と本番形式を解放します。").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(KSTheme.secondary)
                    }.padding(.top,20)
                    KSCard(content: VStack(alignment:.leading,spacing:12) {
                        Label("苦手を3回連続正解まで自動追跡", systemImage:"repeat.circle.fill")
                        Label("11科目・区分別から学習", systemImage:"square.grid.2x2.fill")
                        Label("第115・114・113回の本番形式", systemImage:"doc.text.fill")
                        Label("詳細な学習記録", systemImage:"chart.bar.fill")
                        Label("制度・出題基準の更新対応", systemImage:"arrow.triangle.2.circlepath")
                    }.font(.subheadline).foregroundStyle(KSTheme.ink))

                    if purchase.isPremium {
                        Label("利用中です", systemImage:"checkmark.seal.fill").font(.headline).foregroundStyle(KSTheme.green)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                Task { await purchase.purchase(productID: monthlyID) }
                            } label: {
                                VStack(spacing:3) {
                                    Text(purchase.state == .purchasing ? "購入処理中…" : "月額プラン").font(.headline)
                                    Text(purchase.displayPrice(for: monthlyID).map { "月額 \($0)" } ?? "価格を取得中").font(.caption)
                                }.frame(maxWidth:.infinity).padding(.vertical,13)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(KSTheme.ai)
                            .disabled(purchase.product(for: monthlyID) == nil || purchase.state == .purchasing)

                            Button {
                                Task { await purchase.purchase(productID: lifetimeID) }
                            } label: {
                                VStack(spacing:3) {
                                    Text(purchase.state == .purchasing ? "購入処理中…" : "買い切りプラン").font(.headline)
                                    Text(purchase.displayPrice(for: lifetimeID).map { "買い切り \($0)" } ?? "価格を取得中").font(.caption)
                                }.frame(maxWidth:.infinity).padding(.vertical,13)
                            }
                            .buttonStyle(.bordered)
                            .tint(KSTheme.ai)
                            .disabled(purchase.product(for: lifetimeID) == nil || purchase.state == .purchasing)
                        }
                    }

                    Button("購入を復元") { Task { await purchase.restore() } }
                        .font(.subheadline.bold()).foregroundStyle(KSTheme.ai)
                    if let stateMessage { Text(stateMessage).font(.caption).foregroundStyle(KSTheme.shu).multilineTextAlignment(.center) }
                    Text("月額プランは自動更新、買い切りプランは1回の購入です。価格はApp Storeから取得した表示を使用します。購入・更新・解約・復元はApple IDの設定に従います。")
                        .font(.caption2).foregroundStyle(KSTheme.tertiary).multilineTextAlignment(.center)
                }.padding(18)
            }.background(KSTheme.paper.ignoresSafeArea())
                .navigationTitle("プレミアム")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}
