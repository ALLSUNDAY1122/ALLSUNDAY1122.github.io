import Foundation

public enum AppRoute: Equatable, Sendable {
    case library
    case importFlow
    case separationSelection(ProjectID)
    case project(ProjectID)
    case export(ProjectID)
}

public struct ProjectPresentation: Equatable, Sendable {
    public let projectID: ProjectID
    public var processing: ProcessingSnapshot?
    public var playbackReadiness: PlaybackReadiness
    public var analysis: AnalysisSnapshot?

    public init(
        projectID: ProjectID,
        processing: ProcessingSnapshot? = nil,
        playbackReadiness: PlaybackReadiness = .sourceOnly,
        analysis: AnalysisSnapshot? = nil
    ) {
        self.projectID = projectID
        self.processing = processing
        self.playbackReadiness = playbackReadiness
        self.analysis = analysis
    }
}

/// App-facing seam for Lane1 durable processing recovery. The concrete Lane1 recovery actor conforms
/// without changing the frozen Shared provider contract.
public protocol ProcessingAppRelaunchRecovering: Sendable {
    func recover(projectID: ProjectID) async throws -> ProcessingRecoveryAction
}

extension ProcessingCrashSafeRelaunchRecovery: ProcessingAppRelaunchRecovering {}

/// Composition-only coordinator. Feature engines retain their own operational state.
/// A project may be presented while separation is still running.
public actor VerticalSliceCoordinator {
    private let importer: any AudioImporting
    private let separator: any SourceSeparationProviding
    private let playback: any PlaybackPreparing
    private let analysisEngine: any MusicAnalyzing
    private let persistence: any ProjectPersisting
    private let exporter: any AudioExporting
    private let processingRecovery: (any ProcessingAppRelaunchRecovering)?

    public private(set) var route: AppRoute = .library
    public private(set) var project: ProjectPresentation?
    public private(set) var processingRecoveryAction: ProcessingRecoveryAction?

    public init(
        importer: any AudioImporting,
        separator: any SourceSeparationProviding,
        playback: any PlaybackPreparing,
        analysisEngine: any MusicAnalyzing,
        persistence: any ProjectPersisting,
        exporter: any AudioExporting,
        processingRecovery: (any ProcessingAppRelaunchRecovering)? = nil
    ) {
        self.importer = importer
        self.separator = separator
        self.playback = playback
        self.analysisEngine = analysisEngine
        self.persistence = persistence
        self.exporter = exporter
        self.processingRecovery = processingRecovery
    }

    /// App startup/relaunch hook. Absence of a configured recovery dependency is deliberately not
    /// treated as `.none`: callers must not silently interpret "recovery was never wired" as
    /// "there was nothing to recover".
    @discardableResult
    public func recoverProcessingAfterRelaunch(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let processingRecovery else {
            throw DomainFailure.processingFailed(code: "PROC_RECOVERY_NOT_CONFIGURED", retryable: false)
        }
        let action = try await processingRecovery.recover(projectID: projectID)
        processingRecoveryAction = action
        return action
    }

    @discardableResult
    public func importSource(_ request: ImportRequest) async throws -> ProjectID {
        let asset = try await importer.importAudio(from: request)
        let projectID = try await persistence.createProject(source: asset)
        try await playback.prepareSource(projectID: projectID, asset: asset)
        project = ProjectPresentation(projectID: projectID, playbackReadiness: .sourceOnly)
        route = .separationSelection(projectID)
        return projectID
    }

    @discardableResult
    public func startSeparation(asset: LocalAudioAsset, roles: Set<StemRole>, qualityProfile: String) async throws -> ProcessingJobID {
        guard let current = project else {
            throw DomainFailure.processingFailed(code: "NO_ACTIVE_PROJECT", retryable: false)
        }
        let request = SeparationRequest(
            projectID: current.projectID,
            asset: asset,
            requestedRoles: roles,
            qualityProfile: qualityProfile
        )
        let jobID = try await separator.start(request)
        let snapshot = try await separator.snapshot(jobID: jobID)
        try await persistence.recordProcessing(projectID: current.projectID, snapshot: snapshot)

        project?.processing = snapshot
        project?.playbackReadiness = .stemsPreparing
        route = .project(current.projectID)
        return jobID
    }

    /// Refreshes processing without blocking the project/player presentation.
    public func refreshProcessing(jobID: ProcessingJobID) async throws {
        guard let current = project else { return }
        let snapshot = try await separator.snapshot(jobID: jobID)
        project?.processing = snapshot
        try await persistence.recordProcessing(projectID: current.projectID, snapshot: snapshot)

        guard snapshot.phase == .ready else {
            if snapshot.phase == .failed, let code = snapshot.stableErrorCode {
                project?.playbackReadiness = .unavailable(stableErrorCode: code)
            }
            return
        }

        let stems = try await separator.result(jobID: jobID)
        try await playback.replaceWithStems(projectID: current.projectID, stems: stems)
        try await persistence.recordStems(projectID: current.projectID, stems: stems)
        project?.playbackReadiness = .stemsReady(stems)
    }

    public func analyzeSource(asset: LocalAudioAsset) async throws {
        guard let current = project else { return }
        project?.analysis = try await analysisEngine.analyze(projectID: current.projectID, asset: asset)
    }

    public func cancelProcessing(jobID: ProcessingJobID) async {
        await separator.cancel(jobID: jobID)
    }

    public func beginExport() {
        guard let current = project else { return }
        route = .export(current.projectID)
    }

    public func export(_ request: ExportRequest) async throws -> [ExportArtifact] {
        try await exporter.export(request)
    }

    public func openProject(_ projectID: ProjectID) {
        route = .project(projectID)
    }

    public func showLibrary() {
        route = .library
    }
}
