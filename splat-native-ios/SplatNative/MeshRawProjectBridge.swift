import Foundation

enum MeshRawSourceKind: String, Codable, Sendable {
    case meshProject
    case splatProject

    var displayName: String {
        switch self {
        case .meshProject: return "Mesh raw"
        case .splatProject: return "Splat raw"
        }
    }
}

struct MeshRawProject: Identifiable, Equatable, Sendable {
    let id: String
    let sourceKind: MeshRawSourceKind
    let sourceProjectURL: URL
    let imagesURL: URL
    let imageCount: Int
    let modifiedAt: Date
    let title: String
}

struct PreparedMeshRawProject: Equatable, Sendable {
    let source: MeshRawProject
    let projectURL: URL
    let imagesURL: URL
}

enum MeshRawProjectBridgeError: LocalizedError {
    case rawUnavailable
    case workspacePreparationFailed

    var errorDescription: String? {
        switch self {
        case .rawUnavailable:
            return "Mesh再処理に必要な保存済みraw画像が見つかりません。"
        case .workspacePreparationFailed:
            return "Splat rawからMesh再処理用の一時プロジェクトを準備できません。"
        }
    }
}

/// Cross-representation bridge owned by HQ/C integration.
///
/// Saved Splat projects remain the source of truth for their raw capture package. When the user asks
/// to generate a Mesh from that raw, we create only a short-lived `.meshproject` container for the
/// derived result. The source images are read in-place through `ScanProjectStore.reprocessRequest` and
/// are never copied into the transient Mesh workspace.
enum MeshRawProjectBridge {
    static let derivedMarkerFileName = ".derived-from-splat.json"

    static func discover(
        appRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> [MeshRawProject] {
        let root = appRootURL ?? defaultAppRoot(fileManager: fileManager)
        var projects: [MeshRawProject] = []

        let meshChildren = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for projectURL in meshChildren where projectURL.pathExtension.lowercased() == MeshProjectStore.projectExtension {
            let imagesURL = projectURL.appendingPathComponent("images", isDirectory: true)
            let imageCount = countImages(in: imagesURL, fileManager: fileManager)
            guard imageCount > 0 else { continue }
            let modifiedAt = (try? projectURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            let projectID = projectURL.deletingPathExtension().lastPathComponent
            projects.append(MeshRawProject(
                id: "mesh:\(projectID)",
                sourceKind: .meshProject,
                sourceProjectURL: projectURL,
                imagesURL: imagesURL,
                imageCount: imageCount,
                modifiedAt: modifiedAt,
                title: projectID
            ))
        }

        let splatStore = ScanProjectStore(rootURL: root, fileManager: fileManager)
        for summary in splatStore.listProjects() {
            guard let request = try? splatStore.reprocessRequest(
                projectURL: summary.projectURL,
                representation: .mesh
            ) else { continue }
            let imageCount = countImages(in: request.imagesURL, fileManager: fileManager)
            guard imageCount > 0 else { continue }
            projects.append(MeshRawProject(
                id: "splat:\(summary.id)",
                sourceKind: .splatProject,
                sourceProjectURL: summary.projectURL,
                imagesURL: request.imagesURL,
                imageCount: imageCount,
                modifiedAt: summary.manifest.updatedAt,
                title: summary.manifest.title
            ))
        }

        return projects.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt { return lhs.id < rhs.id }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    static func prepareWorkingProject(
        for project: MeshRawProject,
        fileManager: FileManager = .default
    ) throws -> PreparedMeshRawProject {
        guard project.imageCount > 0,
              fileManager.fileExists(atPath: project.imagesURL.path) else {
            throw MeshRawProjectBridgeError.rawUnavailable
        }

        if project.sourceKind == .meshProject {
            return PreparedMeshRawProject(
                source: project,
                projectURL: project.sourceProjectURL,
                imagesURL: project.imagesURL
            )
        }

        let root = project.sourceProjectURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let sourceID = project.sourceProjectURL.deletingPathExtension().lastPathComponent
        let safeID = sanitizedFileComponent(sourceID)
        let projectURL = root
            .appendingPathComponent("mesh-from-\(safeID)-\(UUID().uuidString)")
            .appendingPathExtension(MeshProjectStore.projectExtension)

        do {
            try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: false)

            let sourceManifest = DerivedMeshSourceManifest(
                captureMode: "photogrammetry",
                scanSize: "source-splat",
                createdAt: project.modifiedAt
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(sourceManifest).write(
                to: projectURL.appendingPathComponent(MeshProjectStore.sourceManifestFileName),
                options: .atomic
            )

            let marker = DerivedOrigin(
                sourceProjectID: sourceID,
                createdAt: Date()
            )
            try encoder.encode(marker).write(
                to: projectURL.appendingPathComponent(derivedMarkerFileName),
                options: .atomic
            )

            return PreparedMeshRawProject(
                source: project,
                projectURL: projectURL,
                imagesURL: project.imagesURL
            )
        } catch {
            try? fileManager.removeItem(at: projectURL)
            throw MeshRawProjectBridgeError.workspacePreparationFailed
        }
    }

    static func cleanupDerivedWorkingProject(
        containing resultURL: URL,
        fileManager: FileManager = .default
    ) {
        cleanupDerivedWorkingProject(
            projectURL: resultURL.deletingLastPathComponent(),
            fileManager: fileManager
        )
    }

    static func cleanupDerivedWorkingProject(
        projectURL: URL,
        fileManager: FileManager = .default
    ) {
        guard isDerivedWorkingProject(projectURL, fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: projectURL)
    }

    static func isDerivedWorkingProject(
        _ projectURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard projectURL.pathExtension.lowercased() == MeshProjectStore.projectExtension else { return false }
        return fileManager.fileExists(
            atPath: projectURL.appendingPathComponent(derivedMarkerFileName).path
        )
    }

    private static func defaultAppRoot(fileManager: FileManager) -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SplatLab", isDirectory: true)
    }

    private static func countImages(in directory: URL, fileManager: FileManager) -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        let extensions = Set(["jpg", "jpeg", "heic", "png"])
        return files.reduce(into: 0) { count, url in
            guard extensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return
            }
            count += 1
        }
    }

    private static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let result = String(scalars).prefix(48)
        return result.isEmpty ? "splat" : String(result)
    }

    private struct DerivedMeshSourceManifest: Codable {
        let schemaVersion = 1
        let captureMode: String
        let scanSize: String
        let createdAt: Date
    }

    private struct DerivedOrigin: Codable {
        let schemaVersion = 1
        let sourceProjectID: String
        let createdAt: Date
    }
}
