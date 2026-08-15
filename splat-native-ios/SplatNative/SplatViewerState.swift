import Foundation
import SwiftUI
import simd

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

/// Mirrors msplat's `autoScaleAndCenter` transform for Nerfstudio input.
/// The trainer exports gaussians in this normalized coordinate system, so
/// distances in the exported Splat must be multiplied by `1 / scale` to recover meters.
struct SplatSceneNormalization: Equatable, Sendable {
    let translation: SIMD3<Float>
    let scale: Float

    init(cameraPositions: [SIMD3<Float>]) {
        guard !cameraPositions.isEmpty else {
            translation = .zero
            scale = 1
            return
        }

        let total = cameraPositions.reduce(SIMD3<Float>.zero, +)
        let mean = total / Float(cameraPositions.count)
        var maxAbs: Float = 0
        for position in cameraPositions {
            let centered = position - mean
            maxAbs = max(maxAbs, abs(centered.x), abs(centered.y), abs(centered.z))
        }
        translation = mean
        scale = maxAbs > 0 ? 1 / maxAbs : 1
    }

    var metersPerSceneUnit: Float {
        scale > 0.000001 ? 1 / scale : 1
    }

    func normalized(_ worldPosition: SIMD3<Float>) -> SIMD3<Float> {
        (worldPosition - translation) * scale
    }
}

private struct MeasurementTransforms: Decodable {
    let frames: [MeasurementFrame]
}

private struct MeasurementFrame: Decodable {
    let transformMatrix: [[Float]]

    enum CodingKeys: String, CodingKey {
        case transformMatrix = "transform_matrix"
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
    private var metersPerSceneUnit: Float = 1

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
        metersPerSceneUnit = Self.measurementScale(for: url)
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

    /// The renderer reports distance in exported Splat scene units. The parameter
    /// label is retained for the renderer-facing API, then converted back to meters here.
    func rendererMeasured(meters sceneUnits: Float) {
        measurementText = SplatMeasurementFormatter.string(
            meters: sceneUnits * metersPerSceneUnit
        )
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

    private static func measurementScale(for splatURL: URL) -> Float {
        let transformsURL = splatURL.deletingLastPathComponent().appendingPathComponent("transforms.json")
        guard let data = try? Data(contentsOf: transformsURL),
              let dataset = try? JSONDecoder().decode(MeasurementTransforms.self, from: data) else {
            return 1
        }

        let positions = dataset.frames.compactMap { frame -> SIMD3<Float>? in
            let matrix = frame.transformMatrix
            guard matrix.count >= 3,
                  matrix[0].count >= 4,
                  matrix[1].count >= 4,
                  matrix[2].count >= 4 else { return nil }
            return SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
        }
        return SplatSceneNormalization(cameraPositions: positions).metersPerSceneUnit
    }
}
