import Foundation

private enum AW13BackendError: Error { case forced }

private final class AW13TransactionalBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW13ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private(set) var activeGeneration: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        guard generation > activeGeneration else { throw AW13BackendError.forced }
        activeGeneration = generation
    }
}

@main
struct L3AW13UnifiedEvidenceV2SelfTest {
    static func main() async throws {
        let projectID = ProjectID()
        let backend = AW13TransactionalBackend()
        let controller = try PracticeDSPProductionController(
            projectID: projectID,
            backend: backend
        )
        let click = AW13ClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: projectID,
            controller: controller,
            clickInvalidator: click
        )

        let playbackToken = PlaybackTransportRescheduleToken(
            generation: 1,
            reason: .seek
        )
        let coordinatorReceipt = try await coordinator.bindTransportDiscontinuity(
            playbackToken: playbackToken
        )
        let productionReceipt = try await Lane3ProductionGenerationEvidenceCapture.capture(
            coordinator: coordinator,
            receipt: coordinatorReceipt
        )
        precondition(productionReceipt.currentBindingValidated)
        precondition(productionReceipt.activePlaybackGeneration == 1)
        precondition(productionReceipt.activeClickGeneration == 1)

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

        let frameCount = 8_192
        let reference = makePCM(frameCount: frameCount, gain: 0.35)
        let observed = reference
        let offline = Lane3OfflineEvidenceReceipt(
            fixtureID: "aw13-lawful-fixture-placeholder",
            controlSignatureFNV1A64: "aw13-controls",
            outputSampleRate: 48_000,
            plannedFrameCount: Int64(frameCount),
            renderedFrameCount: Int64(frameCount),
            clickEventCount: 2,
            actualAudioCaptured: true,
            outputFileWritten: true,
            eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
            componentParityPromotionAllowed: false
        )

        let report = try Lane3UnifiedEvidencePipelineV2.analyze(
            productionGeneration: productionReceipt,
            recoveryLineage: recoveryLineage,
            offline: offline,
            referencePCM: reference,
            observedPCM: observed,
            expectedEventFrames: [2_048, 4_096],
            comparisonIntent: .peerSameControls
        )
        precondition(report.schemaVersion == 2)
        precondition(report.evidenceScope == "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY")
        precondition(report.coreEvidence.timeDomain.globalLagFrames == report.envelope.globalLagFramesApplied)
        precondition(report.pcmIdentity.referenceDigestFNV1A64 == report.pcmIdentity.observedDigestFNV1A64)
        precondition(report.productionGeneration.activePlaybackGeneration == report.recoveryLineage.playbackGeneration)
        precondition(report.productionGeneration.activeClickGeneration == report.recoveryLineage.clickGeneration)
        precondition(!report.humanAudibilityClaimed)
        precondition(!report.standardizedPerceptualMetricClaimed)
        precondition(!report.formantPreservationClaimed)
        precondition(!report.parityPromotionAllowed)

        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(Lane3UnifiedEvidenceReportV2.self, from: encoded)
        precondition(decoded == report)

        var changedSamples = observed.interleavedSamples
        changedSamples[511] += 0.125
        let changedObserved = Lane3PCMBufferDescriptor(
            interleavedSamples: changedSamples,
            channels: observed.channels,
            sampleRate: observed.sampleRate
        )
        let changedIdentity = try Lane3PCMIdentityHasher.makeReceipt(
            reference: reference,
            observed: changedObserved
        )
        precondition(changedIdentity.observedDigestFNV1A64 != report.pcmIdentity.observedDigestFNV1A64)

        do {
            let malformed = try malformedRecoveryLineage(from: recoveryLineage)
            _ = try Lane3UnifiedEvidencePipelineV2.analyze(
                productionGeneration: productionReceipt,
                recoveryLineage: malformed,
                offline: offline,
                referencePCM: reference,
                observedPCM: observed,
                expectedEventFrames: [2_048, 4_096],
                comparisonIntent: .peerSameControls
            )
            preconditionFailure("generation-mismatched AW11 lineage must fail")
        } catch Lane3UnifiedEvidenceV2Error.generationLineageMismatch {
        }

        let clickOnlyReceipt = try await coordinator.setMetronomeEnabled(true)
        do {
            _ = try await Lane3ProductionGenerationEvidenceCapture.capture(
                coordinator: coordinator,
                receipt: coordinatorReceipt
            )
            preconditionFailure("old production receipt must be stale after click-only mutation")
        } catch Lane3UnifiedEvidenceV2Error.staleProductionGenerationReceipt {
        }
        do {
            _ = try await Lane3ProductionGenerationEvidenceCapture.capture(
                coordinator: coordinator,
                receipt: clickOnlyReceipt
            )
            preconditionFailure("click-only receipt cannot authorize a rendered evidence run")
        } catch Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt {
        }

        print("L3-AW13 unified evidence v2 self-test PASS")
        print("run_binding=\(report.runBindingFNV1A64) pcm=\(report.pcmIdentity.referenceDigestFNV1A64)")
    }

    private static func makePCM(frameCount: Int, gain: Double) -> Lane3PCMBufferDescriptor {
        var samples: [Float] = []
        samples.reserveCapacity(frameCount * 2)
        for frame in 0..<frameCount {
            let t = Double(frame) / 48_000
            let value = gain * (
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

    private static func malformedRecoveryLineage(
        from receipt: Lane3CombinedRecoveryAW05Receipt
    ) throws -> Lane3CombinedRecoveryAW05Receipt {
        let encoded = try JSONEncoder().encode(receipt)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object["playbackGeneration"] = NSNumber(value: receipt.playbackGeneration + 1)
        let malformed = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(Lane3CombinedRecoveryAW05Receipt.self, from: malformed)
    }
}
