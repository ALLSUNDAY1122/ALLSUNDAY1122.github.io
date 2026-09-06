import Foundation

private final class AW30Source: Lane3PCMChunkReadable, @unchecked Sendable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 32_768
    private let onRead: (@Sendable () -> Void)?

    init(onRead: (@Sendable () -> Void)? = nil) {
        self.onRead = onRead
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        onRead?()
        return [Float](repeating: 0.125, count: frameCount * channels)
    }
}

@main
struct L3AW30LongTrackExecutionSelfTest {
    static func main() async throws {
        let progress = Lane3LongTrackEvidenceExecutionController()
        var checkpoint = progress.checkpoint()
        precondition(checkpoint.state == .running)
        precondition(checkpoint.phase == .validatingInputs)
        precondition(checkpoint.progressLowerBoundPermille == 0)
        precondition(!checkpoint.authoritativeEvidenceAllowed)
        precondition(checkpoint.resumeMode == .restartRequired)
        precondition(!checkpoint.partialMetricsIncluded && !checkpoint.rawPCMIncluded && !checkpoint.sourcePathIncluded)

        try progress.begin(.timeDomain)
        try progress.begin(.spectral)
        do {
            try progress.begin(.assemblingCore)
            preconditionFailure("skipping a stage must fail closed")
        } catch Lane3LongTrackEvidenceExecutionError.invalidPhaseTransition { }
        try progress.begin(.envelope)
        try progress.begin(.assemblingCore)
        try progress.begin(.pcmIdentity)
        try progress.begin(.finalizing)

        let reference = Lane3CancellationAwarePCMChunkSource(base: AW30Source(), role: .reference, controller: progress)
        let observed = Lane3CancellationAwarePCMChunkSource(base: AW30Source(), role: .observed, controller: progress)
        _ = try reference.readInterleavedFrames(startFrame: 0, frameCount: 512)
        _ = try observed.readInterleavedFrames(startFrame: 0, frameCount: 256)
        checkpoint = progress.checkpoint()
        precondition(checkpoint.referenceReadCalls == 1 && checkpoint.referenceFramesRequested == 512)
        precondition(checkpoint.observedReadCalls == 1 && checkpoint.observedFramesRequested == 256)
        precondition(checkpoint.progressLowerBoundPermille == 950)

        let binding = String(repeating: "a", count: 64)
        try progress.markCompleted(runBindingSHA256: binding)
        let completion = try progress.completionReceipt()
        precondition(completion.runBindingSHA256 == binding)
        precondition(completion.progressPermille == 1_000)
        precondition(completion.finalReportConstructedBeforeCompletion)
        precondition(!completion.rawPCMIncluded && !completion.sourcePathIncluded && !completion.parityPromotionAllowed)
        checkpoint = progress.checkpoint()
        precondition(checkpoint.state == .completed && checkpoint.phase == .completed)
        precondition(!checkpoint.authoritativeEvidenceAllowed, "checkpoint is never authoritative evidence")

        let encodedCheckpoint = String(data: try JSONEncoder().encode(checkpoint), encoding: .utf8)!
        precondition(!encodedCheckpoint.contains("file://"))
        precondition(!encodedCheckpoint.contains("/tmp/"))
        precondition(!encodedCheckpoint.lowercased().contains("pcmdata"))

        let preCancelled = Lane3LongTrackEvidenceExecutionController()
        preCancelled.requestCancellation()
        let preCancelledSource = Lane3CancellationAwarePCMChunkSource(base: AW30Source(), role: .reference, controller: preCancelled)
        do {
            _ = try preCancelledSource.readInterleavedFrames(startFrame: 0, frameCount: 64)
            preconditionFailure("pre-read cancellation must stop the read")
        } catch Lane3LongTrackEvidenceExecutionError.cancelled { }
        let preCancelledCheckpoint = preCancelled.checkpoint()
        precondition(preCancelledCheckpoint.state == .cancelled)
        precondition(preCancelledCheckpoint.referenceReadCalls == 0)
        do { _ = try preCancelled.completionReceipt(); preconditionFailure() }
        catch Lane3LongTrackEvidenceExecutionError.completionUnavailable { }

        let midRead = Lane3LongTrackEvidenceExecutionController()
        let midReadBase = AW30Source { midRead.requestCancellation() }
        let midReadSource = Lane3CancellationAwarePCMChunkSource(base: midReadBase, role: .reference, controller: midRead)
        do {
            _ = try midReadSource.readInterleavedFrames(startFrame: 0, frameCount: 128)
            preconditionFailure("cancellation during underlying read must discard returned PCM")
        } catch Lane3LongTrackEvidenceExecutionError.cancelled { }
        let midReadCheckpoint = midRead.checkpoint()
        precondition(midReadCheckpoint.state == .cancelled)
        precondition(midReadCheckpoint.referenceReadCalls == 1)
        precondition(midReadCheckpoint.referenceFramesRequested == 128)
        precondition(!midReadCheckpoint.authoritativeEvidenceAllowed)

        let failed = Lane3LongTrackEvidenceExecutionController()
        try failed.begin(.timeDomain)
        failed.markFailed()
        let failedCheckpoint = failed.checkpoint()
        precondition(failedCheckpoint.state == .failed)
        precondition(!failedCheckpoint.authoritativeEvidenceAllowed)
        do { _ = try failed.completionReceipt(); preconditionFailure() }
        catch Lane3LongTrackEvidenceExecutionError.completionUnavailable { }

        let taskCancelled = Lane3LongTrackEvidenceExecutionController()
        let taskSource = Lane3CancellationAwarePCMChunkSource(base: AW30Source(), role: .reference, controller: taskCancelled)
        let task = Task { () throws -> [Float] in
            while !Task.isCancelled { await Task.yield() }
            return try taskSource.readInterleavedFrames(startFrame: 0, frameCount: 32)
        }
        task.cancel()
        do {
            _ = try await task.value
            preconditionFailure("Swift Task cancellation must be observed")
        } catch Lane3LongTrackEvidenceExecutionError.cancelled { }
        precondition(taskCancelled.checkpoint().state == .cancelled)

        do {
            let invalid = Lane3LongTrackEvidenceExecutionController()
            try invalid.begin(.timeDomain)
            try invalid.begin(.spectral)
            try invalid.begin(.envelope)
            try invalid.begin(.assemblingCore)
            try invalid.begin(.pcmIdentity)
            try invalid.begin(.finalizing)
            try invalid.markCompleted(runBindingSHA256: String(repeating: "A", count: 64))
            preconditionFailure("uppercase binding must not complete")
        } catch Lane3LongTrackEvidenceExecutionError.invalidCompletionReceipt { }

        print("L3-AW30 long-track execution self-test PASS cancellation=pre+midread+task progress=monotonic partialEvidence=forbidden completionBinding=validated")
    }
}
