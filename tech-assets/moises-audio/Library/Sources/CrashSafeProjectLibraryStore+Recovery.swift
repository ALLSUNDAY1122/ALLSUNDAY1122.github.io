import Foundation

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct RecoverableLibraryOpenResult: Sendable {
    public let library: CrashSafeProjectLibraryStore
    public let metadataOpen: PreservingStoreOpenResult

    public init(library: CrashSafeProjectLibraryStore, metadataOpen: PreservingStoreOpenResult) {
        self.library = library
        self.metadataOpen = metadataOpen
    }
}

public extension CrashSafeProjectLibraryStore {
    /// Production-safe preserving open path. AW24 prepares only one bounded legacy tombstone slice
    /// per launch before crash-safe delete recovery; remaining historical tombstones resume on a
    /// later launch without re-entering the old unbounded compatibility scanner.
    static func openPreservingUserData(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        recoveryRootURL: URL? = nil
    ) async throws -> RecoverableLibraryOpenResult {
        let metadataOpen = try await PreservingCoreDataStoreOpener.open(
            storeURL: metadataStoreURL,
            recoveryRootURL: recoveryRootURL
        )
        _ = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
            metadataStoreURL: metadataStoreURL,
            artifactRootURL: artifactRootURL
        )
        let library = try CrashSafeProjectLibraryStore(
            metadata: metadataOpen.store,
            artifactRootURL: artifactRootURL
        )
        _ = try await library.recoverInterruptedOperations()
        _ = try await metadataOpen.store.reconcileOrphanSetlistEntries()
        _ = try await library.reconcileSetlistIntegrity()
        return RecoverableLibraryOpenResult(library: library, metadataOpen: metadataOpen)
    }
}
#endif
