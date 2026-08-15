import Foundation

/// Storage admission for Mesh/model delivery. Conversion can temporarily hold the source,
/// an OBJ bridge, a partial output, and the finalized share file at the same time, so the UI
/// must fail before conversion rather than discovering a full disk halfway through an export.
enum MeshExportAdmission {
    enum AdmissionError: LocalizedError, Equatable {
        case sourceMissing
        case sourceSizeUnavailable
        case insufficientStorage(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "Meshの書き出し元が見つかりません。"
            case .sourceSizeUnavailable:
                return "Meshデータのサイズを確認できないため、書き出しを開始できません。"
            case .insufficientStorage(let required, let available):
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return "空き容量が不足しています。安全なMesh書き出しには約\(formatter.string(fromByteCount: required))必要ですが、現在は約\(formatter.string(fromByteCount: available))です。"
            }
        }
    }

    private static let safetyReserveBytes: Int64 = 128 * 1_024 * 1_024

    @discardableResult
    static func preflight(
        sourceURL: URL,
        format: MeshExportService.Format,
        availableCapacityOverride: Int64? = nil
    ) throws -> URL {
        guard sourceURL.isFileURL, FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AdmissionError.sourceMissing
        }
        let sourceBytes = try fileSize(at: sourceURL)
        let required = estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: sourceURL.pathExtension.lowercased(),
            format: format
        )
        let available = availableCapacityOverride.map { max(0, $0) }
            ?? availableCapacity(at: sourceURL.deletingLastPathComponent())
        if let available, available < required {
            throw AdmissionError.insufficientStorage(required: required, available: available)
        }
        return sourceURL
    }

    /// Conservative disk estimate for the atomic pipeline. Exact-format passthrough only needs
    /// one share copy. Other formats may need an OBJ bridge plus partial/final conversion output.
    static func estimatedRequiredFreeBytes(
        sourceBytes: Int64,
        sourceExtension: String,
        format: MeshExportService.Format
    ) -> Int64 {
        let source = max(0, sourceBytes)
        let multiplier: Int64
        if sourceExtension.lowercased() == format.rawValue {
            multiplier = 1
        } else {
            switch format {
            case .ply, .las:
                multiplier = 4
            case .fbx, .obj, .glb, .usdz, .stl:
                multiplier = 3
            }
        }
        return saturatingAdd(saturatingMultiply(source, by: multiplier), safetyReserveBytes)
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
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
