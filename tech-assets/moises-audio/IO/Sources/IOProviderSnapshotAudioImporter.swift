import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

/// Product-composition seam for picker / Files / File Provider imports.
/// A durable staging ownership lease remains active through downstream codec/media validation so
/// concurrent recovery cannot sweep a long-running import's ready snapshot.
public actor IOProviderSnapshotAudioImporter {
    private let baseImporter: any AudioImporting
    private let acquirer: IOProviderSnapshotAcquirer
    private let fileStore: IOFileStore
    private let fileManager: FileManager
    private let ownershipKeepAliveInterval: TimeInterval

    public init(
        baseImporter: any AudioImporting,
        rootURL: URL,
        maximumFileBytes: Int64,
        storageReserveBytes: Int64,
        chunkBytes: Int = 1024 * 1024,
        ownershipHeartbeatBytes: Int64 = 8 * 1024 * 1024,
        ownershipLeaseDuration: TimeInterval = 2 * 60 * 60,
        ownershipKeepAliveInterval: TimeInterval = 30,
        fileManager: FileManager = .default
    ) {
        let store = IOFileStore(rootURL: rootURL)
        self.baseImporter = baseImporter
        self.fileStore = store
        self.acquirer = IOProviderSnapshotAcquirer(
            fileStore: store,
            maximumFileBytes: maximumFileBytes,
            storageReserveBytes: storageReserveBytes,
            chunkBytes: chunkBytes,
            ownershipHeartbeatBytes: ownershipHeartbeatBytes,
            ownershipLeaseDuration: ownershipLeaseDuration,
            fileManager: fileManager
        )
        self.fileManager = fileManager
        self.ownershipKeepAliveInterval = max(0.1, ownershipKeepAliveInterval)
    }

    public func importExternalFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode = .securityScoped
    ) async throws -> LocalAudioAsset {
        let snapshot: IOProviderStagedSnapshot
        do {
            snapshot = try acquirer.stageProviderSnapshot(
                at: sourceURL,
                accessMode: accessMode,
                fileManager: fileManager
            )
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as IOProviderSnapshotAcquisitionError {
            throw Self.map(error)
        } catch let error as IOFileStore.StoreError {
            throw Self.map(error)
        } catch let error as IOStagingOwnershipError {
            throw Self.map(error)
        } catch {
            let ns = error as NSError
            throw DomainFailure.processingFailed(code: "PROVIDER_IMPORT_\(ns.code)", retryable: true)
        }

        do {
            try snapshot.ownership.heartbeat(writtenBytes: snapshot.stagedFile.descriptor.byteCount)
        } catch {
            snapshot.ownership.release()
            fileStore.removeIfExists(snapshot.stagedFile.stagingURL, fileManager: fileManager)
            throw DomainFailure.processingFailed(code: "PROVIDER_STAGE_OWNERSHIP_LOST", retryable: true)
        }

        let lease = snapshot.ownership
        let writtenBytes = snapshot.stagedFile.descriptor.byteCount
        let keepAliveInterval = ownershipKeepAliveInterval
        let keepAlive = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(keepAliveInterval))
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                try? lease.heartbeat(writtenBytes: writtenBytes)
            }
        }
        defer {
            keepAlive.cancel()
            snapshot.ownership.release()
            fileStore.removeIfExists(snapshot.stagedFile.stagingURL, fileManager: fileManager)
        }

        let relativePath: String
        do {
            relativePath = try fileStore.relativePath(for: snapshot.stagedFile.stagingURL)
        } catch {
            throw DomainFailure.processingFailed(code: "PROVIDER_STAGE_PATH_INVALID", retryable: false)
        }
        return try await baseImporter.importAudio(from: .appOwnedFile(relativePath: relativePath))
    }

    private static func map(_ error: IOProviderSnapshotAcquisitionError) -> DomainFailure {
        switch error {
        case .invalidConfiguration, .invalidSourceURL, .sourceInsideAppRoot:
            return .processingFailed(code: "EXTERNAL_SOURCE_URL_INVALID", retryable: false)
        case .sourceMissing, .sourceEmpty:
            return .corruptMedia
        case .sourceNotRegularFile:
            return .unsupportedMedia
        case .sourceTooLarge:
            return .processingFailed(code: "IMPORT_FILE_TOO_LARGE", retryable: false)
        case .insufficientStorage:
            return .insufficientStorage
        case .securityScopeDenied:
            return .accessDenied
        case .providerCoordinationFailed:
            return .providerUnavailable
        case .sourceChangedDuringAcquisition:
            return .processingFailed(code: "PROVIDER_SOURCE_CHANGED_DURING_ACQUISITION", retryable: true)
        case .partialPublishFailed:
            return .processingFailed(code: "PROVIDER_STAGE_PUBLISH_FAILED", retryable: true)
        }
    }

    private static func map(_ error: IOFileStore.StoreError) -> DomainFailure {
        switch error {
        case .invalidRelativePath:
            return .accessDenied
        case .sourceMissing:
            return .corruptMedia
        case .insufficientStorage:
            return .insufficientStorage
        case .fileOperationFailed(let code):
            return .processingFailed(code: code, retryable: true)
        }
    }

    private static func map(_ error: IOStagingOwnershipError) -> DomainFailure {
        switch error {
        case .invalidConfiguration, .invalidToken, .invalidStagingFilename:
            return .processingFailed(code: "PROVIDER_STAGE_OWNERSHIP_INVALID", retryable: false)
        case .ledgerUnavailable, .leaseMissing, .leaseCorrupt:
            return .processingFailed(code: "PROVIDER_STAGE_OWNERSHIP_UNAVAILABLE", retryable: true)
        }
    }
}
