import SwiftUI
import TedoriLogCore
import TedoriLogVision

@main
struct TedoriLogInputApp: App {
    @StateObject private var state = ImportFlowState()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                switch state.step {
                case .input:
                    InputView(state: state)
                case .review:
                    ReviewView(state: state)
                case .result:
                    ResultView(state: state)
                }
            }
        }
    }
}

/// 取込→確認→保存の流れと計測をまとめて持つ。
@MainActor
final class ImportFlowState: ObservableObject {

    enum Step { case input, review, result }

    @Published var step: Step = .input
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var qualityMessage: String?

    @Published private(set) var result: PayslipResult?
    @Published private(set) var pageImages: [CGImage] = []
    @Published var confirmations: [ItemKey: SaveGuard.Confirmation] = [:]
    @Published var focusedItem: ItemKey?
    @Published private(set) var savedPayload: SaveGuard.Payload?

    @Published private(set) var analyzeMs: Double = 0
    @Published private(set) var ocrPasses: Int = 0
    private var startedAt: Date?
    /// 取込を始めてから保存し終わるまで（製品チェック1で見る所要時間）
    @Published private(set) var totalSeconds: Double = 0

    var editCount = 0
    var manualCount = 0

    func beginTiming() {
        startedAt = Date()
        errorMessage = nil
        qualityMessage = nil
    }

    func handle(_ imported: PayslipImporter.ImportResult) {
        result = imported.result
        pageImages = imported.pageImages
        analyzeMs = imported.elapsedMs
        ocrPasses = imported.ocrPasses
        qualityMessage = imported.quality?.shouldRetake == true ? imported.quality?.message : nil
        confirmations = [:]
        for key in ItemKey.allCases {
            confirmations[key] = SaveGuard.Confirmation(value: imported.result.items[key]?.value,
                                                        confirmed: false, edited: false)
        }
        editCount = 0
        manualCount = 0
        focusedItem = nil
        if imported.result.ok {
            step = .review
        } else {
            errorMessage = imported.result.message ?? "解析できませんでした"
        }
    }

    func fail(_ message: String) {
        errorMessage = message
        isAnalyzing = false
    }

    func save() -> Bool {
        guard let result else { return false }
        let draft = SaveGuard.buildDraft(result: result, confirmations: confirmations)
        guard draft.ok, let payload = draft.payload else {
            errorMessage = "保存できません。未確認の項目があります: "
                + draft.blocked.map(\.label).joined(separator: "、")
            return false
        }
        savedPayload = payload
        totalSeconds = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        step = .result
        return true
    }

    func restart() {
        result = nil
        pageImages = []
        confirmations = [:]
        savedPayload = nil
        errorMessage = nil
        qualityMessage = nil
        step = .input
    }
}
