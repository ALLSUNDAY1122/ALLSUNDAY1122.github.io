import Foundation
import Darwin

enum MeshAssetFormat: String, Codable, Sendable {
    case obj
    case usdz
}

enum MeshAssetSource: String, Codable, Sendable {
    case lidarSceneReconstruction
    case lidarDepthFusion
    case lidarRGBTextureBake
    case photogrammetry
    case visualFeatureFallback
    case visualDenseMVS
    case rawReprocess
    case refined
    case trimmed
    case appearanceEdited
    case detailSimplified
    case simplified
    case unknown
}

struct MeshAssetDescriptor: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let fileURL: URL
    let format: MeshAssetFormat
    let source: MeshAssetSource
    let hasMetricScale: Bool
    let linearUnit: String
    let coordinateSpace: String
    let isTextured: Bool
    let rawProjectURL: URL?

    init(fileURL: URL, format: MeshAssetFormat, source: MeshAssetSource, hasMetricScale: Bool, isTextured: Bool, rawProjectURL: URL?) {
        self.schemaVersion = 2
        self.fileURL = fileURL
        self.format = format
        self.source = source
        self.hasMetricScale = hasMetricScale
        self.linearUnit = hasMetricScale ? "meter" : "uncalibrated"
        self.coordinateSpace = hasMetricScale
            ? "ARKit world space; Y-up; right-handed"
            : "RealityKit photogrammetry local space; scale not calibrated to ARKit world"
        self.isTextured = isTextured
        self.rawProjectURL = rawProjectURL
    }
}

enum MeshAssetContract {
    private static let maximumSidecarByteCount: Int64 = 64 * 1024

    static func descriptor(for url: URL, source requestedSource: MeshAssetSource = .unknown) -> MeshAssetDescriptor? {
        let ext = url.pathExtension.lowercased()
        let format: MeshAssetFormat
        switch ext {
        case "obj": format = .obj
        case "usdz": format = .usdz
        default: return nil
        }
        let source = requestedSource == .unknown ? inferSource(url: url) : requestedSource
        let metric = hasMetricScale(format: format, source: source)
        let parent = url.deletingLastPathComponent()
        return MeshAssetDescriptor(
            fileURL: url,
            format: format,
            source: source,
            hasMetricScale: metric,
            isTextured: isTextured(url: url, format: format, source: source),
            rawProjectURL: parent.pathExtension == "meshproject" ? parent : nil
        )
    }

    static func writeSidecar(for descriptor: MeshAssetDescriptor) throws -> URL {
        let sidecarURL = descriptor.fileURL.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        let candidateURL = sidecarURL.deletingLastPathComponent()
            .appendingPathComponent(".\(sidecarURL.lastPathComponent).candidate-\(UUID().uuidString)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let expected = try encoder.encode(descriptor)
        let fileManager = FileManager.default
        var candidateCommitted = false
        defer {
            if !candidateCommitted {
                try? fileManager.removeItem(at: candidateURL)
            }
        }

        if fileManager.fileExists(atPath: sidecarURL.path) {
            let existing = try readExistingSidecarIfSafe(at: sidecarURL)
            if let object = try? JSONSerialization.jsonObject(with: existing) as? [String: Any],
               let version = object["schemaVersion"] as? NSNumber,
               version.intValue > descriptor.schemaVersion {
                throw sidecarError("このMesh資産メタデータは新しいバージョンで作成されています。原本を保護するため更新しません")
            }
        }

        try expected.write(to: candidateURL, options: .atomic)
        let persisted = try readExistingSidecarIfSafe(at: candidateURL)
        guard persisted == expected else {
            throw sidecarError("Mesh資産メタデータの書込み検証に失敗しました")
        }
        let decoded = try JSONDecoder().decode(MeshAssetDescriptor.self, from: persisted)
        guard decoded == descriptor else {
            throw sidecarError("Mesh資産メタデータの復号検証に失敗しました")
        }
        try synchronizeFileBeforePublish(at: candidateURL)

        if fileManager.fileExists(atPath: sidecarURL.path) {
            _ = try fileManager.replaceItemAt(sidecarURL, withItemAt: candidateURL)
        } else {
            try fileManager.moveItem(at: candidateURL, to: sidecarURL)
        }
        candidateCommitted = true

        let published = try readExistingSidecarIfSafe(at: sidecarURL)
        guard published == expected,
              let publishedDescriptor = try? JSONDecoder().decode(MeshAssetDescriptor.self, from: published),
              publishedDescriptor == descriptor else {
            throw sidecarError("Mesh資産メタデータの公開後検証に失敗しました")
        }
        return sidecarURL
    }

    private static func readExistingSidecarIfSafe(at url: URL) throws -> Data {
        do {
            return try BoundedFileReader.read(url, maximumBytes: Int(maximumSidecarByteCount))
        } catch {
            throw sidecarError("既存のMesh資産メタデータを安全に確認できません。原本を保護するため更新しません")
        }
    }

    private static func synchronizeFileBeforePublish(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func sidecarError(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshAssetContract", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func isTextured(url: URL, format: MeshAssetFormat, source: MeshAssetSource) -> Bool {
        if format == .usdz { return true }
        if source == .lidarRGBTextureBake || source == .appearanceEdited { return true }
        let name = url.lastPathComponent.lowercased()
        return name.contains("textured") || name.contains("edited")
    }

    private static func hasMetricScale(format: MeshAssetFormat, source: MeshAssetSource) -> Bool {
        guard format == .obj else { return false }
        switch source {
        case .lidarSceneReconstruction, .lidarDepthFusion, .lidarRGBTextureBake,
             .visualFeatureFallback, .visualDenseMVS, .refined, .trimmed,
             .appearanceEdited, .detailSimplified, .simplified:
            return true
        case .photogrammetry, .rawReprocess, .unknown:
            return false
        }
    }

    private static func inferSource(url: URL) -> MeshAssetSource {
        let name = url.lastPathComponent.lowercased()
        if url.pathExtension.lowercased() == "usdz" {
            return name.contains("reprocessed") ? .rawReprocess : .photogrammetry
        }
        if name.contains("depth-fused") { return .lidarDepthFusion }
        if name.contains("visual-dense-mvs") || name.contains("visual-mesh") || name.hasPrefix("visual-") {
            if name.contains("edited") { return .appearanceEdited }
            if name.contains("trimmed") { return .trimmed }
            if name.contains("textured") { return .lidarRGBTextureBake }
            return name.contains("dense") ? .visualDenseMVS : .visualFeatureFallback
        }
        if name.contains("edited") { return .appearanceEdited }
        if name.contains("textured") || name.contains("rgb-textured") { return .lidarRGBTextureBake }
        if name.contains("detail-simplified") { return .detailSimplified }
        if name.contains("simplified") { return .simplified }
        if name.contains("refined") { return .refined }
        if name.contains("trimmed") || name.contains("cropped") { return .trimmed }
        if name == "mesh.obj" { return .lidarSceneReconstruction }
        return .unknown
    }
}
