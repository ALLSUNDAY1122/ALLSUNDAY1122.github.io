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

        // Open the asset itself without following a symlink. A resourceValues preflight followed by
        // FileHandle(forWritingTo:) still leaves a path-swap race between validation and open.
        guard descriptor.fileURL.isFileURL,
              descriptor.fileURL.baseURL == nil,
              !descriptor.fileURL.path.isEmpty,
              descriptor.fileURL.path.hasPrefix("/"),
              !descriptor.fileURL.path.contains("\0"),
              descriptor.fileURL.host == nil,
              descriptor.fileURL.user == nil,
              descriptor.fileURL.password == nil,
              descriptor.fileURL.port == nil,
              descriptor.fileURL.query == nil,
              descriptor.fileURL.fragment == nil,
              descriptor.fileURL.standardizedFileURL.path == descriptor.fileURL.path else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産のパスが安全でないため、書き出し情報を更新できません"]
            )
        }

        let descriptorFD = Darwin.open(descriptor.fileURL.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptorFD >= 0 else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産が通常ファイルではないため、書き出し情報を更新できません"]
            )
        }
        defer { Darwin.close(descriptorFD) }

        var openedStat = stat()
        guard fstat(descriptorFD, &openedStat) == 0,
              (openedStat.st_mode & S_IFMT) == S_IFREG,
              openedStat.st_nlink == 1,
              openedStat.st_size > 0 else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産の公開準備中にファイル識別情報を確認できません"]
            )
        }

        // fsync on the already-open descriptor establishes the durability boundary for exactly the
        // inode generation we validated above, without reopening the path through Foundation.
        guard fsync(descriptorFD) == 0 else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産の公開準備中に永続化を確認できません"]
            )
        }

        // Revalidate both the open descriptor and the currently named path after synchronization.
        // This detects same-inode writes that occur while fsync is in flight as well as path swaps;
        // the sidecar may only describe the exact single-link generation that was synchronized.
        var syncedStat = stat()
        var namedStat = stat()
        guard fstat(descriptorFD, &syncedStat) == 0,
              (syncedStat.st_mode & S_IFMT) == S_IFREG,
              syncedStat.st_nlink == 1,
              syncedStat.st_dev == openedStat.st_dev,
              syncedStat.st_ino == openedStat.st_ino,
              syncedStat.st_size == openedStat.st_size,
              syncedStat.st_mtimespec.tv_sec == openedStat.st_mtimespec.tv_sec,
              syncedStat.st_mtimespec.tv_nsec == openedStat.st_mtimespec.tv_nsec,
              syncedStat.st_ctimespec.tv_sec == openedStat.st_ctimespec.tv_sec,
              syncedStat.st_ctimespec.tv_nsec == openedStat.st_ctimespec.tv_nsec,
              lstat(descriptor.fileURL.path, &namedStat) == 0,
              (namedStat.st_mode & S_IFMT) == S_IFREG,
              namedStat.st_nlink == 1,
              namedStat.st_dev == syncedStat.st_dev,
              namedStat.st_ino == syncedStat.st_ino,
              namedStat.st_size == syncedStat.st_size,
              namedStat.st_mtimespec.tv_sec == syncedStat.st_mtimespec.tv_sec,
              namedStat.st_mtimespec.tv_nsec == syncedStat.st_mtimespec.tv_nsec,
              namedStat.st_ctimespec.tv_sec == syncedStat.st_ctimespec.tv_sec,
              namedStat.st_ctimespec.tv_nsec == syncedStat.st_ctimespec.tv_nsec else {
            throw NSError(
                domain: "ScanLab.MeshAssetContract",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Mesh資産が公開準備中に変更されたため、書き出し情報を更新しません"]
            )
        }

        return try MeshAssetContract.writeSidecar(for: descriptor)
    }
}
