import Foundation

/// Backend-side result metadata source. It may describe AudioShake outputs, a project-owned model,
/// or another approved provider, but it must not return a `StemArtifact` until local assurance passes.
public protocol SeparationRunManifestProviding: Sendable {
    func outputManifest(jobID: ProcessingJobID) async throws -> SeparationProviderRunManifest
}

/// Keeps the frozen Shared provider contract while inserting the Lane 1 assurance gates on result().
/// start/snapshot/cancel remain delegated to the selected provider controller. result() is produced
/// only from a complete, verified, project-controlled output set.
public actor AssuredSeparationProvider: SourceSeparationProviding {
    private let controller: any SourceSeparationProviding
    private let manifestProvider: any SeparationRunManifestProviding
    private let assurance: SeparationOutputAssurance
    private let ledgerStore: any SeparationRunLedgerStoring

    public init(
        controller: any SourceSeparationProviding,
        manifestProvider: any SeparationRunManifestProviding,
        assurance: SeparationOutputAssurance,
        ledgerStore: any SeparationRunLedgerStoring
    ) {
        self.controller = controller
        self.manifestProvider = manifestProvider
        self.assurance = assurance
        self.ledgerStore = ledgerStore
    }

    public func start(_ request: SeparationRequest) async throws -> ProcessingJobID {
        try await controller.start(request)
    }

    public func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot {
        try await controller.snapshot(jobID: jobID)
    }

    public func result(jobID: ProcessingJobID) async throws -> [StemArtifact] {
        let manifest = try await manifestProvider.outputManifest(jobID: jobID)
        guard manifest.jobID == jobID else {
            throw DomainFailure.processingFailed(code: "SEP_ASSURANCE_JOB_ID_MISMATCH", retryable: false)
        }

        // Structural role/container/timing declarations must be sane even when a trusted local result
        // already exists. URL freshness/cost/retention are intentionally handled later because a fully
        // verified local transaction must remain recoverable after signed vendor URLs expire.
        try SeparationArtifactSetIntegrity.validate(manifest)

        if let trusted = try await ledgerStore.load(projectID: manifest.projectID, jobID: jobID) {
            try SeparationArtifactSetIntegrity.validateCachedManifestIdentity(manifest, trusted: trusted.manifest)
        }

        _ = try await assurance.recoverInterruptedCommit(projectID: manifest.projectID, jobID: jobID)

        if let existing = try await ledgerStore.load(projectID: manifest.projectID, jobID: jobID) {
            try SeparationArtifactSetIntegrity.validateCachedManifestIdentity(manifest, trusted: existing.manifest)
            switch existing.state {
            case .committed:
                return try await assurance.committedArtifacts(projectID: manifest.projectID, jobID: jobID)
            case .prepared:
                return try await assurance.commit(projectID: manifest.projectID, jobID: jobID).finalArtifacts
            case .deleted:
                break
            }
        }

        // No trusted local result exists. Remote output URLs must therefore still be fresh and the
        // full provider manifest (including cost/retention metadata) must pass before any download.
        try await assurance.validateManifest(manifest)
        _ = try await assurance.prepare(manifest)
        return try await assurance.commit(projectID: manifest.projectID, jobID: jobID).finalArtifacts
    }

    public func cancel(jobID: ProcessingJobID) async {
        await controller.cancel(jobID: jobID)
    }
}
