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
    private let quarantineRecovery: Lane2LifecycleQuarantineRecovery
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
        self.registrationJournal = Lane2ExportRegistrationJournal(
            rootURL: rootURL,
            fileManager: fileManager
        )
        self.quarantineRecovery = Lane2LifecycleQuarantineRecovery(
            rootURL: rootURL,
            fileManager: fileManager
        )
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
        try await quarantineRecovery.requireExportMetadataConsistent()
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
                    Lane2ExportRegistrationArtifact(
                        relativePath: $0.relativePath,
                        mediaType: $0.mediaType
                    )
                }
            )
            registrationIntentID = intent.id
            activeExportRegistrationIntents.insert(intent.id)

            // AW36: close the post-prepare/pre-metadata TOCTOU. The durable intent remains if
            // published bytes drift after AW35 prepare verification.
            try registrationJournal.revalidatePublishedBatchIntegrityIfPresent(intent: intent)

            _ = try await metadata.recordExports(
                projectUUID: request.projectID.rawValue,
                artifacts: produced.map { ($0.relativePath, $0.mediaType) }
            )
            metadataCommitted = true

            // AW36: metadata may have committed immediately before a process death or content
            // mutation. Revalidate again before intent retirement. Failure intentionally leaves the
            // intent durable so relaunch recovery fails closed rather than blessing changed bytes.
            try registrationJournal.revalidatePublishedBatchIntegrityIfPresent(intent: intent)
            activeExportRegistrationIntents.remove(intent.id)
            try registrationJournal.complete(intentID: intent.id)
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

    /// Explicit metadata-recovery entrypoint. A durable export barrier is prepared before any
    /// corrupt export shard is moved, then canonical Project Library ownership is reconstructed.
    /// Corrupt export metadata itself is never guessed from canonical Library state.
    @discardableResult
    public func quarantineAndReconcileLifecycleMetadata() async throws -> Lane2LifecycleCanonicalRecoveryReport {
        var quarantined: [String] = []

        do {
            _ = try await quarantineRecovery.prepareBarrierForCurrentCorruptExportShards()
            quarantined = try await metadata.quarantineCorruptShards().quarantinedRelativePaths
        } catch Lane2LifecycleMetadataFailure.corruptDocument {
            _ = try await quarantineRecovery.prepareBarrierForLegacyCorruption()
            guard let preserved = try await metadata.quarantineCorruptLegacyDocument() else {
                throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
            }
            quarantined = [preserved]
        } catch Lane2LifecycleMetadataFailure.invalidRelativePath {
            _ = try await quarantineRecovery.prepareBarrierForLegacyCorruption()
            guard let preserved = try await metadata.quarantineCorruptLegacyDocument() else {
                throw Lane2LifecycleQuarantineRecoveryFailure.corruptBarrier
            }
            quarantined = [preserved]
        }

        try await reconcileProjectOwnership()
        return Lane2LifecycleCanonicalRecoveryReport(
            quarantinedRelativePaths: quarantined,
            exportRecoveryBarrier: try await quarantineRecovery.barrier(),
            ownershipReconciled: true
        )
    }

    public func exportMetadataRecoveryBarrier() async throws -> Lane2ExportMetadataQuarantineBarrier? {
        try await quarantineRecovery.barrier()
    }

    @discardableResult
    public func resolveQuarantinedExportMetadata(
        _ resolution: Lane2ExportMetadataRecoveryResolution
    ) async throws -> Lane2ExportMetadataRecoveryCompletionReport {
        guard let barrier = try await quarantineRecovery.barrier() else {
            return Lane2ExportMetadataRecoveryCompletionReport(
                restoredProjectUUIDs: [],
                acknowledgedEmptyProjectUUIDs: [],
                acknowledgedUnattributedMetadataLoss: false
            )
        }

        try await quarantineRecovery.validate(resolution: resolution, against: barrier)
        try await quarantineRecovery.requireRecoveredArtifactsReady(resolution.restoredArtifacts)

        let grouped = Dictionary(grouping: resolution.restoredArtifacts, by: \.projectUUID)
        let before = try await metadata.snapshot()
        for (projectUUID, restored) in grouped {
            let existing = before.exports.filter { $0.projectUUID == projectUUID }
            let existingKeys = Set(existing.map { "\($0.relativePath)|\($0.mediaType)" })
            let desiredKeys = Set(restored.map { "\($0.relativePath)|\($0.mediaType)" })
            if !existing.isEmpty {
                guard existing.allSatisfy({ $0.state == .ready }), existingKeys == desiredKeys else {
                    throw Lane2LifecycleQuarantineRecoveryFailure.conflictingExistingExportMetadata(projectUUID)
                }
                continue
            }
            _ = try await metadata.recordExports(
                projectUUID: projectUUID,
                artifacts: restored.map { ($0.relativePath, $0.mediaType) }
            )
        }

        for projectUUID in resolution.acknowledgedEmptyProjectUUIDs {
            let existing = before.exports.filter { $0.projectUUID == projectUUID }
            guard existing.isEmpty else {
                throw Lane2LifecycleQuarantineRecoveryFailure.conflictingExistingExportMetadata(projectUUID)
            }
        }

        let after = try await metadata.snapshot()
        for (projectUUID, restored) in grouped {
            let existing = after.exports.filter { $0.projectUUID == projectUUID }
            let existingKeys = Set(existing.map { "\($0.relativePath)|\($0.mediaType)" })
            let desiredKeys = Set(restored.map { "\($0.relativePath)|\($0.mediaType)" })
            guard existing.allSatisfy({ $0.state == .ready }), existingKeys == desiredKeys else {
                throw Lane2LifecycleQuarantineRecoveryFailure.conflictingExistingExportMetadata(projectUUID)
            }
        }

        try await quarantineRecovery.clearBarrier()
        return Lane2ExportMetadataRecoveryCompletionReport(
            restoredProjectUUIDs: Array(grouped.keys),
            acknowledgedEmptyProjectUUIDs: Array(resolution.acknowledgedEmptyProjectUUIDs),
            acknowledgedUnattributedMetadataLoss: resolution.acknowledgeUnattributedMetadataLoss
        )
    }

    @discardableResult
    public func recoverPendingExportRegistrations() async throws -> Lane2ExportRegistrationRecoveryReport {
        try await quarantineRecovery.requireExportMetadataConsistent()
        let pending = try registrationJournal.pending()
        if pending.isEmpty {
            return Lane2ExportRegistrationRecoveryReport(
                preservedRegistered: 0,
                discardedUnregistered: 0,
                retainedIncomplete: 0
            )
        }

        let lifecycle = try await metadata.snapshot()
        var preservedRegistered = 0
        var discardedUnregistered = 0
        var retainedIncomplete = 0

        for intent in pending {
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
                // AW36: registered metadata does not authorize intent retirement unless the AW35+
                // manifest still matches the exact published bytes on relaunch.
                try registrationJournal.revalidatePublishedBatchIntegrityIfPresent(intent: intent)
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
                            error: DomainFailure.exportFailed(
                                code: "EXPORT_COMPENSATION_INCOMPLETE"
                            )
                        )
                    }
                } catch {
                    retainedIncomplete += 1
                    try? await persistFailure(
                        attemptID: UUID(),
                        projectID: ProjectID(rawValue: intent.projectUUID),
                        operation: .exportAudio,
                        error: DomainFailure.exportFailed(
                            code: "EXPORT_COMPENSATION_INCOMPLETE"
                        )
                    )
                }

            case .partial:
                throw Lane2ExportRegistrationJournalFailure.partialRegistration(intent.id)
            }
        }

        return Lane2ExportRegistrationRecoveryReport(
            preservedRegistered: preservedRegistered,
            discardedUnregistered: discardedUnregistered,
            retainedIncomplete: retainedIncomplete
        )
    }

    public func cleanupExports(projectID: ProjectID) async throws {
        try await quarantineRecovery.requireExportMetadataConsistent()
        let records = try await metadata.beginExportCleanup(projectUUID: projectID.rawValue)
        try await finishExportCleanup(records)
    }

    public func recoverPendingExportCleanup() async throws {
        try await quarantineRecovery.requireExportMetadataConsistent()
        try await finishExportCleanup(try await metadata.pendingExportCleanup())
    }

    public func deleteProjectAndOwnedArtifacts(projectID: ProjectID) async throws {
        try await quarantineRecovery.requireExportMetadataConsistent()
        try await library.deleteProject(projectID: projectID)
        try await reconcileDeletedProjectArtifacts()
    }

    public func reconcileDeletedProjectArtifacts() async throws {
        try await quarantineRecovery.requireExportMetadataConsistent()
        let liveIDs = try await liveProjectUUIDs()
        let lifecycle = try await metadata.snapshot()
        let trackedIDs = Set(
            lifecycle.projects.map(\.projectUUID) + lifecycle.exports.map(\.projectUUID)
        )
        for projectUUID in trackedIDs where !liveIDs.contains(projectUUID) {
            let deleting = try await metadata.beginExportCleanup(projectUUID: projectUUID)
            try await finishExportCleanup(deleting)
            try await metadata.removeProjectMetadata(projectUUID: projectUUID)
        }
    }

    public func reconcileProjectOwnership() async throws {
        for project in try await maintenanceProjects() {
            try await metadata.upsertProjectOwnership(
                projectUUID: project.projectID.rawValue,
                sourceAssetUUID: project.sourceAssetID.rawValue,
                sourceRelativePath: project.sourceRelativePath
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
            exports: lifecycle.exports.filter {
                $0.projectUUID == projectID.rawValue && $0.state == .ready
            },
            latestFailure: try await metadata.latestFailure(projectUUID: projectID.rawValue)
        )
    }

    public func sweepOrphans(
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) async throws -> LibraryOrphanSweepResult {
        try await quarantineRecovery.requireExportMetadataConsistent()
        try await recoverPendingExportRegistrations()
        try await recoverPendingExportCleanup()
        try await reconcileDeletedProjectArtifacts()
        let projects = try await maintenanceProjects()
        let lifecycle = try await metadata.snapshot()
        var referenced = LibraryMaintenanceProjectionPolicy.referencedArtifactPaths(in: projects)
        lifecycle.exports.forEach { referenced.insert($0.relativePath) }
        return try artifacts.sweepOrphans(
            referencedRelativePaths: referenced,
            gracePeriod: gracePeriod,
            now: now
        )
    }

    public func lifecycleSnapshot() async throws -> Lane2LifecycleSnapshot {
        try await quarantineRecovery.requireExportMetadataConsistent()
        return try await metadata.snapshot()
    }

    private func liveProjectUUIDs() async throws -> Set<UUID> {
        if let provider = library as? any LibraryMaintenanceProjectProviding {
            return Set(try await provider.listLiveProjectIDs().map(\.rawValue))
        }
        return Set(try await library.listProjects().map { $0.projectID.rawValue })
    }

    private func maintenanceProjects() async throws -> [LibraryMaintenanceProject] {
        if let provider = library as? any LibraryMaintenanceProjectProviding {
            return try await provider.listMaintenanceProjects()
        }

        let snapshots = try await library.listProjects()
        return try LibraryMaintenanceProjectionPolicy.validateUniqueProjects(
            snapshots.map {
                try LibraryMaintenanceProject(
                    projectID: $0.projectID,
                    sourceAssetID: $0.source.id,
                    sourceRelativePath: $0.source.relativePath,
                    stemRelativePaths: $0.stems.map(\.relativePath)
                )
            }
        )
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
        case .accessDenied:
            return ("ACCESS_DENIED", false)
        case .providerUnavailable:
            return ("PROVIDER_UNAVAILABLE", true)
        case .networkUnavailable:
            return ("NETWORK_UNAVAILABLE", true)
        case .networkTimeout:
            return ("NETWORK_TIMEOUT", true)
        case .unsupportedMedia:
            return ("UNSUPPORTED_MEDIA", false)
        case .protectedMedia:
            return ("PROTECTED_MEDIA", false)
        case .corruptMedia:
            return ("CORRUPT_MEDIA", false)
        case .noAudioTrack:
            return ("NO_AUDIO_TRACK", false)
        case .insufficientStorage:
            return ("INSUFFICIENT_STORAGE", true)
        case .cancelled:
            return ("CANCELLED", true)
        case .processingFailed(let code, let retryable):
            return (code, retryable)
        case .exportFailed(let code):
            return (code, false)
        }
    }
}
