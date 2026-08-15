import Foundation
import SwiftUI

struct SplatEditSettings: Codable, Equatable, Sendable {
    var exposureEV: Double = 0
    var contrast: Double = 1
    var cropXMin: Double = 0
    var cropXMax: Double = 1
    var cropYMin: Double = 0
    var cropYMax: Double = 1
    var cropZMin: Double = 0
    var cropZMax: Double = 1

    static let `default` = SplatEditSettings()

    var hasCrop: Bool {
        cropXMin > 0.0001 || cropXMax < 0.9999 ||
        cropYMin > 0.0001 || cropYMax < 0.9999 ||
        cropZMin > 0.0001 || cropZMax < 0.9999
    }

    func normalized() -> SplatEditSettings {
        var value = self
        value.exposureEV = Self.clamp(value.exposureEV, -2...2)
        value.contrast = Self.clamp(value.contrast, 0.5...1.5)
        Self.normalizeRange(low: &value.cropXMin, high: &value.cropXMax)
        Self.normalizeRange(low: &value.cropYMin, high: &value.cropYMax)
        Self.normalizeRange(low: &value.cropZMin, high: &value.cropZMax)
        return value
    }

    private static func normalizeRange(low: inout Double, high: inout Double) {
        low = clamp(low, 0...1)
        high = clamp(high, 0...1)
        if high - low < 0.02 {
            let center = (low + high) * 0.5
            low = clamp(center - 0.01, 0...0.98)
            high = clamp(low + 0.02, 0.02...1)
        }
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

enum SplatMeasurementFormatter {
    static func string(meters: Float) -> String {
        let value = max(0, meters)
        if value < 0.01 {
            return String(format: "%.1f mm", value * 1_000)
        }
        if value < 1 {
            return String(format: "%.1f cm", value * 100)
        }
        return String(format: "%.2f m", value)
    }
}

@MainActor
final class SplatViewerState: ObservableObject {
    @Published var exposureEV: Double = 0
    @Published var contrast: Double = 1
    @Published var cropXMin: Double = 0
    @Published var cropXMax: Double = 1
    @Published var cropYMin: Double = 0
    @Published var cropYMax: Double = 1
    @Published var cropZMin: Double = 0
    @Published var cropZMax: Double = 1
    @Published var measurementEnabled = false

    @Published private(set) var isLoading = true
    @Published private(set) var isApplyingEdits = false
    @Published private(set) var totalPointCount = 0
    @Published private(set) var visiblePointCount = 0
    @Published private(set) var measurementText = "画面上の2点を順番にタップしてください"
    @Published private(set) var errorMessage: String?
    @Published private(set) var warningMessage: String?
    @Published private(set) var resetCameraToken = 0
    @Published private(set) var clearMeasurementToken = 0
    @Published private(set) var reloadToken = 0

    private var sourceURL: URL?
    private var persistenceTask: Task<Void, Never>?

    var editSettings: SplatEditSettings {
        SplatEditSettings(
            exposureEV: exposureEV,
            contrast: contrast,
            cropXMin: cropXMin,
            cropXMax: cropXMax,
            cropYMin: cropYMin,
            cropYMax: cropYMax,
            cropZMin: cropZMin,
            cropZMax: cropZMax
        ).normalized()
    }

    func attach(url: URL) {
        guard sourceURL != url else { return }
        sourceURL = url
        measurementEnabled = false
        measurementText = "画面上の2点を順番にタップしてください"
        errorMessage = nil
        warningMessage = nil
        totalPointCount = 0
        visiblePointCount = 0
        isLoading = true
        isApplyingEdits = false
        loadPersistedEdits()
        clearMeasurementToken &+= 1
    }

    func resetEdits() {
        apply(.default)
        persistNow()
    }

    func requestCameraReset() {
        resetCameraToken &+= 1
    }

    func requestMeasurementClear() {
        measurementText = "画面上の2点を順番にタップしてください"
        clearMeasurementToken &+= 1
    }

    func requestReload() {
        errorMessage = nil
        warningMessage = nil
        isLoading = true
        reloadToken &+= 1
    }

    func schedulePersistence() {
        guard sourceURL != nil else { return }
        persistenceTask?.cancel()
        persistenceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled, let self else { return }
            self.persistNow()
        }
    }

    func persistNow() {
        guard let url = sidecarURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(editSettings).write(to: url, options: .atomic)
        } catch {
            warningMessage = "編集内容を保存できませんでした"
        }
    }

    func rendererBeganLoading() {
        isLoading = true
        errorMessage = nil
        warningMessage = nil
    }

    func rendererLoaded(total: Int) {
        totalPointCount = total
        visiblePointCount = total
        isLoading = false
        errorMessage = nil
    }

    func rendererBeganApplyingEdits() {
        isApplyingEdits = true
        warningMessage = nil
    }

    func rendererAppliedEdits(visible: Int) {
        visiblePointCount = visible
        isApplyingEdits = false
        warningMessage = nil
    }

    func rendererRejectedEdit(_ message: String) {
        isApplyingEdits = false
        warningMessage = message
    }

    func rendererFailed(_ message: String) {
        isLoading = false
        isApplyingEdits = false
        errorMessage = message
    }

    func rendererSelectedMeasurementPoint(count: Int) {
        if count == 1 {
            measurementText = "始点を選択しました。終点をタップしてください"
        }
    }

    func rendererMeasured(meters: Float) {
        measurementText = SplatMeasurementFormatter.string(meters: meters)
    }

    private var sidecarURL: URL? {
        sourceURL?.deletingPathExtension().appendingPathExtension("viewer.json")
    }

    private func loadPersistedEdits() {
        guard let url = sidecarURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SplatEditSettings.self, from: data) else {
            apply(.default)
            return
        }
        apply(decoded.normalized())
    }

    private func apply(_ settings: SplatEditSettings) {
        let value = settings.normalized()
        exposureEV = value.exposureEV
        contrast = value.contrast
        cropXMin = value.cropXMin
        cropXMax = value.cropXMax
        cropYMin = value.cropYMin
        cropYMax = value.cropYMax
        cropZMin = value.cropZMin
        cropZMax = value.cropZMax
    }
}
