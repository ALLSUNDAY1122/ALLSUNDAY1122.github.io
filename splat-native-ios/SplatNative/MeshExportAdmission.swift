import Darwin
import Foundation
import SceneKit

/// Storage admission for Mesh/model delivery. Conversion can temporarily hold the source,
/// an OBJ bridge, a partial output, and the finalized share file at the same time, so the UI
/// must fail before conversion rather than discovering a full disk halfway through an export.
enum MeshExportAdmission {
    enum AdmissionError: LocalizedError, Equatable {
        case sourceMissing
        case unsafeSource
        case sourceSizeUnavailable
        case invalidGeometry
        case storageCapacityUnavailable
        case insufficientStorage(required: Int64, available: Int64)

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "Meshの書き出し元が見つかりません。"
            case .unsafeSource:
                return "Meshの書き出し元が安全な通常ファイルではありません。保存済みスキャンから開き直してください。"
            case .sourceSizeUnavailable:
                return "Meshデータのサイズを確認できないため、書き出しを開始できません。"
            case .invalidGeometry:
                return "Meshの生成結果に有効な面形状を確認できないため、書き出しを開始できません。再生成してください。"
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
        if let sourceValues = try? sourceURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
           sourceValues.isSymbolicLink == true {
            throw AdmissionError.unsafeSource
        }

        let sourceBytes = try fileSize(at: sourceURL)
        let sourceExtension = sourceURL.pathExtension.lowercased()

        if sourceExtension == "usdz" {
            guard let scene = try? SCNScene(url: sourceURL, options: nil),
                  MeshRawSceneValidator.containsGeometry(scene) else {
                throw AdmissionError.invalidGeometry
            }
        }

        var required = estimatedRequiredFreeBytes(
            sourceBytes: sourceBytes,
            sourceExtension: sourceExtension,
            format: format
        )

        if sourceExtension == "obj" {
            switch format {
            case .fbx, .obj, .glb, .usdz, .stl:
                let companionBytes = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: sourceURL)
                required = saturatingAdd(required, companionBytes)
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

    /// Read source size from one no-follow descriptor and verify that the named path still refers
    /// to the same generation. Export admission must not size one file and later approve a swapped
    /// alias/replacement with different resource requirements.
    private static func fileSize(at url: URL) throws -> Int64 {
        guard url.isFileURL,
              url.baseURL == nil,
              url.host == nil,
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.query == nil,
              url.fragment == nil else {
            throw AdmissionError.unsafeSource
        }
        let path = url.path
        let descriptor = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw AdmissionError.unsafeSource }
        defer { close(descriptor) }

        var opened = stat()
        guard fstat(descriptor, &opened) == 0,
              (opened.st_mode & S_IFMT) == S_IFREG,
              opened.st_nlink == 1,
              opened.st_size > 0 else {
            throw AdmissionError.sourceSizeUnavailable
        }

        var named = stat()
        guard lstat(path, &named) == 0,
              (named.st_mode & S_IFMT) == S_IFREG,
              named.st_nlink == 1,
              named.st_dev == opened.st_dev,
              named.st_ino == opened.st_ino,
              named.st_size == opened.st_size,
              named.st_mtimespec.tv_sec == opened.st_mtimespec.tv_sec,
              named.st_mtimespec.tv_nsec == opened.st_mtimespec.tv_nsec,
              named.st_ctimespec.tv_sec == opened.st_ctimespec.tv_sec,
              named.st_ctimespec.tv_nsec == opened.st_ctimespec.tv_nsec else {
            throw AdmissionError.unsafeSource
        }
        return Int64(opened.st_size)
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
