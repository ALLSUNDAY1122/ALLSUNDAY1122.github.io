import SwiftUI
import UIKit

@main
struct ClipboardWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var directCopyState = "未実行"

    var body: some View {
        NavigationStack {
            List {
                Section("Phase 0") {
                    Label("Large Widgetを追加してください", systemImage: "rectangle.grid.2x2")
                    Text("まずWidgetの「TESTをコピー」を押し、メモへ貼り付けて “Widget Copy Test” になるか確認します。失敗した場合だけBを試します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("本体Pasteboard基準確認") {
                    Button {
                        UIPasteboard.general.string = PasteboardProbePayload.appBaseline
                        directCopyState = "本体から書込実行済み"
                    } label: {
                        Label("本体でTESTをコピー", systemImage: "doc.on.doc")
                    }
                    Text(directCopyState).font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("このPoCはPasteboardを読み取りません。Buttonの明示操作時だけ文字列を書き込みます。")
                        .font(.subheadline)
                }
            }
            .navigationTitle("クリップボードWidget")
        }
    }
}
