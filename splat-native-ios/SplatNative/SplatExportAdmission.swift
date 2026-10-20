import Foundation
import Darwin

enum SplatExportAdmission {
    enum Kind: Equatable, Sendable {
        case ply
        case spz
        case video(width: Int, height: Int, framesPerSecond: Int, duration: TimeInterval)
    }

    struct Result: Equatable, Sendable {
        let verification: SplatCompletionVerifier.Verification

        var trustedURL: URL { verification.url }
        var verifiedDigest: String { verification.sha256 }
    }

    enum AdmissionError: LocalizedError {
        case untrustedSource
        case sourceSizeUnavailable
        case invalidExportConfiguration
        case availableCapacityUnavailable
        case insufficientStorage(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .untrustedSource: return "完成確認できていない3Dデータは書き出せません。再生成または保存済みスキャンから開き直してください。"
            case .sourceSizeUnavailable: return "3Dデータのサイズを確認できないため、書き出しを開始できません。"
            case .invalidExportConfiguration: return "書き出し設定が不正なため、安全な書き出しを開始できません。"
            case .availableCapacityUnavailable: return "端末の空き容量を確認できないため、安全な書き出しを開始できません。"
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
    private static let maximumViewerSidecarByteCount = 64 * 1_024
    private static let maximumVideoDimension = 16_384
    private static let maximumVideoFramesPerSecond = 240
    private static let maximumVideoDuration: TimeInterval = 3_600

    static func preflight(sourceURL: URL, kind: Kind, availableCapacityOverride: Int64? = nil) throws -> URL {
        try preflightResult(sourceURL: sourceURL, kind: kind, availableCapacityOverride: availableCapacityOverride).trustedURL
    }

    static func preflightResult(sourceURL: URL, kind: Kind, availableCapacityOverride: Int64? = nil) throws -> Result {
        try validate(kind: kind)
        let verification: SplatCompletionVerifier.Verification
        do { verification = try SplatCompletionVerifier.verifyWithDigest(sourceURL: sourceURL) }
        catch { throw AdmissionError.untrustedSource }
        let trustedURL = verification.url

        guard viewerPrimarySidecarIsSafeOrMissing(sourceURL: trustedURL) else { throw AdmissionError.untrustedSource }
        _ = SplatViewerEditStore.load(sourceURL: trustedURL)
        guard viewerPrimarySidecarIsSafeOrMissing(sourceURL: trustedURL) else { throw AdmissionError.untrustedSource }

        let projectURL = trustedURL.deletingLastPathComponent()
        let sourceBytes = try fileSize(at: trustedURL)
        let pointCount = Int(sourceBytes / 32)
        let canonicalInspection = inspectCanonicalOnce(sourceURL: trustedURL, verifiedDigest: verification.sha256, expectedPointCount: pointCount)
        if canonicalInspection.candidateExists && canonicalInspection.completeAsset == nil { throw AdmissionError.untrustedSource }
        let canonicalBytes: Int64?
        if let canonical = canonicalInspection.completeAsset {
            canonicalBytes = try fileSize(at: canonical.url)
        } else {
            canonicalBytes = nil
        }
        let required = estimatedRequiredFreeBytes(sourceBytes: sourceBytes, canonicalAssetBytes: canonicalBytes, kind: kind)
        let detectedCapacity = availableCapacityOverride == nil ? availableCapacity(at: projectURL) : nil
        let available = try resolvedAvailableCapacity(override: availableCapacityOverride, detected: detectedCapacity)
        if available < required { throw AdmissionError.insufficientStorage(required: required, available: available) }
        return Result(verification: verification)
    }

    static func resolvedAvailableCapacity(override: Int64?, detected: Int64?) throws -> Int64 {
        if let override { return max(0, override) }
        guard let detected else { throw AdmissionError.availableCapacityUnavailable }
        return max(0, detected)
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
            guard validVideoConfiguration(width: width, height: height, framesPerSecond: framesPerSecond, duration: duration) else { return Int64.max }
            let pixelsPerSecond = Double(width) * Double(height) * Double(framesPerSecond)
            let estimatedBitrate = max(2_000_000, pixelsPerSecond * 0.12)
            let estimatedVideoBytes = estimatedBitrate * duration / 8
            let videoBytes: Int64
            if !estimatedVideoBytes.isFinite || estimatedVideoBytes >= Double(Int64.max) { videoBytes = Int64.max }
            else { videoBytes = Int64(max(0, estimatedVideoBytes).rounded(.up)) }
            outputEstimate = videoBytes
        }
        return saturatingAdd(outputEstimate, safetyReserveBytes)
    }

    private static func validate(kind: Kind) throws {
        guard case .video(let width, let height, let framesPerSecond, let duration) = kind else { return }
        guard validVideoConfiguration(width: width, height: height, framesPerSecond: framesPerSecond, duration: duration) else {
            throw AdmissionError.invalidExportConfiguration
        }
    }

    private static func validVideoConfiguration(width: Int, height: Int, framesPerSecond: Int, duration: TimeInterval) -> Bool {
        width > 0 && width <= maximumVideoDimension &&
        height > 0 && height <= maximumVideoDimension &&
        framesPerSecond > 0 && framesPerSecond <= maximumVideoFramesPerSecond &&
        duration.isFinite && duration > 0 && duration <= maximumVideoDuration
    }

    private static func inspectCanonicalOnce(sourceURL: URL, verifiedDigest: String, expectedPointCount: Int) -> CanonicalInspection {
        guard let canonicalURL = try? SplatCanonicalSHAsset.canonicalURL(forLegacySplat: sourceURL, verifiedDigest: verifiedDigest) else {
            return CanonicalInspection(candidateExists: false, completeAsset: nil)
        }
        guard FileManager.default.fileExists(atPath: canonicalURL.path) else { return CanonicalInspection(candidateExists: false, completeAsset: nil) }
        guard let descriptor = try? SplatCanonicalSHAsset.inspectPLYStrictHeader(canonicalURL),
              descriptor.shDegree == SplatCanonicalSHAsset.requiredSHDegree,
              descriptor.pointCount == expectedPointCount,
              SplatCanonicalSHAsset.hasCompleteVertexPayload(at: canonicalURL, expectedPointCount: expectedPointCount) else {
            return CanonicalInspection(candidateExists: true, completeAsset: nil)
        }
        return CanonicalInspection(candidateExists: true, completeAsset: SplatCanonicalSHAsset.Asset(url: canonicalURL, descriptor: descriptor))
    }

    private static func viewerPrimarySidecarIsSafeOrMissing(sourceURL: URL, fileManager: FileManager = .default) -> Bool {
        let primary = SplatViewerEditStore.primaryURL(for: sourceURL)
        guard fileManager.fileExists(atPath: primary.path) else {
            return (try? fileManager.destinationOfSymbolicLink(atPath: primary.path)) == nil
        }
        do {
            _ = try BoundedFileReader.read(primary, maximumBytes: maximumViewerSidecarByteCount)
            return true
        } catch {
            return false
        }
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        guard url.isFileURL,
              url.baseURL == nil,
              !url.path.isEmpty,
              url.path.hasPrefix("/"),
              !url.path.contains("\0"),
              url.host == nil,
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.query == nil,
              url.fragment == nil,
              url.standardizedFileURL.path == url.path else {
            throw AdmissionError.sourceSizeUnavailable
        }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw AdmissionError.sourceSizeUnavailable }
        defer { Darwin.close(descriptor) }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0,
              (opened.st_mode & S_IFMT) == S_IFREG,
              opened.st_nlink == 1,
              opened.st_size >= 0 else {
            throw AdmissionError.sourceSizeUnavailable
        }
        var named = stat()
        guard lstat(url.path, &named) == 0,
              (named.st_mode & S_IFMT) == S_IFREG,
              named.st_nlink == 1,
              named.st_dev == opened.st_dev,
              named.st_ino == opened.st_ino,
              named.st_size == opened.st_size,
              named.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec,
              named.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              named.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec,
              named.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec else {
            throw AdmissionError.sourceSizeUnavailable
        }
        var finalOpened = stat()
        guard fstat(descriptor, &finalOpened) == 0,
              finalOpened.st_dev == opened.st_dev,
              finalOpened.st_ino == opened.st_ino,
              finalOpened.st_nlink == opened.st_nlink,
              finalOpened.st_size == opened.st_size,
              finalOpened.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec,
              finalOpened.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              finalOpened.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec,
              finalOpened.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec else {
            throw AdmissionError.sourceSizeUnavailable
        }
        return Int64(finalOpened.st_size)
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
