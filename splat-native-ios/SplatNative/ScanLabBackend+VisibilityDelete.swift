@preconcurrency import Supabase

private struct ScanLabHiddenStatusUpdate: Encodable {
    let status: String
}

extension ScanLabBackend {
    func deleteVisibilityLocked(_ scan: ScanLabOwnerScan) async throws {
        if scan.status == "published" {
            try await client
                .from("scanlab_scans")
                .update(ScanLabHiddenStatusUpdate(status: "hidden"))
                .eq("id", value: scan.id)
                .execute()
        }

        let folder = scan.assetPath.split(separator: "/").dropLast().joined(separator: "/")
        var paths = [scan.assetPath]
        if !folder.isEmpty {
            paths.append("\(folder)/manifest.json")
        }
        if let previewPath = scan.previewPath {
            paths.append(previewPath)
        }
        var uniquePaths: [String] = []
        for path in paths where !uniquePaths.contains(path) {
            uniquePaths.append(path)
        }

        if !uniquePaths.isEmpty {
            try await client.storage.from("scanlab-assets").remove(paths: uniquePaths)
        }

        try await client
            .from("scanlab_scans")
            .delete()
            .eq("id", value: scan.id)
            .execute()

        await loadOwnerScans()
        await loadPublicScans()
    }
}
