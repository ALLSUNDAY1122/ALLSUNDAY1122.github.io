import AppIntents
import Foundation
import UIKit

struct PasteboardProbePayload {
    static let widgetExtension = "Widget Copy Test"
    static let appBaseline = "Widget Copy Test - App Baseline"
}

enum ProbeMethod: String, Codable {
    case widgetExtension = "A / Widget Extension"
}

struct ProbeReceipt: Codable, Equatable {
    let method: ProbeMethod
    let executedAt: Date
}

enum SharedProbeStore {
    static let appGroupIdentifier = "group.jp.allsunday1122.clipboardwidget"
    private static let receiptKey = "phase0.lastProbeReceipt"

    static func saveReceipt(_ receipt: ProbeReceipt) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(receipt) else { return }
        defaults.set(data, forKey: receiptKey)
    }

    static func loadReceipt() -> ProbeReceipt? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: receiptKey) else { return nil }
        return try? JSONDecoder().decode(ProbeReceipt.self, from: data)
    }
}

@available(iOS 26.0, *)
struct WidgetExtensionCopyProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "TESTをコピー"
    static let description = IntentDescription("Widget ExtensionプロセスからPasteboardへ検証文字列を書き込みます。")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult {
        UIPasteboard.general.string = PasteboardProbePayload.widgetExtension
        SharedProbeStore.saveReceipt(ProbeReceipt(method: .widgetExtension, executedAt: Date()))
        return .result()
    }
}
