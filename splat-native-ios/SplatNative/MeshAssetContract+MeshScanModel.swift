import Foundation
import Darwin

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
        // Also reject aliases before opening for write: FileHandle follows symlinks, so accepting
        // one here could synchronize and then publish a contract for bytes outside the scan's
        // immutable asset generation rather than the result path the viewer actually selected.
        let values = try descriptor.fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産が通常ファイルではないため、書き出し情報を更新できません"]
            )
        }
        let assetHandle = try FileHandle(forWritingTo: descriptor.fileURL)
        defer { try? assetHandle.close() }

        // Capture identity from the already-open descriptor. Reading attributes from the path here
        // would only compare the path with itself and would miss a rename/symlink swap after open.
        var openedStat = stat()
        guard fstat(assetHandle.fileDescriptor, &openedStat) == 0 else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産の公開準備中にファイル識別情報を確認できません"]
            )
        }

        try assetHandle.synchronize()

        // Revalidate the currently named path after synchronization. The durable sidecar may only
        // describe the same inode/device generation that was actually synchronized above.
        let postValues = try descriptor.fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        let postAttributes = try FileManager.default.attributesOfItem(atPath: descriptor.fileURL.path)
        let postFileNumber = postAttributes[.systemFileNumber] as? NSNumber
        let postSystemNumber = postAttributes[.systemNumber] as? NSNumber
        guard postValues.isRegularFile == true,
              postValues.isSymbolicLink != true,
              postFileNumber?.uint64Value == UInt64(openedStat.st_ino),
              postSystemNumber?.uint64Value == UInt64(openedStat.st_dev) else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産が公開準備中に差し替えられたため、書き出し情報を更新しません"]
            )
        }

        return try MeshAssetContract.writeSidecar(for: descriptor)
    }
}
