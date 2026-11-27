import SwiftUI

/// 設定：広告なし（買い切り）の購入・復元、学習記録リセット、クレジット。
struct SettingsView: View {
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @EnvironmentObject private var bgm: BGMPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("BGM") {
                    Toggle("BGMを再生", isOn: Binding(
                        get: { bgm.enabled },
                        set: { bgm.setEnabled($0) }
                    ))
                    .tint(Palette.primary)
                    Text("やさしい音楽が小さな音で流れます。")
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                }
                Section("広告について") {
                    Text(premium.isNoAds
                        ? "広告なしを利用中です。ありがとうございます。"
                        : "無料版では広告（バナー）が表示されます。")
                        .foregroundStyle(Palette.ink)
                    if !premium.isNoAds {
                        Button {
                            Task { await premium.purchase() }
                        } label: {
                            HStack {
                                Text("広告なし（買い切り）")
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text(premium.product?.displayPrice ?? "取得できません")
                                    .foregroundStyle(Palette.sub)
                            }
                        }
                        .disabled(premium.busy || !premium.checked || premium.product == nil)
                        Text("一度の購入で、ずっと広告が表示されなくなります。学年や機能の制限はありません。")
                            .font(.footnote)
                            .foregroundStyle(Palette.sub)
                    }
                    Button("購入を復元") { Task { await premium.restore() } }
                        .disabled(premium.busy)
                    Button("商品情報を再取得") { Task { await premium.refresh() } }
                        .disabled(premium.busy)
                    if premium.busy { ProgressView() }
                    if !premium.message.isEmpty {
                        Text(premium.message)
                            .font(.footnote)
                            .foregroundStyle(Palette.sub)
                    }
                }
                Section("学習記録") {
                    Button("学習記録をリセット", role: .destructive) {
                        showResetConfirm = true
                    }
                    Text("読みクイズの記録・苦手・書き完了をすべて消します。")
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                }
                Section("データの出典・クレジット") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("漢字の学年・読み・画数")
                            .font(.subheadline.bold())
                            .foregroundStyle(Palette.ink)
                        Text("KANJIDIC2 © The Electronic Dictionary Research and Development Group（EDRDG）／ CC BY-SA 4.0")
                            .font(.footnote)
                            .foregroundStyle(Palette.sub)
                        Text("学年の配当は文部科学省「学年別漢字配当表」（平成29年告示）に基づきます。")
                            .font(.footnote)
                            .foregroundStyle(Palette.sub)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("筆順・字形")
                            .font(.subheadline.bold())
                            .foregroundStyle(Palette.ink)
                        Text("KanjiVG © Ulrich Apel and contributors ／ CC BY-SA 3.0")
                            .font(.footnote)
                            .foregroundStyle(Palette.sub)
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await premium.refresh() }
            .alert("学習記録をリセットしますか？", isPresented: $showResetConfirm) {
                Button("リセット", role: .destructive) {
                    records.resetAll()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("読みクイズの記録・苦手・書き完了がすべて消えます。")
            }
        }
    }
}
