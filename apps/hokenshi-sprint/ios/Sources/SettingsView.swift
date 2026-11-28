import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPremium = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Premium") {
                    if premium.isPremium {
                        Label("全546問を利用中（買い切り）", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.good)
                    } else {
                        Button("全546問を解放する（買い切り）") { showPremium = true }
                            .foregroundStyle(Palette.teal)
                        Button("購入を復元する") {
                            Task { await premium.restore() }
                        }
                        .foregroundStyle(Palette.teal)
                    }
                    if !premium.message.isEmpty {
                        Text(premium.message)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                    }
                }
                Section("学習記録") {
                    HStack {
                        Text("総回答数")
                        Spacer()
                        Text("\(records.totalAnswered) 問")
                            .foregroundStyle(Palette.sub)
                    }
                    HStack {
                        Text("復習中の問題")
                        Spacer()
                        Text("\(records.weakCount) 問")
                            .foregroundStyle(Palette.sub)
                    }
                    Button("学習記録をリセット", role: .destructive) { confirmReset = true }
                }
                Section("このアプリについて") {
                    Text("保健師国家試験の過去問題（第108〜112回）を収録しています。問題・正答は厚生労働省が公表した資料に基づき、解説は本アプリ独自に作成したものです。法令・統計は出題当時の内容のため、現在の制度とは異なる場合があります（該当する問題には注記があります）。")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                    Link("プライバシーポリシー",
                         destination: URL(string: "https://allsunday1122.github.io/hokenshi-sprint/privacy.html")!)
                    Link("サポート",
                         destination: URL(string: "https://allsunday1122.github.io/hokenshi-sprint/support.html")!)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showPremium) { PremiumView() }
            .confirmationDialog("学習記録をすべて消去しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("消去する", role: .destructive) { records.resetAll() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}
