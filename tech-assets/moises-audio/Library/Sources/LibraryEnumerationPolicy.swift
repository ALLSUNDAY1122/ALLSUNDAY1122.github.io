import Foundation

/// Lane-local policy for bounded Core Data enumeration. The public Shared contract still returns
/// complete arrays; this policy limits the size of each related-record materialization batch.
public struct LibraryEnumerationPolicy: Equatable, Sendable {
    public static let defaultBatchSize = 128
    public static let minimumBatchSize = 16
    public static let maximumBatchSize = 1024

    public let batchSize: Int

    public init(batchSize: Int = Self.defaultBatchSize) {
        self.batchSize = min(max(batchSize, Self.minimumBatchSize), Self.maximumBatchSize)
    }

    public func ranges(forCount count: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        var ranges: [Range<Int>] = []
        ranges.reserveCapacity((count + batchSize - 1) / batchSize)
        var lower = 0
        while lower < count {
            let upper = min(lower + batchSize, count)
            ranges.append(lower..<upper)
            lower = upper
        }
        return ranges
    }

    public func batchCount(forCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (count + batchSize - 1) / batchSize
    }

    /// Informational upper bound for the bounded materialization shape used by listProjects().
    /// One primary ProjectRecord fetch plus one fetch per related record group per batch.
    public func estimatedProjectFetchOperations(projectCount: Int, relatedRecordGroups: Int = 5) -> Int {
        guard projectCount >= 0, relatedRecordGroups >= 0 else { return 0 }
        return 1 + batchCount(forCount: projectCount) * relatedRecordGroups
    }

    /// Informational upper bound for maintenance projections: root projects plus source assets/stems.
    public func estimatedMaintenanceFetchOperations(projectCount: Int, relatedRecordGroups: Int = 2) -> Int {
        guard projectCount >= 0, relatedRecordGroups >= 0 else { return 0 }
        return 1 + batchCount(forCount: projectCount) * relatedRecordGroups
    }

    /// Informational upper bound for listSetlists(): one primary SetlistRecord fetch plus one
    /// batched SetlistEntryRecord fetch per setlist batch.
    public func estimatedSetlistFetchOperations(setlistCount: Int) -> Int {
        guard setlistCount >= 0 else { return 0 }
        return 1 + batchCount(forCount: setlistCount)
    }
}
