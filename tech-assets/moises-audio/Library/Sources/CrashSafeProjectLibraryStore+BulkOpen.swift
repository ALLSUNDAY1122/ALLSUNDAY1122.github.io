import Foundation

#if canImport(CoreData)
public extension CrashSafeProjectLibraryStore {
    /// AW23 production open for callers that do not need PreservingCoreDataStoreOpener.
    /// Pre-AW22 tombstones are bulk-indexed before CrashSafe recovery so the old per-project
    /// compatibility projection is not on the canonical startup path.
    static func openBulkPrepared(
        metadataConfiguration: CoreDataProjectLibraryStore.Configuration,
        artifactRootURL: URL
    ) async throws -> CrashSafeProjectLibraryStore {
        let metadata = try CoreDataProjectLibraryStore(configuration: metadataConfiguration)
        if !metadataConfiguration.inMemory,
           let metadataStoreURL = metadataConfiguration.storeURL {
            _ = try await Lane2LegacyTombstoneBulkMigrator.prepareIfNeeded(
                metadataStoreURL: metadataStoreURL,
                artifactRootURL: artifactRootURL,
                enumerationBatchSize: metadataConfiguration.enumerationPolicy.batchSize
            )
        }
        let store = try CrashSafeProjectLibraryStore(
            metadata: metadata,
            artifactRootURL: artifactRootURL
        )
        _ = try await store.recoverInterruptedOperations()
        return store
    }
}
#endif
