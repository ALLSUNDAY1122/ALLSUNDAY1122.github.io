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
            case .untrustedSource:
                return "完成確認できていない3Dデータは書き出せません。再生成または保存済みスキャンから開き直してください。"
            case .sourceSizeUnavailable:
                return "3Dデータのサイズを確認できないため、書き出しを開始できません。"
            case .insufficientStorage(let required, let available):
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let requiredText = formatter.string(fromByteCount: required)
                let availableText = formatter.string(fromByteCount: available)
                return "空き容量が不足しています。安全な書き出しには約\(requiredText)必要ですが、現在は約\(availableText)です。"
            }
        }
    }

    private static let safetyReserveBytes: Int64 = 128 * 1_024 * 1_024

    /// Export is admitted only when the source matches the project store's atomic completion
    /// evidence. Record alignment or a `.finished` manifest by itself is not enough because an
    /// interrupted writer can still leave a whole number of 32-byte records behind.
    static func preflight(sourceURL: URL, kind: Kind) throws -> URL {
        let trustedURL: URL
        do {
            trustedURL = try SplatCompletionVerifier.verify(sourceURL: sourceURL)
        } catch {
            throw AdmissionError.untrustedSource
        }

        let projectURL = trustedURL.deletingLastPathComponent()
        let sourceBytes = try fileSize(at: trustedURL)
        let required = estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: kind)
        if let available = availableCapacity(at: projectURL), available < required {
            throw AdmissionError.insufficientStorage(required: required, available: available)
        }
        return trustedURL
    }

    /// Includes temporary-output headroom because export services write `.partial` files
    /// and only replace the final file after validation succeeds.
    static func estimatedRequiredFreeBytes(sourceBytes: Int64, kind: Kind) -> Int64 {
        let source = max(0, sourceBytes)
        let outputEstimate: Int64

        switch kind {
        case .ply:
            // Binary PLY carries more attributes per Gaussian than the compact 32-byte .splat record.
            outputEstimate = saturatingMultiply(source, by: 3)
        case .spz:
            // SPZ is compressed, but reserve at least one source-sized working file.
            outputEstimate = max(source, 32 * 1_024 * 1_024)
        case .video(let width, let height, let framesPerSecond, let duration):
            let pixelsPerSecond = Double(max(1, width))
                * Double(max(1, height))
                * Double(max(1, framesPerSecond))
            let estimatedBitrate = max(2_000_000, pixelsPerSecond * 0.12)
            let estimatedBytes = estimatedBitrate * max(1, duration) / 8
            outputEstimate = Int64(min(Double(Int64.max), estimatedBytes.rounded(.up)))
        }

        return saturatingAdd(outputEstimate, safetyReserveBytes)
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw AdmissionError.sourceSizeUnavailable
        }
        return size.int64Value
    }

    private static func availableCapacity(at url: URL) -> Int64? {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }

        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
           let freeSize = attributes[.systemFreeSize] as? NSNumber {
            return freeSize.int64Value
        }
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
