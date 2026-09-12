import Foundation

/// Storage admission for Mesh/model delivery. Conversion can temporarily hold the source,
/// an OBJ bridge, a partial output, and the finalized share file at the same time, so the UI
/// must fail before conversion rather than discovering a full disk halfway through an export.
enum MeshExportAdmission {
    enum AdmissionError: LocalizedError, Equatable {
        case sourceMissing
        case sourceSizeUnavailable
        case storageCapacityUnavailable
        case insufficientStorage(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "Meshの書き出し元が見つかりません。"
            case .sourceSizeUnavailable:
                return "Meshデータのサイズを確認できないため、書き出しを開始できません。"
            case .storageCapacityUnavailable:
                return "端末の空き容量を確認できないため、安全なMesh書き出しを開始できません。"
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
        availableCapacityOverride: Int64? = nil,
        capacityProvider: ((URL) -> Int64?)? = nil
    ) throws -> URL {
        guard sourceURL.isFileURL, FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AdmissionError.sourceMissing
        }
        let sourceBytes = try fileSize(at: sourceURL)
        let sourceExtension = sourceURL.pathExtension.lowercased()
        var required = estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: sourceExtension,
            format: format
        )

        // Assimp/Model I/O scene conversion and exact OBJ delivery may follow every referenced
        // material/texture, so those paths fail closed on missing/unsafe companions. PLY/LAS uses
        // our bounded parser instead: it validates contained, decodable textures and deliberately
        // falls back to geometry-only points when texture metadata is stale or damaged. Do not let
        // the stricter share-bundle scanner block that safe point-cloud fallback before it starts.
        if sourceExtension == "obj" {
            switch format {
            case .fbx, .obj, .glb, .usdz, .stl:
                let companionBytes = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: sourceURL)
                if format == .obj {
                    required = saturatingAdd(required, companionBytes)
                }
            case .ply, .las:
                break
            }
        }

        let capacityURL = sourceURL.deletingLastPathComponent()
        let available: Int64?
        if let availableCapacityOverride {
            available = max(0, availableCapacityOverride)
        } else if let capacityProvider {
            available = capacityProvider(capacityURL).map { max(0, $0) }
        } else {
            available = availableCapacity(at: capacityURL).map { max(0, $0) }
        }
        guard let available else {
            throw AdmissionError.storageCapacityUnavailable
        }
        if available < required {
            throw AdmissionError.insufficientStorage(required: required, available: available)
        }
        return sourceURL
    }

    /// Conservative disk estimate for the atomic pipeline. Exact-format passthrough only needs
    /// one share copy. Direct OBJ point-cloud output can expand a compact indexed OBJ substantially
    /// because each triangle corner becomes a full point record (up to 26 bytes in LAS 1.2 with
    /// RGB), so reserve 12x source bytes. Non-OBJ point-cloud conversion first materializes a text
    /// OBJ bridge and then expands that bridge again into PLY/LAS; compressed/binary inputs such as
    /// GLB can therefore consume substantially more disk than their source size suggests, so that
    /// two-stage path reserves 24x source bytes. Non-OBJ FBX/OBJ/GLB/STL conversion also creates a
    /// temporary text OBJ bridge before writing the final container; reserve 8x source bytes there
    /// instead of the direct-OBJ 3x path. USDZ is exported directly by Model I/O and keeps 3x.
    static func estimatedRequiredFreeBytes(
        sourceBytes: Int64,
        sourceExtension: String,
        format: MeshExportService.Format
    ) -> Int64 {
        let source = max(0, sourceBytes)
        let normalizedExtension = sourceExtension.lowercased()
        let multiplier: Int64
        if normalizedExtension == format.rawValue {
            multiplier = 1
        } else {
            switch format {
            case .ply, .las:
                multiplier = normalizedExtension == "obj" ? 12 : 24
            case .usdz:
                multiplier = 3
            case .fbx, .obj, .glb, .stl:
                multiplier = normalizedExtension == "obj" ? 3 : 8
            }
        }
        return saturatingAdd(saturatingMultiply(source, by: multiplier), safetyReserveBytes)
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.int64Value > 0 else {
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
