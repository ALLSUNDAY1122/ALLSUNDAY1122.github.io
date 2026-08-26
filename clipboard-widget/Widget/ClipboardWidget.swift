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
                    Text("Aを先に試し、失敗時だけB").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(intent: WidgetExtensionCopyProbeIntent()) {
                HStack {
                    Image(systemName: "a.square.fill")
                    Text("TESTをコピー").fontWeight(.semibold)
                    Spacer()
                    Text("Widget Extension").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.borderedProminent)
            Button(intent: MainBackgroundCopyProbeIntent()) {
                HStack {
                    Image(systemName: "b.square.fill")
                    Text("B：Main background").fontWeight(.semibold)
                    Spacer()
                    Text("A失敗時のみ").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.bordered)
            Divider()
            if let receipt = entry.receipt {
                Text("Intent実行：\(receipt.method.rawValue) / \(receipt.executedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption.weight(.semibold))
            } else {
                Text("まだIntentは実行されていません").font(.caption).foregroundStyle(.secondary)
            }
            Text("※ これはIntent実行証拠です。コピー成功はメモへPasteして判定します。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(4)
    }
}
