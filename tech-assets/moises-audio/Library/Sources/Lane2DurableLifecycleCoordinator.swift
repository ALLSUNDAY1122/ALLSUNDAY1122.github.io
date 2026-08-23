import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct Lane2RelaunchState: Sendable {
    public let project: PersistedProjectSnapshot?
    public let ownership: Lane2ProjectOwnershipRecord?
    public let exports: [Lane2ExportRecord]
    public let latestFailure: Lane2FailureRecord?
}

/// Lane 2 integration seam. It composes existing IO and Library contracts without an iOS shell.
public actor Lane2DurableLifecycleCoordinator {
    private let importer: any AudioImporting
    private let exporter: any AudioExporting
    private let library: any ProjectLibraryPersisting
    private let metadata: Lane2LifecycleMetadataStore
    private let artifacts: LibraryArtifactLifecycle
    private let fileStore: IOFileStore
    private let registrationJournal: Lane2ExportRegistrationJournal
    private let storageReserveBytes: Int64
    private let fileManager: FileManager
    private var activeExportRegistrationIntents: Set<UUID> = []

    public init(
        rootURL: URL,
        importer: any AudioImporting,
        exporter: any AudioExporting,
        library: any ProjectLibraryPersisting,
        metadata: Lane2LifecycleMetadataStore? = nil,
        storageReserveBytes: Int64 = 64 * 1024 * 1024,
        fileManager: FileManager = .default
    ) {
        self.importer = importer
        self.exporter = exporter
        self.library = library
        self.metadata = metadata ?? Lane2LifecycleMetadataStore(rootURL: rootURL)
        self.artifacts = LibraryArtifactLifecycle(rootURL: rootURL)
        self.fileStore = IOFileStore(rootURL: rootURL)
        self.registrationJournal = Lane2ExportRegistrationJournal(rootURL: rootURL, fileManager: fileManager)
        self.storageReserveBytes = storageReserveBytes
        self.fileManager = fileManager
    }

    @discardableResult
    public func importAndCreateProject(from request: ImportRequest) async throws -> ProjectID {
        let attemptID = UUID()
        do {
            let source = try await importer.importAudio(from: request)
            try artifacts.requireReady(relativePath: source.relativePath)
            let projectID = try await library.createProject(source: source)
            try await metadata.upsertProjectOwnership(
                projectUUID: projectID.rawValue,
                sourceAssetUUID: source.id.rawValue,
                sourceRelativePath: source.relativePath
            )
            return projectID
        } catch {
            try? await persistFailure(
                attemptID: attemptID,
                projectID: nil,
                operation: .importAudio,
                error: error
            )
            throw error
        }
    }

    public func saveUserEdits(projectID: ProjectID, edits: ProjectUserEdits) async throws {
        try await library.saveUserEdits(projectID: projectID, edits: edits)
    }

    @discardableResult
    public func exportAndRecord(_ request: ExportRequest) async throws -> [ExportArtifact] {
        let attemptID = UUID()
        var produced: [ExportArtifact] = []
        var metadataCommitted = false
        var registrationIntentID: UUID?

        do {
            produced = try await exporter.export(request)
            guard !produced.isEmpty else {
                throw DomainFailure.exportFailed(code: "EXPORT_EMPTY_RESULT")
            }
            for artifact in produced {
                try artifacts.requireReady(relativePath: artifact.relativePath)
            }

            let intent = try registrationJournal.prepare(
                projectUUID: request.projectID.rawValue,
                artifacts: produced.map {
                    Lane2ExportRegistrationArtifact(relativePath: $0.relativePath, mediaType: $0.mediaType)
                }
            )
            registrationIntentID = intent.id
            activeExportRegistrationIntents.insert(intent.id)

            _ = try await metadata.recordExports(
                projectUUID: request.projectID.rawValue,
                artifacts: produced.map { ($0.relativePath, $0.mediaType) }
            )
            metadataCommitted = true

            activeExportRegistrationIntents.remove(intent.id)
            try? registrationJournal.complete(intentID: intent.id)
            return produced
        } catch {
            if let registrationIntentID {
                activeExportRegistrationIntents.remove(registrationIntentID)
            }

            var compensationIncomplete = false
            if !metadataCommitted && !produced.isEmpty {
                do {
                    let report = try artifacts.discardUncommittedExportArtifacts(
                        relativePaths: produced.map(\.relativePath),
                        fileManager: fileManager
                    )
                    compensationIncomplete = !report.isComplete
                    if report.isComplete, let registrationIntentID {
                        do {
                            try registrationJournal.complete(intentID: registrationIntentID)
                        } catch {
                            compensationIncomplete = true
                        }
                    }
                } catch {
                    compensationIncomplete = true
                }
            }

            try? await persistFailure(
                attemptID: attemptID,
                projectID: request.projectID,
                operation: .exportAudio,
                error: error
            )
            if compensationIncomplete {
                try? await persistFailure(
                    attemptID: UUID(),
                    projectID: request.projectID,
                    operation: .exportAudio,
                    error: DomainFailure.exportFailed(code: "EXPORT_COMPENSATION_INCOMPLETE")
                )
            }
            throw error
        }
    }

    /// Stable storage-pressure seam that can be evaluated before a large owned operation.
    public func preflight(requiredBytes: Int64, availableBytes: Int64) async throws {
        do {
            try fileStore.preflight(
                requiredBytes: requiredBytes,
                reserveBytes: storageReserveBytes,
                availableBytes: availableBytes
            )
        } catch {
            try? await persistFailure(
                attemptID: UUID(),
                projectID: nil,
                operation: .storagePreflight,
                error: DomainFailure.insufficientStorage
            )
            throw error
        }
    }

    /// Relaunch convergence for a process death after export publication but before registration,
    /// or after metadata registration but before the durable handoff intent was removed.
    @discardableResult
    public func recoverPendingExportRegistrations() async throws -> Lane2ExportRegistrationRecoveryReport {
        let pending = try registrationJournal.pending()
        if pending.isEmpty {
            return Lane2ExportRegistrationRecoveryReport(
                preservedRegistered: 0,
                discardedUnregistered: 0,
                retainedIncomplete: 0
            )
        }

        // Read canonical lifecycle metadata before any destructive recovery. Corruption here fails
        // closed and leaves every intent/artifact untouched for explicit recovery.
        let lifecycle = try await metadata.snapshot()
        var preservedRegistered = 0
        var discardedUnregistered = 0
        var retainedIncomplete = 0

        for intent in pending {
            // Actor methods are reentrant across awaits. Never recover an intent still owned by an
            // active export call in this process. After relaunch this set is empty by construction.
            if activeExportRegistrationIntents.contains(intent.id) {
                retainedIncomplete += 1
                continue
            }

            let registered = Set(
                lifecycle.exports
                    .filter { $0.projectUUID == intent.projectUUID }
                    .map(\.relativePath)
            )
            switch Lane2ExportRegistrationJournal.disposition(
                intent: intent,
                registeredRelativePaths: registered
            ) {
            case .alreadyRegistered:
                // Metadata won the race before termination. Do not delete audio; only retire intent.
                for artifact in intent.artifacts {
                    try artifacts.requireReady(relativePath: artifact.relativePath)
                }
                try registrationJournal.complete(intentID: intent.id)
                preservedRegistered += 1

            case .unregistered:
                do {
                    let report = try artifacts.discardUncommittedExportArtifacts(
                        relativePaths: intent.artifacts.map(\.relativePath),
                        fileManager: fileManager
                    )
                    if report.isComplete {
                        try registrationJournal.complete(intentID: intent.id)
                        discardedUnregistered += 1
                    } else {
                        retainedIncomplete += 1
                        try? await persistFailure(
                            attemptID: UUID(),
                            projectID: ProjectID(rawValue: intent.projectUUID),
                            operation: .exportAudio,
                            error: DomainFailure.exportFailed(code: "EXPORT_COMPENSATION_INCOMPLETE")
                        )
                    }
                } catch {
                    retainedIncomplete += 1
                    try? await persistFailure(
                        attemptID: UUID(),
                        projectID: ProjectID(rawValue: intent.projectUUID),
                        operation: .exportAudio,
                        error: DomainFailure.exportFailed(code: "EXPORT_COMPENSATION_INCOMPLETE")
                    )
                }

            case .partial:
                // recordExports writes one project shard atomically. A partial path match is not a
                // safe deletion state; retain everything for explicit diagnosis.
                throw Lane2ExportRegistrationJournalFailure.partialRegistration(intent.id)
            }
        }

        return Lane2ExportRegistrationRecoveryReport(
            preservedRegistered: preservedRegistered,
            discardedUnregistered: discardedUnregistered,
            retainedIncomplete: retainedIncomplete
        )
    }

    /// ready -> deleting metadata transition happens before file removal.
    public func cleanupExports(projectID: ProjectID) async throws {
        let records = try await metadata.beginExportCleanup(projectUUID: projectID.rawValue)
        try await finishExportCleanup(records)
    }

    /// Relaunch convergence for a crash after deleting-state metadata commit.
    public func recoverPendingExportCleanup() async throws {
        try await finishExportCleanup(try await metadata.pendingExportCleanup())
    }

    /// Deletes through canonical Library first, then converges Lane-2 export/ownership metadata.
    /// A crash after the Library tombstone is repaired by reconcileDeletedProjectArtifacts().
    public func deleteProjectAndOwnedArtifacts(projectID: ProjectID) async throws {
        try await library.deleteProject(projectID: projectID)
        try await reconcileDeletedProjectArtifacts()
    }

    /// Any sidecar project/export whose canonical Library project is no longer live is cleanup work.
    /// If Library listing fails (for example corruption), this method throws before deleting anything.
    public func reconcileDeletedProjectArtifacts() async throws {
        let liveProjects = try await library.listProjects()
        let liveIDs = Set(liveProjects.map { $0.projectID.rawValue })
        let lifecycle = try await metadata.snapshot()
        let trackedIDs = Set(lifecycle.projects.map(\.projectUUID) + lifecycle.exports.map(\.projectUUID))
        for projectUUID in trackedIDs where !liveIDs.contains(projectUUID) {
            let deleting = try await metadata.beginExportCleanup(projectUUID: projectUUID)
            try await finishExportCleanup(deleting)
            try await metadata.removeProjectMetadata(projectUUID: projectUUID)
        }
    }

    /// Repairs the lane-local ownership sidecar from canonical Library snapshots after an interrupted handoff.
    public func reconcileProjectOwnership() async throws {
        for project in try await library.listProjects() {
            try await metadata.upsertProjectOwnership(
                projectUUID: project.projectID.rawValue,
                sourceAssetUUID: project.source.id.rawValue,
                sourceRelativePath: project.source.relativePath
            )
        }
    }

    public func relaunchState(projectID: ProjectID) async throws -> Lane2RelaunchState {
        try await recoverPendingExportRegistrations()
        try await recoverPendingExportCleanup()
        try await reconcileDeletedProjectArtifacts()
        try await reconcileProjectOwnership()
        let project = try await library.loadProject(projectID: projectID)
        let lifecycle = try await metadata.snapshot()
        return Lane2RelaunchState(
            project: project,
            ownership: lifecycle.projects.first { $0.projectUUID == projectID.rawValue },
            exports: lifecycle.exports.filter { $0.projectUUID == projectID.rawValue && $0.state == .ready },
            latestFailure: try await metadata.latestFailure(projectUUID: projectID.rawValue)
        )
    }

    /// Orphan sweep retains canonical source/stem paths plus export paths recorded ready/deleting.
    public func sweepOrphans(gracePeriod: TimeInterval = 3600, now: Date = Date()) async throws -> LibraryOrphanSweepResult {
        try await recoverPendingExportRegistrations()
        try await recoverPendingExportCleanup()
        try await reconcileDeletedProjectArtifacts()
        let projects = try await library.listProjects()
        let lifecycle = try await metadata.snapshot()
        var referenced = Set<String>()
        for project in projects {
            referenced.insert(project.source.relativePath)
            project.stems.forEach { referenced.insert($0.relativePath) }
        }
        lifecycle.exports.forEach { referenced.insert($0.relativePath) }
        return try artifacts.sweepOrphans(
            referencedRelativePaths: referenced,
            gracePeriod: gracePeriod,
            now: now
        )
    }

    public func lifecycleSnapshot() async throws -> Lane2LifecycleSnapshot {
        try await metadata.snapshot()
    }

    private func finishExportCleanup(_ records: [Lane2ExportRecord]) async throws {
        for record in records {
            let url = try artifacts.absoluteURL(for: record.relativePath)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            try await metadata.finishExportCleanup(exportID: record.id)
        }
    }

    private func persistFailure(
        attemptID: UUID,
        projectID: ProjectID?,
        operation: Lane2LifecycleOperation,
        error: Error
    ) async throws {
        let mapped = Self.failureCode(error)
        try await metadata.recordFailure(
            Lane2FailureRecord(
                attemptUUID: attemptID,
                projectUUID: projectID?.rawValue,
                operation: operation,
                stableCode: mapped.code,
                retryable: mapped.retryable,
                createdAt: Date()
            )
        )
    }

    private static func failureCode(_ error: Error) -> (code: String, retryable: Bool) {
        guard let failure = error as? DomainFailure else {
            if case IOFileStore.StoreError.insufficientStorage = error {
                return ("INSUFFICIENT_STORAGE", true)
            }
            let ns = error as NSError
            return ("LANE2_FAILURE_\(ns.code)", false)
        }
        switch failure {
        case .accessDenied: return ("ACCESS_DENIED", false)
        case .providerUnavailable: return ("PROVIDER_UNAVAILABLE", true)
        case .networkUnavailable: return ("NETWORK_UNAVAILABLE", true)
        case .networkTimeout: return ("NETWORK_TIMEOUT", true)
        case .unsupportedMedia: return ("UNSUPPORTED_MEDIA", false)
        case .protectedMedia: return ("PROTECTED_MEDIA", false)
        case .corruptMedia: return ("CORRUPT_MEDIA", false)
        case .noAudioTrack: return ("NO_AUDIO_TRACK", false)
        case .insufficientStorage: return ("INSUFFICIENT_STORAGE", true)
        case .cancelled: return ("CANCELLED", true)
        case .processingFailed(let code, let retryable): return (code, retryable)
        case .exportFailed(let code): return (code, false)
        }
    }
}
