import Foundation

public struct Lane2LegacyRecoverySliceBudget: Equatable, Sendable {
    public static let defaultProjectsPerLaunch = 64
    public static let minimumProjectsPerLaunch = 8
    public static let maximumProjectsPerLaunch = 256

    public let projectsPerLaunch: Int

    public init(projectsPerLaunch: Int = Self.defaultProjectsPerLaunch) {
        self.projectsPerLaunch = min(
            max(projectsPerLaunch, Self.minimumProjectsPerLaunch),
            Self.maximumProjectsPerLaunch
        )
    }

    public func selectedCount(available: Int) -> Int {
        min(max(available, 0), projectsPerLaunch)
    }

    public func hasMore(availableWithSentinel: Int) -> Bool {
        max(availableWithSentinel, 0) > projectsPerLaunch
    }

    public func launchCount(forProjectCount count: Int) -> Int {
        let count = max(count, 0)
        guard count > 0 else { return 0 }
        return (count + projectsPerLaunch - 1) / projectsPerLaunch
    }

    /// The bounded scanner performs one root fetch (limit N+1), then one Asset and one Stem fetch
    /// for the selected slice. This is a structural call bound, not observed SQLite query count.
    public var logicalFetchUpperBoundPerLaunch: Int { 3 }
}

public struct Lane2LegacyRecoverySliceState: Sendable {
    public let rootURL: URL
    public let recoveryDirectoryName: String

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery") {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
    }

    public func ensureLayout() throws {
        try FileManager.default.createDirectory(
            at: ownershipDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    public var isActive: Bool {
        FileManager.default.fileExists(atPath: activeMarkerURL.path)
    }

    /// Written before the legacy-complete compatibility marker is set. Canonical AW24 opening
    /// always re-enters bounded preparation while this marker exists, even though the old AW22
    /// marker is intentionally set to suppress the unbounded fallback scanner.
    public func activate() throws {
        try ensureLayout()
        guard !isActive else { return }
        try Data("L2-AW24 bounded legacy recovery active\n".utf8)
            .write(to: activeMarkerURL, options: [.atomic])
    }

    public func finish() throws {
        guard isActive else { return }
        try FileManager.default.removeItem(at: activeMarkerURL)
    }

    private var ownershipDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("DeleteOwnership", isDirectory: true)
    }

    private var activeMarkerURL: URL {
        ownershipDirectoryURL.appendingPathComponent(
            ".legacy-bounded-v2-active",
            isDirectory: false
        )
    }
}
