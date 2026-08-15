import Foundation

enum MeshAssetFormat: String, Codable, Sendable {
    case obj
    case usdz
}

enum MeshAssetSource: String, Codable, Sendable {
    case lidarSceneReconstruction
    case lidarRGBTextureBake
    case photogrammetry
    case visualFeatureFallback
    case rawReprocess
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

    init(
        fileURL: URL,
        format: MeshAssetFormat,
        source: MeshAssetSource,
        hasMetricScale: Bool,
        isTextured: Bool,
        rawProjectURL: URL?
    ) {
        self.schemaVersion = 1
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
    static func descriptor(
        for url: URL,
        source requestedSource: MeshAssetSource = .unknown
    ) -> MeshAssetDescriptor? {
        let ext = url.pathExtension.lowercased()
        let format: MeshAssetFormat
        switch ext {
        case "obj":
            format = .obj
        case "usdz":
            format = .usdz
        default:
            return nil
        }

        let source = requestedSource == .unknown ? inferSource(url: url) : requestedSource
        let metric = hasMetricScale(format: format, source: source)
        let parent = url.deletingLastPathComponent()
        let rawProjectURL = parent.pathExtension == "meshproject" ? parent : nil
        return MeshAssetDescriptor(
            fileURL: url,
            format: format,
            source: source,
            hasMetricScale: metric,
            isTextured: isTextured(url: url, format: format, source: source),
            rawProjectURL: rawProjectURL
        )
    }

    static func writeSidecar(for descriptor: MeshAssetDescriptor) throws -> URL {
        let sidecarURL = descriptor.fileURL
            .deletingPathExtension()
            .appendingPathExtension("mesh-asset.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(descriptor).write(to: sidecarURL, options: .atomic)
        return sidecarURL
    }

    private static func isTextured(url: URL, format: MeshAssetFormat, source: MeshAssetSource) -> Bool {
        if format == .usdz { return true }
        if source == .lidarRGBTextureBake { return true }
        return url.lastPathComponent.lowercased().contains("textured")
    }

    private static func hasMetricScale(format: MeshAssetFormat, source: MeshAssetSource) -> Bool {
        guard format == .obj else { return false }
        switch source {
        case .lidarSceneReconstruction, .lidarRGBTextureBake, .visualFeatureFallback, .simplified:
            return true
        case .photogrammetry, .rawReprocess, .unknown:
            return false
        }
    }

    private static func inferSource(url: URL) -> MeshAssetSource {
        let name = url.lastPathComponent.lowercased()
        if name == "mesh-textured.obj" || name.contains("rgb-textured") { return .lidarRGBTextureBake }
        if name.contains("visual-mesh") { return .visualFeatureFallback }
        if name.contains("reprocessed") { return .rawReprocess }
        if name.contains("simplified") { return .simplified }
        if url.pathExtension.lowercased() == "usdz" { return .photogrammetry }
        if name == "mesh.obj" || name.contains("cropped") { return .lidarSceneReconstruction }
        return .unknown
    }
}

extension MeshScanModel {
    var exporterMeshAsset: MeshAssetDescriptor? {
        guard let resultURL else { return nil }
        return MeshAssetContract.descriptor(for: resultURL)
    }

    var currentMeshHasMetricScale: Bool {
        exporterMeshAsset?.hasMetricScale ?? false
    }

    @discardableResult
    func persistExporterMeshAssetContract() throws -> URL? {
        guard let descriptor = exporterMeshAsset else { return nil }
        return try MeshAssetContract.writeSidecar(for: descriptor)
    }
}
