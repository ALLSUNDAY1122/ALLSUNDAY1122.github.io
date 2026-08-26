import AppIntents
import SwiftUI
import WidgetKit

@main
struct ClipboardWidgetBundle: WidgetBundle {
    var body: some Widget { ClipboardProbeWidget() }
}

struct ProbeEntry: TimelineEntry {
    let date: Date
    let receipt: ProbeReceipt?
}

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry { ProbeEntry(date: .now, receipt: nil) }
    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(ProbeEntry(date: .now, receipt: SharedProbeStore.loadReceipt()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        completion(Timeline(entries: [ProbeEntry(date: .now, receipt: SharedProbeStore.loadReceipt())], policy: .never))
    }
}

struct ClipboardProbeWidget: Widget {
    let kind = "ClipboardProbeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProbeProvider()) { entry in
            ClipboardProbeWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("クリップボードWidget PoC")
        .description("WidgetからPasteboardへ1タップ書き込みできるか検証します。")
        .supportedFamilies([.systemLarge])
    }
}

struct ClipboardProbeWidgetView: View {
    let entry: ProbeEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "doc.on.clipboard").font(.title2.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phase 0 / 実機PoC").font(.headline)
                    Text("現行安定版はまずAを検証").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(intent: WidgetExtensionCopyProbeIntent()) {
                HStack {
                    Image(systemName: "a.square.fill")
                    Text("TESTをコピー").fontWeight(.semibold)
                    Spacer()
                    Text("Widget Extension").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
            }.buttonStyle(.borderedProminent)
            Text("Bの main-process実行指定APIはXcode 26.6安定版SDKに未収録のため、このビルドには入れていません。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            if let receipt = entry.receipt {
                Text("Intent実行：\(receipt.method.rawValue) / \(receipt.executedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption.weight(.semibold))
            } else {
                Text("まだIntentは実行されていません").font(.caption).foregroundStyle(.secondary)
            }
            Text("※ Intent実行表示はコピー成功の証拠ではありません。メモへPasteして判定します。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(4)
    }
}
