import Foundation

enum SplatExportAdmission {
    enum Kind: Equatable, Sendable {
        case ply
        case spz
        case video(width: Int, height: Int, framesPerSecond: Int, duration: TimeInterval)
    }

    enum AdmissionError: LocalizedError {
        case untrustedSource
        case sourceSizeUnavailable
        case insufficientStorage(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .untrustedSource: return "完成確認できていない3Dデータは書き出せません。再生成または保存済みスキャンから開き直してください。"
            case .sourceSizeUnavailable: return "3Dデータのサイズを確認できないため、書き出しを開始できません。"
            case .insufficientStorage(let required, let available):
                let formatter = ByteCountFormatter(); formatter.countStyle = .file
                return "空き容量が不足しています。安全な書き出しには約\(formatter.string(fromByteCount: required))必要ですが、現在は約\(formatter.string(fromByteCount: available))です。"
            }
        }
    }

    private static let safetyReserveBytes: Int64 = 128 * 1_024 * 1_024

    static func preflight(sourceURL: URL, kind: Kind, availableCapacityOverride: Int64? = nil) throws -> URL {
        let trustedURL: URL
        do { trustedURL = try SplatCompletionVerifier.verify(sourceURL: sourceURL) }
        catch { throw AdmissionError.untrustedSource }

        _ = SplatViewerEditStore.load(sourceURL: trustedURL)

        let projectURL = trustedURL.deletingLastPathComponent()
        let sourceBytes = try fileSize(at: trustedURL)
        let pointCount = Int(sourceBytes / 32)

        // `existingAsset` historically validates the PLY schema but not whether every declared
        // binary vertex is present. If a canonical SH3 file has a valid header but is truncated,
        // do not let export silently consume it. A complete canonical asset remains preferred;
        // scans with no canonical asset at all retain legacy `.splat` compatibility.
        let schemaValidCanonical = SplatCanonicalSHAsset.existingAsset(
            forLegacySplat: trustedURL,
            expectedPointCount: pointCount
        )
        let canonical = SplatCanonicalSHAsset.existingCompleteAsset(
            forLegacySplat: trustedURL,
            expectedPointCount: pointCount
        )
        if schemaValidCanonical != nil, canonical == nil {
            throw AdmissionError.untrustedSource
        }

        let canonicalBytes = canonical.flatMap { try? fileSize(at: $0.url) }
        let required = estimatedRequiredFreeBytes(sourceBytes: sourceBytes, canonicalAssetBytes: canonicalBytes, kind: kind)
        let available = availableCapacityOverride.map { max(0, $0) } ?? availableCapacity(at: projectURL)
        if let available, available < required { throw AdmissionError.insufficientStorage(required: required, available: available) }
        return trustedURL
    }

    static func estimatedRequiredFreeBytes(sourceBytes: Int64, canonicalAssetBytes: Int64? = nil, kind: Kind) -> Int64 {
        let legacySource = max(0, sourceBytes)
        let canonical = max(0, canonicalAssetBytes ?? 0)
        let effectiveSource = max(legacySource, canonical)
        let outputEstimate: Int64
        switch kind {
        case .ply:
            outputEstimate = canonical > 0 ? canonical : saturatingMultiply(legacySource, by: 3)
        case .spz:
            outputEstimate = max(effectiveSource, 32 * 1_024 * 1_024)
        case .video(let width, let height, let framesPerSecond, let duration):
            let pixelsPerSecond = Double(max(1, width)) * Double(max(1, height)) * Double(max(1, framesPerSecond))
            let estimatedBitrate = max(2_000_000, pixelsPerSecond * 0.12)
            let videoBytes = Int64(min(Double(Int64.max), (estimatedBitrate * max(1, duration) / 8).rounded(.up)))
            outputEstimate = saturatingAdd(effectiveSource, videoBytes)
        }
        return saturatingAdd(outputEstimate, safetyReserveBytes)
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw AdmissionError.sourceSizeUnavailable }
        return size.int64Value
    }

    private static func availableCapacity(at url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]), let capacity = values.volumeAvailableCapacityForImportantUsage { return capacity }
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: url.path), let freeSize = attributes[.systemFreeSize] as? NSNumber { return freeSize.int64Value }
        return nil
    }

    private static func saturatingMultiply(_ value: Int64, by multiplier: Int64) -> Int64 {
        guard value > 0, multiplier > 0 else { return 0 }
        if value > Int64.max / multiplier { return Int64.max }
        return value * multiplier
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        if lhs > Int64.max - rhs { return Int64.max }
        return lhs + rhs
    }
}