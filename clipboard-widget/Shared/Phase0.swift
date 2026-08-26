import AppIntents
import UIKit

struct PasteboardProbePayload {
    static let widgetExtension = "Widget Copy Test"
    static let appBaseline = "Widget Copy Test - App Baseline"
}

@available(iOS 26.0, *)
struct WidgetExtensionCopyProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "TESTをコピー"
    static let description = IntentDescription("Widget ExtensionプロセスからPasteboardへ検証文字列を書き込みます。")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult {
        UIPasteboard.general.string = PasteboardProbePayload.widgetExtension
        return .result()
    }
}
