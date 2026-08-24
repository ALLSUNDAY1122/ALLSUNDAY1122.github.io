import Foundation

#if canImport(CoreData)
public extension CrashSafeProjectLibraryStore {
    /// AW24 production open for callers that do not need PreservingCoreDataStoreOpener.
    /// A bounded pre-AW22 compatibility slice is indexed before CrashSafe recovery. The legacy
    /// backlog therefore converges across launches instead of monopolizing one startup.
    static func openBulkPrepared(
        metadataConfiguration: CoreDataProjectLibraryStore.Configuration,
        artifactRootURL: URL
    ) async throws -> CrashSafeProjectLibraryStore {
        let metadata = try CoreDataProjectLibraryStore(configuration: metadataConfiguration)
        if !metadataConfiguration.inMemory,
           let metadataStoreURL = metadataConfiguration.storeURL {
            _ = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
                metadataStoreURL: metadataStoreURL,
                artifactRootURL: artifactRootURL
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
