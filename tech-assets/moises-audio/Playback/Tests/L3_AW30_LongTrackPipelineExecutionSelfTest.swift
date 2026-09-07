import Foundation

private enum AW30PipelineBackendError: Error { case forced }

private final class AW30PipelineBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private var tempo = 1.0
    private var pitch = 0.0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW30PipelineClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private var activeGeneration: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        guard generation > activeGeneration else { throw AW30PipelineBackendError.forced }
        activeGeneration = generation
    }
}

@main
struct L3AW30LongTrackPipelineExecutionSelfTest {
    static func main() async throws {
        let projectID = ProjectID()
        let backend = AW30PipelineBackend()
        let controller = try PracticeDSPProductionController(projectID: projectID, backend: backend)
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: projectID,
            controller: controller,
            clickInvalidator: AW30PipelineClickInvalidator()
        )
        let playbackToken = PlaybackTransportRescheduleToken(generation: 1, reason: .seek)
        let coordinatorReceipt = try await coordinator.bindTransportDiscontinuity(playbackToken: playbackToken)
        let productionReceipt = try await Lane3ProductionGenerationEvidenceCapture.capture(
            coordinator: coordinator,
            receipt: coordinatorReceipt
        )
        let lineageBinding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: productionReceipt.activePlaybackGeneration,
            clickGeneration: productionReceipt.activeClickGeneration,
            reason: .seek
        )
        let recoveryLineage = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
            playbackToken: playbackToken,
            binding: lineageBinding,
            activeClickGeneration: productionReceipt.activeClickGeneration
        )

        let frameCount = 65_536
        let descriptor = makePCM(frameCount: frameCount)
        let reference = Lane3ArrayPCMChunkSource(descriptor)
        let observed = Lane3ArrayPCMChunkSource(descriptor)
        let offline = Lane3OfflineEvidenceReceipt(
            fixtureID: "aw30-rights-cleared-fixture-placeholder",
            controlSignatureFNV1A64: "0123456789abcdef",
            outputSampleRate: 48_000,
            plannedFrameCount: Int64(frameCount),
            renderedFrameCount: Int64(frameCount),
            clickEventCount: 2,
            actualAudioCaptured: true,
            outputFileWritten: true,
            eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
            componentParityPromotionAllowed: false
        )
        let timeConfiguration = Lane3PCMDifferentialConfiguration(
            maximumAlignmentLagFrames: 64,
            alignmentWindowFrames: 8_192,
            localDriftSearchFrames: 16,
            localWindowFrames: 2_048,
            driftAnchorCount: 5,
            onsetSearchRadiusFrames: 64,
            expectedEventMaskRadiusFrames: 16,
            minimumComparableFrames: 512
        )
        let spectralConfiguration = Lane3SpectralDifferentialConfiguration(
            windowSize: 1_024,
            hopSize: 256,
            minimumFrequencyHz: 40,
            maximumFrequencyHz: 12_000,
            expectedFrequencyRatio: 1,
            frequencyRatioSearchRadiusCents: 100,
            frequencyRatioSearchStepCents: 10,
            highBandStartHz: 5_000,
            spectralFloorDB: -120,
            minimumWindowRMS: 1e-7,
            maximumWindows: 32
        )
        let envelopeConfiguration = Lane3CepstralEnvelopeConfiguration(
            windowSize: 1_024,
            hopSize: 256,
            minimumFrequencyHz: 100,
            maximumFrequencyHz: 5_000,
            cepstralCoefficientCount: 8,
            minimumWindowRMS: 1e-7,
            maximumWindows: 32,
            formantPeakLimit: 8
        )

        let execution = Lane3LongTrackEvidenceExecutionController()
        let result = try Lane3LongTrackUnifiedEvidencePipelineV2.analyze(
            productionGeneration: productionReceipt,
            recoveryLineage: recoveryLineage,
            offline: offline,
            referencePCM: reference,
            observedPCM: observed,
            expectedEventFrames: [16_384, 32_768],
            comparisonIntent: .peerSameControls,
            timeConfiguration: timeConfiguration,
            spectralConfiguration: spectralConfiguration,
            envelopeConfiguration: envelopeConfiguration,
            chunkFrames: 4_096,
            executionController: execution
        )
        let completion = try execution.completionReceipt()
        precondition(completion.runBindingSHA256 == result.reportV2.runBindingSHA256)
        precondition(completion.referenceReadCalls > 0 && completion.observedReadCalls > 0)
        precondition(execution.checkpoint().state == .completed)
        precondition(!execution.checkpoint().authoritativeEvidenceAllowed)

        let cancelled = Lane3LongTrackEvidenceExecutionController()
        cancelled.requestCancellation()
        do {
            _ = try Lane3LongTrackUnifiedEvidencePipelineV2.analyze(
                productionGeneration: productionReceipt,
                recoveryLineage: recoveryLineage,
                offline: offline,
                referencePCM: reference,
                observedPCM: observed,
                expectedEventFrames: [16_384, 32_768],
                comparisonIntent: .peerSameControls,
                timeConfiguration: timeConfiguration,
                spectralConfiguration: spectralConfiguration,
                envelopeConfiguration: envelopeConfiguration,
                chunkFrames: 4_096,
                executionController: cancelled
            )
            preconditionFailure("pre-cancelled long-track execution must not return evidence")
        } catch Lane3LongTrackEvidenceExecutionError.cancelled { }
        precondition(cancelled.checkpoint().state == .cancelled)
        do { _ = try cancelled.completionReceipt(); preconditionFailure() }
        catch Lane3LongTrackEvidenceExecutionError.completionUnavailable { }

        print(
            "L3-AW30 pipeline execution self-test PASS runBinding=\(completion.runBindingSHA256) "
                + "referenceReads=\(completion.referenceReadCalls) observedReads=\(completion.observedReadCalls)"
        )
    }

    private static func makePCM(frameCount: Int) -> Lane3PCMBufferDescriptor {
        var samples: [Float] = []
        samples.reserveCapacity(frameCount * 2)
        for frame in 0..<frameCount {
            let t = Double(frame) / 48_000
            let value = 0.35 * (
                0.55 * sin(2 * Double.pi * 220 * t)
                + 0.30 * sin(2 * Double.pi * 700 * t)
                + 0.20 * sin(2 * Double.pi * 1_300 * t)
                + 0.15 * sin(2 * Double.pi * 2_500 * t)
            )
            samples.append(Float(value))
            samples.append(Float(value * 0.97))
        }
        return Lane3PCMBufferDescriptor(
            interleavedSamples: samples,
            channels: 2,
            sampleRate: 48_000
        )
    }
}
