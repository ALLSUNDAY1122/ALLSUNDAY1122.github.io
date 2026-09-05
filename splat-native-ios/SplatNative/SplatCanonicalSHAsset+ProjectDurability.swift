import Foundation
import Msplat

extension SplatCanonicalSHAsset {
    static let manifestOutputKeyPrefix = "splatSH3Canonical."

    enum DurabilityError: LocalizedError {
        case lossyFingerprintCollision

        var errorDescription: String? {
            switch self {
            case .lossyFingerprintCollision:
                return "同じlegacy .splat識別子に異なるSH3内容が検出されたため、安全のため再生成結果を確定しませんでした。"
            }
        }
    }

    /// Persists SH3 without ever overwriting a different canonical payload that happens to share
    /// the same legacy `.splat` fingerprint. Because legacy `.splat` excludes SH1-3, two trainer
    /// generations can theoretically have identical `.splat` bytes but different higher-order SH.
    /// In that ambiguous case we reject the new pending result instead of corrupting recovery pairing.
    static func persistCollisionSafe(
        from trainer: Msplat.GaussianTrainer,
        legacySplatURL: URL,
        expectedPointCount: Int
    ) throws -> Asset {
        let targetURL = try canonicalURL(forLegacySplat: legacySplatURL)
        let temporaryURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent(".\(targetURL.lastPathComponent).\(UUID().uuidString).candidate.ply")
        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            trainer.exportPly(to: temporaryURL.path)
            return try installCollisionSafeTemporaryPLY(
                temporaryURL,
                targetURL: targetURL,
                expectedPointCount: expectedPointCount
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    /// Internal seam used by synthetic tests to exercise collision behavior without allocating a trainer.
    static func installCollisionSafeTemporaryPLY(
        _ temporaryURL: URL,
        targetURL: URL,
        expectedPointCount: Int
    ) throws -> Asset {
        let candidate = try inspectPLY(temporaryURL)
        guard candidate.pointCount == expectedPointCount else {
            throw CanonicalError.pointCountMismatch(
                expected: expectedPointCount,
                actual: candidate.pointCount
            )
        }
        guard candidate.shDegree == requiredSHDegree else {
            throw CanonicalError.shDegreeMismatch(
                expected: requiredSHDegree,
                actual: candidate.shDegree
            )
        }

        if FileManager.default.fileExists(atPath: targetURL.path) {
            let existing = try inspectPLY(targetURL)
            guard existing.pointCount == expectedPointCount,
                  existing.shDegree == requiredSHDegree,
                  try SplatExportService.sha256Hex(fileURL: targetURL) ==
                    SplatExportService.sha256Hex(fileURL: temporaryURL) else {
                throw DurabilityError.lossyFingerprintCollision
            }
            try? FileManager.default.removeItem(at: temporaryURL)
            return Asset(url: targetURL, descriptor: existing)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
        return Asset(url: targetURL, descriptor: candidate)
    }

    /// Registers a canonical SH asset as a durable project output before reconstruction completion.
    ///
    /// Keys are content-addressed rather than singular so a failed reprocess cannot evict the canonical
    /// asset belonging to the previously committed `.splat`. `ScanProjectStore.clearRawData()` already
    /// preserves every `manifest.outputs` value, so both the current and recovery candidate remain safe.
    @discardableResult
    static func registerDurableProjectOutput(
        _ asset: Asset,
        legacySplatURL: URL,
        store: ScanProjectStore = ScanProjectStore()
    ) throws -> ScanProjectManifest {
        let projectURL = legacySplatURL.deletingLastPathComponent()
        let key = manifestOutputKeyPrefix + asset.url.deletingPathExtension().lastPathComponent
        return try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.outputs[key] = asset.url.lastPathComponent
        }
    }
}
