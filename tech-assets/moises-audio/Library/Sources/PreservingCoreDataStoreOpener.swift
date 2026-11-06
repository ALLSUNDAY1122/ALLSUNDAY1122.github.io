import Foundation

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public enum PreservingStoreOpenFailure: Error, Equatable, Sendable {
    case corruptStore(originalPath: String, recoveryPackagePath: String)
    case activeStoreInvalid(activePath: String, preservedOriginalPath: String, recoveryPackagePath: String)
    case migrationFailed(originalPath: String, preservedSnapshotPath: String, workingCopyPath: String, reason: String)
}

public struct PreservingStoreOpenResult: Sendable {
    public let store: CoreDataProjectLibraryStore
    public let recoveryPlan: LibraryStoreRecoveryPlan
    public let activeStorePath: String
    public let preservedOriginalPath: String?
    public let preservedSnapshotPath: String?
}

/// Opens Core Data without ever auto-migrating the user's only copy in place.
/// Existing stores are first snapshotted, migrated/validated as a working copy, then activated by pointer.
public enum PreservingCoreDataStoreOpener {
    public static func open(
        storeURL: URL,
        recoveryRootURL: URL? = nil
    ) async throws -> PreservingStoreOpenResult {
        let manager = try LibraryStoreRecoveryManager(storeURL: storeURL, recoveryRootURL: recoveryRootURL)

        if let active = try manager.resolveActiveStoreManifest() {
            let activeURL = URL(fileURLWithPath: active.activeStorePath)
            let activeManager = try LibraryStoreRecoveryManager(storeURL: activeURL, recoveryRootURL: manager.recoveryRootURL)
            guard activeManager.inspect() == .plausibleSQLite else {
                let package = try activeManager.exportRecoveryPackage(reason: "active-store-header-invalid")
                throw PreservingStoreOpenFailure.activeStoreInvalid(
                    activePath: active.activeStorePath,
                    preservedOriginalPath: active.preservedOriginalStorePath,
                    recoveryPackagePath: package.directoryURL.path
                )
            }
            do {
                let store = try CoreDataProjectLibraryStore(configuration: .init(storeURL: activeURL))
                try await validateReadable(store)
                return PreservingStoreOpenResult(
                    store: store,
                    recoveryPlan: manager.recoveryPlan(),
                    activeStorePath: active.activeStorePath,
                    preservedOriginalPath: active.preservedOriginalStorePath,
                    preservedSnapshotPath: active.preservedSnapshotPath
                )
            } catch {
                let package = try activeManager.exportRecoveryPackage(reason: "active-store-open-failed")
                throw PreservingStoreOpenFailure.activeStoreInvalid(
                    activePath: active.activeStorePath,
                    preservedOriginalPath: active.preservedOriginalStorePath,
                    recoveryPackagePath: package.directoryURL.path
                )
            }
        }

        switch manager.inspect() {
        case .missing:
            let store = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
            try await validateReadable(store)
            return PreservingStoreOpenResult(
                store: store,
                recoveryPlan: manager.recoveryPlan(),
                activeStorePath: storeURL.path,
                preservedOriginalPath: nil,
                preservedSnapshotPath: nil
            )

        case .corruptOrUnreadable:
            let package = try manager.exportRecoveryPackage(reason: "original-store-corrupt")
            throw PreservingStoreOpenFailure.corruptStore(
                originalPath: storeURL.path,
                recoveryPackagePath: package.directoryURL.path
            )

        case .plausibleSQLite:
            let preserved = try manager.snapshotOriginal(reason: "pre-migration")
            let working = try manager.createWorkingCopy(from: preserved)
            do {
                var migrated: CoreDataProjectLibraryStore? = try CoreDataProjectLibraryStore(
                    configuration: .init(storeURL: working.storeURL)
                )
                try await validateReadable(try unwrapStore(migrated))
                migrated = nil

                let active = try manager.activateMigratedCopy(
                    from: working,
                    preservedOriginalSnapshot: preserved
                )
                let activeStore = try CoreDataProjectLibraryStore(
                    configuration: .init(storeURL: URL(fileURLWithPath: active.activeStorePath))
                )
                try await validateReadable(activeStore)
                return PreservingStoreOpenResult(
                    store: activeStore,
                    recoveryPlan: manager.migrationPlan(),
                    activeStorePath: active.activeStorePath,
                    preservedOriginalPath: active.preservedOriginalStorePath,
                    preservedSnapshotPath: active.preservedSnapshotPath
                )
            } catch {
                throw PreservingStoreOpenFailure.migrationFailed(
                    originalPath: storeURL.path,
                    preservedSnapshotPath: preserved.directoryURL.path,
                    workingCopyPath: working.directoryURL.path,
                    reason: String(describing: error)
                )
            }
        }
    }

    private static func validateReadable(_ store: CoreDataProjectLibraryStore) async throws {
        _ = try await store.listProjects()
        _ = try await store.listSetlists()
    }
}

private func unwrapStore<T>(_ value: T?) throws -> T {
    guard let value else {
        throw LibraryStoreRecoveryError.snapshotFailed("unexpected nil store during migration validation")
    }
    return value
}
#endif
