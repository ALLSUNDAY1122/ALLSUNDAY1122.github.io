import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public enum LibraryMaintenanceProjectionFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case duplicateProject(ProjectID)
}

public struct LibraryMaintenanceProject: Hashable, Sendable {
    public let projectID: ProjectID
    public let sourceAssetID: AssetID
    public let sourceRelativePath: String
    public let stemRelativePaths: [String]

    public init(
        projectID: ProjectID,
        sourceAssetID: AssetID,
        sourceRelativePath: String,
        stemRelativePaths: [String]
    ) throws {
        try Self.validate(relativePath: sourceRelativePath)
        for path in stemRelativePaths {
            try Self.validate(relativePath: path)
        }
        self.projectID = projectID
        self.sourceAssetID = sourceAssetID
        self.sourceRelativePath = sourceRelativePath
        self.stemRelativePaths = stemRelativePaths
    }

    public var artifactRelativePaths: [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(1 + stemRelativePaths.count)
        for path in [sourceRelativePath] + stemRelativePaths where seen.insert(path).inserted {
            result.append(path)
        }
        return result
    }

    private static func validate(relativePath: String) throws {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              !(normalized as NSString).isAbsolutePath else {
            throw LibraryMaintenanceProjectionFailure.invalidRelativePath(relativePath)
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw LibraryMaintenanceProjectionFailure.invalidRelativePath(relativePath)
        }
    }
}

public protocol LibraryMaintenanceProjectProviding: Sendable {
    func listMaintenanceProjects() async throws -> [LibraryMaintenanceProject]
    func listLiveProjectIDs() async throws -> Set<ProjectID>
    func containsLiveProject(projectID: ProjectID) async throws -> Bool
}

public enum LibraryMaintenanceProjectionPolicy {
    public static func validateUniqueProjects(
        _ projects: [LibraryMaintenanceProject]
    ) throws -> [LibraryMaintenanceProject] {
        var seen = Set<ProjectID>()
        for project in projects where !seen.insert(project.projectID).inserted {
            throw LibraryMaintenanceProjectionFailure.duplicateProject(project.projectID)
        }
        return projects
    }

    public static func referencedArtifactPaths(
        in projects: [LibraryMaintenanceProject],
        excluding projectID: ProjectID? = nil
    ) -> Set<String> {
        var result = Set<String>()
        for project in projects where project.projectID != projectID {
            result.formUnion(project.artifactRelativePaths)
        }
        return result
    }

    public static func projectIDs(
        in projects: [LibraryMaintenanceProject]
    ) -> Set<ProjectID> {
        Set(projects.map(\.projectID))
    }
}
