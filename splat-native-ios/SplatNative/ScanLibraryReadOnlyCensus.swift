import Foundation

enum ScanLibraryReadOnlyCensus {
    struct Result {
        let projects: [ScanProjectSummary]
        let unknownCount: Int
        let scanFailed: Bool
    }

    static func inspect(rootURL: URL, fileManager: FileManager = .default) -> Result {
        guard let rootValues = try? rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              rootValues.isDirectory == true, rootValues.isSymbolicLink != true,
              let entries = try? fileManager.contentsOfDirectory(
                  at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                  options: []
              ) else {
            return Result(projects: [], unknownCount: 0, scanFailed: true)
        }
        var known: [ScanProjectSummary] = []
        var unknown = 0
        let decoder = JSONDecoder()
        for url in entries where url.pathExtension == ScanProjectStore.projectExtension {
            guard let attributes = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  attributes.isDirectory == true, attributes.isSymbolicLink != true else {
                unknown += 1
                continue
            }
            let baseName = url.deletingPathExtension().lastPathComponent
            var verified: ScanProjectManifest?
            for name in [ScanProjectStore.manifestFileName, ScanProjectStore.manifestBackupFileName] {
                let candidate = url.appendingPathComponent(name)
                guard let data = try? BoundedFileReader.read(candidate, maximumBytes: 1024 * 1024),
                      let manifest = try? decoder.decode(ScanProjectManifest.self, from: data),
                      manifest.schemaVersion == ScanProjectManifest.currentSchemaVersion,
                      manifest.id == baseName else { continue }
                verified = manifest
                break
            }
            guard let manifest = verified else {
                unknown += 1
                continue
            }
            known.append(ScanProjectSummary(
                manifest: manifest, projectURL: url, storageBytes: fileSizeEstimate(url, fileManager: fileManager)
            ))
        }
        return Result(
            projects: known.sorted { $0.manifest.updatedAt > $1.manifest.updatedAt },
            unknownCount: unknown, scanFailed: false
        )
    }

    private static func fileSizeEstimate(_ url: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let entry as URL in enumerator {
            guard let values = try? entry.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let bytes = Int64(max(0, values.fileSize ?? 0))
            let (next, overflow) = total.addingReportingOverflow(bytes)
            if overflow { return Int64.max }
            total = next
        }
        return total
    }
}
