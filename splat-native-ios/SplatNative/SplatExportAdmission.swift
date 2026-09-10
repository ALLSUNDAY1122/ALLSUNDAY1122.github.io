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

    private struct CanonicalInspection {
        let candidateExists: Bool
        let completeAsset: SplatCanonicalSHAsset.Asset?
    }

    private static let safetyReserveBytes: Int64 = 128 * 1_024 * 1_024

    static func preflight(sourceURL: URL, kind: Kind, availableCapacityOverride: Int64? = nil) throws -> URL {
        let verification: SplatCompletionVerifier.Verification
        do { verification = try SplatCompletionVerifier.verifyWithDigest(sourceURL: sourceURL) }
        catch { throw AdmissionError.untrustedSource }
        let trustedURL = verification.url

        _ = SplatViewerEditStore.load(sourceURL: trustedURL)

        let projectURL = trustedURL.deletingLastPathComponent()
        let sourceBytes = try fileSize(at: trustedURL)
        let pointCount = Int(sourceBytes / 32)

        // Completion verification has just hashed the full result. Reuse that trusted SHA-256 to
        // derive the content-addressed canonical path instead of immediately scanning the same large
        // `.splat` a second time. Schema and binary-payload checks below remain fail-closed.
        let canonicalInspection = inspectCanonicalOnce(
            sourceURL: trustedURL,
            verifiedDigest: verification.sha256,
            expectedPointCount: pointCount
        )
        // Older SH0 projects legitimately have no canonical file. If the canonical path does exist,
        // any malformed schema, mismatched point count/SH degree, or truncated vertex payload means
        // the high-quality generation is damaged and export must fail closed rather than silently
        // producing a lower-fidelity result from the legacy `.splat`.
        if canonicalInspection.candidateExists && canonicalInspection.completeAsset == nil {
            throw AdmissionError.untrustedSource
        }
        let canonical = canonicalInspection.completeAsset

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

    private static func inspectCanonicalOnce(
        sourceURL: URL,
        verifiedDigest: String,
        expectedPointCount: Int
    ) -> CanonicalInspection {
        guard let canonicalURL = try? SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: sourceURL,
            verifiedDigest: verifiedDigest
        ) else {
            return CanonicalInspection(candidateExists: false, completeAsset: nil)
        }
        guard FileManager.default.fileExists(atPath: canonicalURL.path) else {
            return CanonicalInspection(candidateExists: false, completeAsset: nil)
        }
        guard let descriptor = try? SplatCanonicalSHAsset.inspectPLY(canonicalURL),
              descriptor.shDegree == SplatCanonicalSHAsset.requiredSHDegree,
              descriptor.pointCount == expectedPointCount else {
            return CanonicalInspection(candidateExists: true, completeAsset: nil)
        }
        guard SplatCanonicalSHAsset.hasCompleteVertexPayload(
            at: canonicalURL,
            expectedPointCount: expectedPointCount
        ) else {
            return CanonicalInspection(candidateExists: true, completeAsset: nil)
        }
        return CanonicalInspection(
            candidateExists: true,
            completeAsset: SplatCanonicalSHAsset.Asset(url: canonicalURL, descriptor: descriptor)
        )
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
