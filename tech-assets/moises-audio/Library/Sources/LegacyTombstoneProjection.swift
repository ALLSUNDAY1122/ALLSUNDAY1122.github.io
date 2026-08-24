import Foundation

public struct Lane2LegacyTombstoneProjectRow: Hashable, Sendable {
    public let projectUUID: UUID
    public let sourceAssetUUID: UUID

    public init(projectUUID: UUID, sourceAssetUUID: UUID) {
        self.projectUUID = projectUUID
        self.sourceAssetUUID = sourceAssetUUID
    }
}

public struct Lane2LegacyTombstoneAssetRow: Hashable, Sendable {
    public let assetUUID: UUID
    public let relativePath: String

    public init(assetUUID: UUID, relativePath: String) {
        self.assetUUID = assetUUID
        self.relativePath = relativePath
    }
}

public struct Lane2LegacyTombstoneStemRow: Hashable, Sendable {
    public let projectUUID: UUID
    public let relativePath: String

    public init(projectUUID: UUID, relativePath: String) {
        self.projectUUID = projectUUID
        self.relativePath = relativePath
    }
}

public struct Lane2LegacyTombstoneProjectionMetrics: Equatable, Sendable {
    public let projectCount: Int
    public let batchCount: Int
    public let projectFetchCalls: Int
    public let assetFetchCalls: Int
    public let stemFetchCalls: Int

    public init(
        projectCount: Int,
        batchCount: Int,
        projectFetchCalls: Int,
        assetFetchCalls: Int,
        stemFetchCalls: Int
    ) {
        self.projectCount = projectCount
        self.batchCount = batchCount
        self.projectFetchCalls = projectFetchCalls
        self.assetFetchCalls = assetFetchCalls
        self.stemFetchCalls = stemFetchCalls
    }

    public var totalLogicalFetchCalls: Int {
        projectFetchCalls + assetFetchCalls + stemFetchCalls
    }
}

public enum Lane2LegacyTombstoneProjectionFailure: Error, Equatable, Sendable {
    case duplicateAssetIdentity(UUID)
}

public enum Lane2LegacyTombstoneProjectionPolicy {
    public static func materializeBatch(
        projects: [Lane2LegacyTombstoneProjectRow],
        assets: [Lane2LegacyTombstoneAssetRow],
        stems: [Lane2LegacyTombstoneStemRow]
    ) throws -> [Lane2TombstonedProjectCompactionCandidate] {
        var assetsByID: [UUID: Lane2LegacyTombstoneAssetRow] = [:]
        assetsByID.reserveCapacity(assets.count)
        for asset in assets {
            guard assetsByID[asset.assetUUID] == nil else {
                throw Lane2LegacyTombstoneProjectionFailure.duplicateAssetIdentity(asset.assetUUID)
            }
            assetsByID[asset.assetUUID] = asset
        }

        var stemPathsByProject: [UUID: [String]] = [:]
        for stem in stems {
            stemPathsByProject[stem.projectUUID, default: []].append(stem.relativePath)
        }

        var candidates: [Lane2TombstonedProjectCompactionCandidate] = []
        candidates.reserveCapacity(projects.count)
        for project in projects {
            guard let asset = assetsByID[project.sourceAssetUUID] else {
                throw Lane2TombstonedMetadataCompactionFailure.missingSourceAsset(project.sourceAssetUUID)
            }
            candidates.append(
                Lane2TombstonedProjectCompactionCandidate(
                    projectUUID: project.projectUUID,
                    sourceAssetUUID: project.sourceAssetUUID,
                    artifactRelativePaths: [asset.relativePath] + (stemPathsByProject[project.projectUUID] ?? [])
                )
            )
        }
        return candidates
    }

    public static func metrics(
        projectCount: Int,
        enumerationPolicy: LibraryEnumerationPolicy
    ) -> Lane2LegacyTombstoneProjectionMetrics {
        let count = max(projectCount, 0)
        let batches = enumerationPolicy.batchCount(forCount: count)
        return Lane2LegacyTombstoneProjectionMetrics(
            projectCount: count,
            batchCount: batches,
            projectFetchCalls: 1,
            assetFetchCalls: batches,
            stemFetchCalls: batches
        )
    }

    public static func legacyNPlusOneFetchUpperBound(projectCount: Int) -> Int {
        1 + max(projectCount, 0) * 2
    }
}
