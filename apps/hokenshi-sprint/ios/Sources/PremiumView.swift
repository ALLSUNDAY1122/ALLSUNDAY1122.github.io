import SwiftUI

/// 買い切りの案内・購入・復元。
struct PremiumView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("全546問を解放")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("保健師国家試験 第108〜112回（全5回分）の過去問546問と解説、図表問題36問がすべて使えるようになります。買い切りで、月額料金はありません。")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ink)
                        Text("無料では最新・第112回の30問をお試しいただけます。")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.sub)
                    }
                    if premium.isPremium {
                        Label("購入済みです。全問をご利用いただけます。", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.good)
                    } else {
                        Button {
                            Task { await premium.purchase() }
                        } label: {
                            if premium.busy {
                                ProgressView().tint(.white)
                            } else {
                                Text("買い切りで解放する（\(premium.product?.displayPrice ?? "¥800")）")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
                        .disabled(premium.busy)
                        Button("購入を復元する") {
                            Task { await premium.restore() }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.teal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .disabled(premium.busy)
                    }
                    if !premium.message.isEmpty {
                        Text(premium.message)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.sub)
                    }
                }
                .padding(20)
            }
            .background(Palette.paper)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                if premium.product == nil { await premium.loadProducts() }
            }
        }
    }
}
