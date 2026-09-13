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

    private struct LossyDecode: Decodable {
        let settings: SplatEditSettings
        let validKnownFieldCount: Int

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            var validKnownFieldCount = 0

            func value(_ key: CodingKeys, default defaultValue: Double) -> Double {
                if let decoded = try? values.decode(Double.self, forKey: key) {
                    validKnownFieldCount += 1
                    return decoded
                }
                return defaultValue
            }

            settings = SplatEditSettings(
                exposureEV: value(.exposureEV, default: 0),
                contrast: value(.contrast, default: 1),
                cropXMin: value(.cropXMin, default: 0),
                cropXMax: value(.cropXMax, default: 1),
                cropYMin: value(.cropYMin, default: 0),
                cropYMax: value(.cropYMax, default: 1),
                cropZMin: value(.cropZMin, default: 0),
                cropZMax: value(.cropZMax, default: 1)
            )
            self.validKnownFieldCount = validKnownFieldCount
        }
    }

    static func salvagingPartiallyCorruptJSON(
        _ data: Data,
        minimumValidKnownFieldCount: Int = 1
    ) -> SplatEditSettings? {
        let minimum = min(8, max(1, minimumValidKnownFieldCount))
        guard let decoded = try? JSONDecoder().decode(LossyDecode.self, from: data),
              decoded.validKnownFieldCount >= minimum else {
            return nil
        }
        return decoded.settings.normalized()
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

enum SplatViewerEditStoreError: Error, Equatable {
    case unsafeWriteTarget
}

/// Durable viewer-edit sidecar. The backup is intentionally separate from the scan manifest:
/// viewer edits can be recovered without making the reconstructed asset itself untrusted.
struct SplatViewerEditStore {
    private static let maximumSidecarByteCount: Int64 = 64 * 1024
    private static let strongPartialSalvageFieldCount = 6

    static func primaryURL(for sourceURL: URL) -> URL {
        sourceURL.deletingPathExtension().appendingPathExtension("viewer.json")
    }

    static func backupURL(for sourceURL: URL) -> URL {
        sourceURL.deletingPathExtension().appendingPathExtension("viewer.json.bak")
    }

    static func load(sourceURL: URL, fileManager: FileManager = .default) -> (settings: SplatEditSettings, recoveredFromBackup: Bool)? {
        let decoder = JSONDecoder()
        let primary = primaryURL(for: sourceURL)
        var weakPrimarySalvage: SplatEditSettings?
        if let data = readSettingsDataIfSafe(at: primary, fileManager: fileManager) {
            if let decoded = try? decoder.decode(SplatEditSettings.self, from: data) {
                return (decoded.normalized(), false)
            }
            // Preserve a nearly-intact newer generation when only one or two known fields are type
            // damaged. If corruption is broader, remember any usable primary values but prefer a
            // complete last-known-good backup instead of silently resetting most edits to defaults.
            if let salvaged = SplatEditSettings.salvagingPartiallyCorruptJSON(
                data,
                minimumValidKnownFieldCount: strongPartialSalvageFieldCount
            ) {
                return (salvaged, false)
            }
            weakPrimarySalvage = SplatEditSettings.salvagingPartiallyCorruptJSON(data)
        }

        let backup = backupURL(for: sourceURL)
        if let data = readSettingsDataIfSafe(at: backup, fileManager: fileManager),
           let decoded = try? decoder.decode(SplatEditSettings.self, from: data) {
            // A valid backup remains useful even when the primary node is unsafe. Do not attempt the
            // self-heal through an existing symlink/special node: normal viewer loading must never write
            // outside the scan project merely because the primary sidecar was replaced by an alias.
            if writeDestinationIsSafeOrMissing(at: primary, fileManager: fileManager) {
                try? data.write(to: primary, options: .atomic)
            }
            return (decoded.normalized(), true)
        }

        // No healthy backup exists. Retaining the independently decodable primary values is safer
        // than discarding every user edit, even when the primary was too damaged to outrank a backup.
        if let weakPrimarySalvage {
            return (weakPrimarySalvage, false)
        }
        return nil
    }

    static func save(_ settings: SplatEditSettings, sourceURL: URL, fileManager: FileManager = .default) throws {
        let primary = primaryURL(for: sourceURL)
        let backup = backupURL(for: sourceURL)
        guard writeDestinationIsSafeOrMissing(at: primary, fileManager: fileManager),
              writeDestinationIsSafeOrMissing(at: backup, fileManager: fileManager) else {
            throw SplatViewerEditStoreError.unsafeWriteTarget
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(settings.normalized())

        var preservedPreviousGeneration = false
        if let oldData = readSettingsDataIfSafe(at: primary, fileManager: fileManager),
           (try? decoder.decode(SplatEditSettings.self, from: oldData)) != nil {
            try oldData.write(to: backup, options: .atomic)
            preservedPreviousGeneration = true
        }

        let existingBackupIsValid: Bool
        if let backupData = readSettingsDataIfSafe(at: backup, fileManager: fileManager),
           (try? decoder.decode(SplatEditSettings.self, from: backupData)) != nil {
            existingBackupIsValid = true
        } else {
            existingBackupIsValid = false
        }

        try data.write(to: primary, options: .atomic)

        if !preservedPreviousGeneration && !existingBackupIsValid {
            try data.write(to: backup, options: .atomic)
        }
    }

    private static func writeDestinationIsSafeOrMissing(at url: URL, fileManager: FileManager) -> Bool {
        // `fileExists` follows symlinks and returns false for a dangling alias. Probe the node type
        // first so a broken external link cannot masquerade as a safe missing destination.
        if (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil {
            return false
        }
        guard fileManager.fileExists(atPath: url.path) else { return true }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func readSettingsDataIfSafe(at url: URL, fileManager: FileManager) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value >= 0,
              size.int64Value <= maximumSidecarByteCount else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}

struct SplatSceneNormalization: Equatable, Sendable {
    let translation: SIMD3<Float>
    let scale: Float

    init(cameraPositions: [SIMD3<Float>]) {
        let finitePositions = cameraPositions.filter { position in
            position.x.isFinite && position.y.isFinite && position.z.isFinite
        }
        guard !finitePositions.isEmpty else {
            translation = .zero
            scale = 1
            return
        }

        // Accumulate the centroid in Double with an online mean. A plain SIMD3<Float> sum can
        // overflow even when every camera position and the mathematical mean are finite; that used
        // to collapse measurement scaling to the 1:1 fallback for otherwise valid datasets.
        var mean = SIMD3<Double>.zero
        var sampleCount = 0.0
        for position in finitePositions {
            sampleCount += 1
            let sample = SIMD3<Double>(
                Double(position.x),
                Double(position.y),
                Double(position.z)
            )
            mean += (sample - mean) / sampleCount
        }
        guard mean.x.isFinite, mean.y.isFinite, mean.z.isFinite else {
            translation = .zero
            scale = 1
            return
        }

        let stableTranslation = SIMD3<Float>(Float(mean.x), Float(mean.y), Float(mean.z))
        guard stableTranslation.x.isFinite,
              stableTranslation.y.isFinite,
              stableTranslation.z.isFinite else {
            translation = .zero
            scale = 1
            return
        }

        // Compute the spread before narrowing back to Float. Opposite large-but-finite Float
        // coordinates can have a finite center while their subtraction overflows in Float.
        var maxAbs = 0.0
        for position in finitePositions {
            maxAbs = max(
                maxAbs,
                abs(Double(position.x) - mean.x),
                abs(Double(position.y) - mean.y),
                abs(Double(position.z) - mean.z)
            )
        }
        guard maxAbs.isFinite, maxAbs > 0 else {
            translation = stableTranslation
            scale = 1
            return
        }

        let inverseSpread = 1.0 / maxAbs
        let stableScale = Float(inverseSpread)
        translation = stableTranslation
        scale = stableScale.isFinite && stableScale > 0 ? stableScale : 1
    }

    var metersPerSceneUnit: Float {
        guard scale.isFinite, scale > 0 else { return 1 }
        let value = 1 / scale
        return value.isFinite && value > 0 ? value : 1
    }

    func normalized(_ worldPosition: SIMD3<Float>) -> SIMD3<Float> {
        (worldPosition - translation) * scale
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
    private var persistenceWarningMessage: String?

    private static let saveFailureWarning = "編集内容を保存できませんでした"
    private static let backupRecoveryWarning = "前回の編集設定をバックアップから復元しました"

    var editSettings: SplatEditSettings {
        SplatEditSettings(exposureEV: exposureEV, contrast: contrast, cropXMin: cropXMin, cropXMax: cropXMax, cropYMin: cropYMin, cropYMax: cropYMax, cropZMin: cropZMin, cropZMax: cropZMax).normalized()
    }

    func attach(url: URL) {
        guard sourceURL != url else { return }
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
        let positions = SplatViewerCameraDatasetLoader.cameraPositions(for: splatURL)
        return SplatSceneNormalization(cameraPositions: positions).metersPerSceneUnit
    }
}
