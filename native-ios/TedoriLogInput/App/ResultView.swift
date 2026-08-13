import SwiftUI
import TedoriLogCore

/// 画面C｜結果。製品チェック1で「毎月使いたいか」を判断してもらうための所要時間も出す。
struct ResultView: View {
    @ObservedObject var state: ImportFlowState

    var body: some View {
        List {
            if let payload = state.savedPayload {
                Section("保存しました") {
                    row("取り込みから保存まで", String(format: "%.0f秒", state.totalSeconds))
                    row("解析時間", String(format: "%.0fms（OCR %d回）", state.analyzeMs, state.ocrPasses))
                    row("そのまま確認した項目", "\(payload.items.filter { $0.source == .userConfirmed }.count) 件")
                    row("直した項目", "\(payload.items.filter { $0.source == .userEdited }.count) 件（操作 \(state.editCount + state.manualCount) 回）")
                    row("未入力のまま", "\(payload.items.filter { $0.source == .empty }.count) 件")
                    row("外部送信", "なし（端末内で完結）")
                }

                Section("保存された内容") {
                    ForEach(payload.items, id: \.key) { item in
                        HStack {
                            Text(item.label)
                            Spacer()
                            Text(item.value.map { $0.formatted() } ?? "未入力")
                                .foregroundStyle(item.value == nil ? .secondary : .primary)
                        }
                    }
                }

                Section {
                    Text("明細の画像・PDF・読み取った原文は保存していません。保存したのは上の金額と、確認したかどうかの記録だけです。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("別の明細を取り込む") { state.restart() }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
