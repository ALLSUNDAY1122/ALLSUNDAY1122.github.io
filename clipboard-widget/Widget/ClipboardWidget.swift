import AppIntents
import SwiftUI
import WidgetKit

@main
struct ClipboardWidgetBundle: WidgetBundle {
    var body: some Widget { ClipboardProbeWidget() }
}

struct ProbeEntry: TimelineEntry {
    let date: Date
}

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry { ProbeEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(ProbeEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        completion(Timeline(entries: [ProbeEntry(date: .now)], policy: .never))
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
            Text("押したあとメモへPasteし、“Widget Copy Test” と完全一致するか確認します。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Bの main-process実行指定APIはXcode 26.6安定版SDKに未収録のため、このビルドには入れていません。")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Divider()
            Text("Phase 0では核心検証を署名要件から分離するためApp Groupを使いません。共有保存はPASS-A後のMVPで追加します。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(4)
    }
}
