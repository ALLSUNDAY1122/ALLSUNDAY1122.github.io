import Foundation

/// Privacy-preserving instrumentation decorator for the real Playback backend.
/// It records only monotonic durations and route categories into the aggregate collector.
/// No ProjectID, media metadata, paths, absolute timestamps or audio samples are retained.
public final class Lane3TelemetryPlaybackBackend: PlaybackBackendDriving, @unchecked Sendable {
    private let backend: any PlaybackBackendDriving
    private let telemetry: Lane3ProductionTelemetryCollector
    private let timeSource: any Lane3TelemetryTimeSource

    public init(
        backend: any PlaybackBackendDriving,
        telemetry: Lane3ProductionTelemetryCollector,
        timeSource: any Lane3TelemetryTimeSource = Lane3SystemTelemetryTimeSource()
    ) {
        self.backend = backend
        self.telemetry = telemetry
        self.timeSource = timeSource
    }

    public func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        try await measure(kind: .mediaLoad) {
            try await backend.loadSource(projectID: projectID, asset: asset)
        }
    }

    public func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try await measure(kind: .mediaReplacement) {
            try await backend.loadStems(
                projectID: projectID,
                stems: stems,
                positionSeconds: positionSeconds,
                resume: resume,
                loop: loop
            )
        }
    }

    public func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {
        try await backend.setEffectiveGains(projectID: projectID, gains: gains)
    }

    public func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try await measure(kind: .seek) {
            try await backend.seek(
                projectID: projectID,
                to: positionSeconds,
                resume: resume,
                loop: loop
            )
        }
    }

    public func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        try await measure(kind: .loop) {
            try await backend.setLoop(projectID: projectID, loop: loop)
        }
    }

    public func play(projectID: ProjectID) async throws {
        try await measure(kind: .play) {
            try await backend.play(projectID: projectID)
        }
    }

    public func pause(projectID: ProjectID) async {
        let start = timeSource.nowNanoseconds()
        await telemetry.recordBackendDispatchEntry(kind: .pause, atNanoseconds: start)
        await backend.pause(projectID: projectID)
        let end = timeSource.nowNanoseconds()
        await telemetry.recordBackendCompletion(
            kind: .pause,
            durationNanoseconds: Self.elapsed(from: start, to: end)
        )
    }

    public func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        await backend.currentPositionSeconds(projectID: projectID)
    }

    private func measure(
        kind: Lane3UnifiedTransportKind,
        operation: () async throws -> Void
    ) async throws {
        let start = timeSource.nowNanoseconds()
        await telemetry.recordBackendDispatchEntry(kind: kind, atNanoseconds: start)
        do {
            try await operation()
            let end = timeSource.nowNanoseconds()
            await telemetry.recordBackendCompletion(
                kind: kind,
                durationNanoseconds: Self.elapsed(from: start, to: end)
            )
        } catch {
            let end = timeSource.nowNanoseconds()
            await telemetry.recordBackendCompletion(
                kind: kind,
                durationNanoseconds: Self.elapsed(from: start, to: end)
            )
            throw error
        }
    }

    private static func elapsed(from start: UInt64, to end: UInt64) -> UInt64 {
        end >= start ? end - start : 0
    }
}
