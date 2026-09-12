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

    private enum CodingKeys: String, CodingKey {
        case exposureEV, contrast
        case cropXMin, cropXMax, cropYMin, cropYMax, cropZMin, cropZMax
    }

    init(
        exposureEV: Double = 0,
        contrast: Double = 1,
        cropXMin: Double = 0,
        cropXMax: Double = 1,
        cropYMin: Double = 0,
        cropYMax: Double = 1,
        cropZMin: Double = 0,
        cropZMax: Double = 1
    ) {
        self.exposureEV = exposureEV
        self.contrast = contrast
        self.cropXMin = cropXMin
        self.cropXMax = cropXMax
        self.cropYMin = cropYMin
        self.cropYMax = cropYMax
        self.cropZMin = cropZMin
        self.cropZMax = cropZMax
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        exposureEV = try values.decodeIfPresent(Double.self, forKey: .exposureEV) ?? 0
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        cropXMin = try values.decodeIfPresent(Double.self, forKey: .cropXMin) ?? 0
        cropXMax = try values.decodeIfPresent(Double.self, forKey: .cropXMax) ?? 1
        cropYMin = try values.decodeIfPresent(Double.self, forKey: .cropYMin) ?? 0
        cropYMax = try values.decodeIfPresent(Double.self, forKey: .cropYMax) ?? 1
        cropZMin = try values.decodeIfPresent(Double.self, forKey: .cropZMin) ?? 0
        cropZMax = try values.decodeIfPresent(Double.self, forKey: .cropZMax) ?? 1
    }

    var hasCrop: Bool {
        cropXMin > 0.0001 || cropXMax < 0.9999 ||
        cropYMin > 0.0001 || cropYMax < 0.9999 ||
        cropZMin > 0.0001 || cropZMax < 0.9999
    }

    func normalized() -> SplatEditSettings {
        var value = self
        value.exposureEV = value.exposureEV.isFinite ? Self.clamp(value.exposureEV, -2...2) : 0
        value.contrast = value.contrast.isFinite ? Self.clamp(value.contrast, 0.5...1.5) : 1
        if !value.cropXMin.isFinite { value.cropXMin = 0 }
        if !value.cropXMax.isFinite { value.cropXMax = 1 }
        if !value.cropYMin.isFinite { value.cropYMin = 0 }
        if !value.cropYMax.isFinite { value.cropYMax = 1 }
        if !value.cropZMin.isFinite { value.cropZMin = 0 }
        if !value.cropZMax.isFinite { value.cropZMax = 1 }
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
        let value = meters.isFinite ? max(0, meters) : 0
        if value < 0.01 { return String(format: "%.1f mm", value * 1_000) }
        if value < 1 { return String(format: "%.1f cm", value * 100) }
        return String(format: "%.2f m", value)
    }
}

/// Durable viewer-edit sidecar. The backup is intentionally separate from the scan manifest:
/// viewer edits can be recovered without making the reconstructed asset itself untrusted.
struct SplatViewerEditStore {
    static func primaryURL(for sourceURL: URL) -> URL {
        sourceURL.deletingPathExtension().appendingPathExtension("viewer.json")
    }

    static func backupURL(for sourceURL: URL) -> URL {
        sourceURL.deletingPathExtension().appendingPathExtension("viewer.json.bak")
    }

    static func load(sourceURL: URL, fileManager: FileManager = .default) -> (settings: SplatEditSettings, recoveredFromBackup: Bool)? {
        let decoder = JSONDecoder()
        let primary = primaryURL(for: sourceURL)
        if let data = try? Data(contentsOf: primary),
           let decoded = try? decoder.decode(SplatEditSettings.self, from: data) {
            return (decoded.normalized(), false)
        }

        let backup = backupURL(for: sourceURL)
        guard let data = try? Data(contentsOf: backup),
              let decoded = try? decoder.decode(SplatEditSettings.self, from: data) else {
            return nil
        }
        // Best-effort self-heal: a valid backup becomes the new primary. Failure here does not
        // discard the recovered settings; the caller can still render them and warn the user.
        try? data.write(to: primary, options: .atomic)
        return (decoded.normalized(), true)
    }

    static func save(_ settings: SplatEditSettings, sourceURL: URL, fileManager: FileManager = .default) throws {
        let primary = primaryURL(for: sourceURL)
        let backup = backupURL(for: sourceURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(settings.normalized())

        // Keep one known-good generation. Copy rather than move so an interrupted backup update
        // never removes the only valid primary before the new atomic write lands.
        var preservedPreviousGeneration = false
        if fileManager.fileExists(atPath: primary.path),
           let oldData = try? Data(contentsOf: primary),
           (try? decoder.decode(SplatEditSettings.self, from: oldData)) != nil {
            try oldData.write(to: backup, options: .atomic)
            preservedPreviousGeneration = true
        }

        // A backup file can exist but itself be truncated/corrupt. Treat only a decodable backup as
        // a recovery generation; otherwise the new successful primary must reseed it.
        let existingBackupIsValid: Bool
        if let backupData = try? Data(contentsOf: backup),
           (try? decoder.decode(SplatEditSettings.self, from: backupData)) != nil {
            existingBackupIsValid = true
        } else {
            existingBackupIsValid = false
        }

        try data.write(to: primary, options: .atomic)

        // The very first successful edit, or a successful save after backup corruption, must leave
        // a usable recovery generation. A valid older backup is intentionally preserved when the
        // previous primary was corrupt so one bad generation cannot erase the last known-good edit.
        if !preservedPreviousGeneration && !existingBackupIsValid {
            try data.write(to: backup, options: .atomic)
        }
    }
}

/// Mirrors msplat's `autoScaleAndCenter` transform for Nerfstudio input.
struct SplatSceneNormalization: Equatable, Sendable {
    let translation: SIMD3<Float>
    let scale: Float

    init(cameraPositions: [SIMD3<Float>]) {
        let finitePositions = cameraPositions.filter { position in
            position.x.isFinite && position.y.isFinite && position.z.isFinite
        }
        guard !finitePositions.isEmpty else { translation = .zero; scale = 1; return }
        let total = finitePositions.reduce(SIMD3<Float>.zero, +)
        guard total.x.isFinite, total.y.isFinite, total.z.isFinite else {
            translation = .zero; scale = 1; return
        }
        let mean = total / Float(finitePositions.count)
        var maxAbs: Float = 0
        for position in finitePositions {
            let centered = position - mean
            maxAbs = max(maxAbs, abs(centered.x), abs(centered.y), abs(centered.z))
        }
        translation = mean
        scale = maxAbs.isFinite && maxAbs > 0 ? 1 / maxAbs : 1
    }

    var metersPerSceneUnit: Float { scale.isFinite && scale > 0.000001 ? 1 / scale : 1 }
    func normalized(_ worldPosition: SIMD3<Float>) -> SIMD3<Float> { (worldPosition - translation) * scale }
}

private struct MeasurementTransforms: Decodable { let frames: [MeasurementFrame] }
private struct MeasurementFrame: Decodable {
    let transformMatrix: [[Float]]
    enum CodingKeys: String, CodingKey { case transformMatrix = "transform_matrix" }
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
    private var persistenceWarningMessage: String?

    private static let saveFailureWarning = "編集内容を保存できませんでした"
    private static let backupRecoveryWarning = "前回の編集設定をバックアップから復元しました"

    var editSettings: SplatEditSettings {
        SplatEditSettings(exposureEV: exposureEV, contrast: contrast, cropXMin: cropXMin, cropXMax: cropXMax, cropYMin: cropYMin, cropYMax: cropYMax, cropZMin: cropZMin, cropZMax: cropZMax).normalized()
    }

    func attach(url: URL) {
        guard sourceURL != url else { return }
        // If the user switches directly from one saved scan to another while a debounced edit is
        // pending, persistNow() must still target the old source URL. Flushing before replacing
        // sourceURL preserves the final edit without risking a delayed write into the new scan.
        if sourceURL != nil {
            persistNow()
        } else {
            persistenceTask?.cancel()
        }
        sourceURL = url
        metersPerSceneUnit = Self.measurementScale(for: url)
        measurementEnabled = false
        measurementText = "画面上の2点を順番にタップしてください"
        errorMessage = nil
        persistenceWarningMessage = nil
        warningMessage = nil
        totalPointCount = 0; visiblePointCount = 0
        isLoading = true; isApplyingEdits = false
        loadPersistedEdits()
        clearMeasurementToken &+= 1
    }

    func resetEdits() { apply(.default); persistNow() }
    func requestCameraReset() { resetCameraToken &+= 1 }
    func requestMeasurementClear() { measurementText = "画面上の2点を順番にタップしてください"; clearMeasurementToken &+= 1 }
    func requestReload() { errorMessage = nil; warningMessage = persistenceWarningMessage; isLoading = true; reloadToken &+= 1 }

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
        persistenceTask?.cancel()
        guard let sourceURL else { return }
        do {
            try SplatViewerEditStore.save(editSettings, sourceURL: sourceURL)
            let previousPersistenceWarning = persistenceWarningMessage
            persistenceWarningMessage = nil
            if warningMessage == previousPersistenceWarning {
                warningMessage = nil
            }
        } catch {
            persistenceWarningMessage = Self.saveFailureWarning
            warningMessage = Self.saveFailureWarning
        }
    }

    func rendererBeganLoading() { isLoading = true; errorMessage = nil; warningMessage = persistenceWarningMessage }
    func rendererLoaded(total: Int) { totalPointCount = total; visiblePointCount = total; isLoading = false; errorMessage = nil }
    func rendererBeganApplyingEdits() { isApplyingEdits = true; warningMessage = persistenceWarningMessage }
    func rendererAppliedEdits(visible: Int) { visiblePointCount = visible; isApplyingEdits = false; warningMessage = persistenceWarningMessage }
    func rendererRejectedEdit(_ message: String) { isApplyingEdits = false; warningMessage = message }
    func rendererFailed(_ message: String) { isLoading = false; isApplyingEdits = false; errorMessage = message }
    func rendererSelectedMeasurementPoint(count: Int) { if count == 1 { measurementText = "始点を選択しました。終点をタップしてください" } }
    func rendererMeasured(meters sceneUnits: Float) { measurementText = SplatMeasurementFormatter.string(meters: sceneUnits * metersPerSceneUnit) }

    private func loadPersistedEdits() {
        guard let sourceURL,
              let loaded = SplatViewerEditStore.load(sourceURL: sourceURL) else {
            apply(.default); return
        }
        apply(loaded.settings)
        if loaded.recoveredFromBackup {
            persistenceWarningMessage = Self.backupRecoveryWarning
            warningMessage = Self.backupRecoveryWarning
        }
    }

    private func apply(_ settings: SplatEditSettings) {
        let value = settings.normalized()
        exposureEV = value.exposureEV; contrast = value.contrast
        cropXMin = value.cropXMin; cropXMax = value.cropXMax
        cropYMin = value.cropYMin; cropYMax = value.cropYMax
        cropZMin = value.cropZMin; cropZMax = value.cropZMax
    }

    private static func measurementScale(for splatURL: URL) -> Float {
        let transformsURL = splatURL.deletingLastPathComponent().appendingPathComponent("transforms.json")
        guard let data = try? Data(contentsOf: transformsURL), let dataset = try? JSONDecoder().decode(MeasurementTransforms.self, from: data) else { return 1 }
        let positions = dataset.frames.compactMap { frame -> SIMD3<Float>? in
            let matrix = frame.transformMatrix
            guard matrix.count >= 3, matrix[0].count >= 4, matrix[1].count >= 4, matrix[2].count >= 4 else { return nil }
            let position = SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return nil }
            return position
        }
        return SplatSceneNormalization(cameraPositions: positions).metersPerSceneUnit
    }
}
