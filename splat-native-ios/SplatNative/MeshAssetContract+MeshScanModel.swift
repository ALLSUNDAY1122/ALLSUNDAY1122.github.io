import Foundation

extension MeshScanModel {
    // Keep this path metadata-only: SceneKit decoding belongs in completion/export admission,
    // not this MainActor metadata accessor.
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

        // The sidecar is the durable contract that tells downstream export/share code which
        // generation of the Mesh asset is safe to expose. Do not publish that contract until the
        // referenced OBJ/USDZ itself has crossed a durability boundary; otherwise a crash can
        // leave a durable descriptor pointing at asset bytes that never reached stable storage.
        let assetHandle = try FileHandle(forWritingTo: descriptor.fileURL)
        defer { try? assetHandle.close() }
        try assetHandle.synchronize()

        return try MeshAssetContract.writeSidecar(for: descriptor)
    }
}
