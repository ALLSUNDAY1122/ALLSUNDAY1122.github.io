import Foundation
import SceneKit

extension MeshScanModel {
    var exporterMeshAsset: MeshAssetDescriptor? {
        guard let resultURL else { return nil }
        let descriptor = MeshAssetContract.descriptor(for: resultURL)
        guard let descriptor else { return nil }

        // Photogrammetry completion can surface a USDZ path before the model has proven that
        // SceneKit can decode a usable surface. Do not let a syntactically present but corrupt or
        // geometry-empty USDZ escape through export/share metadata. OBJ paths keep their existing
        // admission path, which performs format-specific validation downstream.
        if descriptor.format == .usdz {
            guard let scene = try? SCNScene(url: resultURL, options: nil),
                  MeshRawSceneValidator.containsGeometry(scene) else { return nil }
        }
        return descriptor
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
