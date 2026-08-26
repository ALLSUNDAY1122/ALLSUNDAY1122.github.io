import Foundation

private struct Lane3AW44SyntheticPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
    let salt: Float

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<channels {
                output[frame * channels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997 + salt
            }
        }
        return output
    }
}

private enum Lane3AW44SelfTest {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func descriptor(_ id: String, _ fault: Lane3RepresentativeCodecFaultExpectation) throws -> Lane3RepresentativeCodecFixtureDescriptor {
        try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: id,
            declaredCodecLabel: "aac-lc",
            faultExpectation: fault,
            expectedChannels: 2,
            expectedSampleRate: 100,
            baselineFrameCount: 180_000,
            rightsCleared: true
        )
    }

    static func makeLongTrackResult(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        runBindingOverride: String? = nil
    ) throws -> Lane3LongTrackUnifiedEvidenceResult {
        let identity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(reference: reference, observed: observed, chunkFrames: 4_096)
        let coordinator = PracticeDSPGenerationCoordinatorReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_PRODUCTION_COMBINED_GENERATION_NON_PARITY",
            operationSerial: 7,
            mutationKind: .transportDiscontinuity,
            playbackGeneration: 3,
            clickGeneration: 5,
            reason: "seek",
            replacementBindingActive: true,
            parityPromotionAllowed: false
        )
        let production = Lane3ProductionGenerationEvidenceReceipt(
            coordinatorReceipt: coordinator,
            snapshotOperationSerial: 7,
            activePlaybackGeneration: 3,
            activeClickGeneration: 5,
            activeReason: "seek",
            currentBindingValidated: true
        )
        let recovery = Lane3CombinedRecoveryAW05Receipt(
            playbackGeneration: 3,
            clickGeneration: 5,
            reason: .seek,
            evidenceScope: "LANE3_AW05_TO_AW11_GENERATION_RECEIPT_NON_PARITY",
            parityPromotionAllowed: false
        )
        let transport = Lane3TransportEvidenceReceipt(
            playbackGeneration: 3,
            clickGeneration: 5,
            transactionSerial: 7,
            reason: "seek",
            gateValidatedCurrentBinding: true
        )
        let offline = Lane3OfflineEvidenceReceipt(
            fixtureID: "aw44-long-run",
            controlSignatureFNV1A64: "aw44-control",
            outputSampleRate: observed.sampleRate,
            plannedFrameCount: observed.frameCount,
            renderedFrameCount: observed.frameCount,
            clickEventCount: 4,
            actualAudioCaptured: true,
            outputFileWritten: false,
            eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
            componentParityPromotionAllowed: false
        )
        let time = Lane3TimeDomainEvidenceSnapshot(
            evidenceScope: "LANE3_PCM_DIFFERENTIAL_NON_PARITY",
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount,
            globalLagFrames: 2,
            globalNormalizedCorrelation: 1,
            onsetObservationCount: 4,
            maximumAbsoluteResidualOnsetErrorFrames: 0,
            unexpectedDiscontinuityCount: 0,
            maximumUnexpectedDerivative: 0,
            observedClippedSampleCount: 0,
            observedNonFiniteSampleCount: 0,
            componentParityPromotionAllowed: false
        )
        let spectral = Lane3SpectralEvidenceSnapshot(
            evidenceScope: "LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY",
            globalLagFramesApplied: 2,
            windowsAnalyzed: 8,
            expectedFrequencyRatio: 1,
            estimatedFrequencyRatio: 1,
            frequencyRatioErrorCents: 0,
            p95AbsoluteSpectralPeakRatioErrorCents: 0,
            meanLogSpectralDistanceDB: 0,
            meanAbsoluteHighBandEnergyDeltaDB: 0,
            meanBandEnergyCosineDistance: 0,
            rmsEnvelopeCorrelation: 1,
            meanSpectralFluxDelta: 0,
            referenceNonFiniteSampleCount: 0,
            observedNonFiniteSampleCount: 0,
            perceptualClaimAllowed: false,
            componentParityPromotionAllowed: false
        )
        let core = Lane3IntegratedEvidenceReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_INTEGRATED_PLAYBACK_DSP_EVIDENCE_NON_PARITY",
            fixtureID: offline.fixtureID,
            controlSignatureFNV1A64: offline.controlSignatureFNV1A64,
            comparisonIntent: .peerSameControls,
            transport: transport,
            offline: offline,
            timeDomain: time,
            spectral: spectral,
            expectedEventCount: 4,
            sourceEvidenceScopes: [offline.eventEvidenceScope, time.evidenceScope, spectral.evidenceScope],
            readyForRealAudioReview: true,
            humanAudibilityClaimed: false,
            standardizedPerceptualMetricClaimed: false,
            parityPromotionAllowed: false
        )
        let envelopeReport = Lane3CepstralEnvelopeDifferentialReport(
            evidenceScope: "LANE3_CEPSTRAL_ENVELOPE_FORMANT_PROXY_NON_PARITY",
            globalLagFramesApplied: 2,
            windowsAnalyzed: 8,
            cepstralCoefficientCount: 8,
            meanEnvelopeRMSEDB: 0,
            p95EnvelopeRMSEDB: 0,
            meanEnvelopeCorrelation: 1,
            meanAbsoluteSpectralTiltDeltaDBPerOctave: 0,
            formantPeakMatches: [],
            medianAbsoluteFormantPeakErrorCents: nil,
            p95AbsoluteFormantPeakErrorCents: nil,
            referenceNonFiniteSampleCount: 0,
            observedNonFiniteSampleCount: 0,
            windowObservations: [],
            standardizedPerceptualClaimAllowed: false,
            formantPreservationClaimAllowed: false,
            parityPromotionAllowed: false
        )
        let envelope = Lane3EnvelopeEvidenceSnapshot(report: envelopeReport)
        let calculatedRunBinding = Lane3LongTrackPCMIdentityHasher.digestFields([
            offline.fixtureID,
            offline.controlSignatureFNV1A64,
            "3", "5", "seek", "7",
            identity.algorithm,
            identity.referenceDigestSHA256,
            identity.observedDigestSHA256,
            "2", "8", "4"
        ])
        let report = Lane3UnifiedEvidenceReportV2(
            schemaVersion: 2,
            evidenceScope: "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY",
            fixtureID: offline.fixtureID,
            controlSignatureFNV1A64: offline.controlSignatureFNV1A64,
            comparisonIntent: .peerSameControls,
            productionGeneration: production,
            recoveryLineage: recovery,
            pcmIdentity: identity,
            coreEvidence: core,
            envelope: envelope,
            runBindingSHA256: runBindingOverride ?? calculatedRunBinding,
            sourceEvidenceScopes: [],
            readyForRealAudioReview: true,
            humanAudibilityClaimed: false,
            standardizedPerceptualMetricClaimed: false,
            formantPreservationClaimed: false,
            parityPromotionAllowed: false
        )
        return Lane3LongTrackUnifiedEvidenceResult(
            reportV2: report,
            resourceProfile: try Lane3LongTrackEvidenceResourcePlanner.profile(channels: 2, chunkFrames: 4_096),
            parityPromotionAllowed: false
        )
    }

    static func completion(for result: Lane3LongTrackUnifiedEvidenceResult) -> Lane3LongTrackEvidenceCompletionReceipt {
        Lane3LongTrackEvidenceCompletionReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW30_LONG_TRACK_EXECUTION_COMPLETION_NON_PARITY",
            runBindingSHA256: result.reportV2.runBindingSHA256,
            finalCheckpointSerial: 99,
            referenceReadCalls: 100,
            observedReadCalls: 100,
            referenceFramesRequested: UInt64(result.reportV2.pcmIdentity.referenceFrameCount),
            observedFramesRequested: UInt64(result.reportV2.pcmIdentity.observedFrameCount),
            counterOverflowed: false,
            progressPermille: 1_000,
            finalReportConstructedBeforeCompletion: true,
            rawPCMIncluded: false,
            sourcePathIncluded: false,
            parityPromotionAllowed: false
        )
    }
}

@main
struct L3AW44CodecLongTrackEvidenceBindingSelfTestMain {
    static func main() throws {
        let source = Lane3AW44SyntheticPCMSource(channels: 2, sampleRate: 100, frameCount: 180_000, salt: 0)
        let cleanDescriptor = try Lane3AW44SelfTest.descriptor("aw44-aac-clean", .clean)
        let truncatedDescriptor = try Lane3AW44SelfTest.descriptor("aw44-aac-truncated", .truncated)
        let corruptedDescriptor = try Lane3AW44SelfTest.descriptor("aw44-aac-corrupted", .corrupted)
        let clean = try Lane3RepresentativeCodecExecutionProbe.sweep(source: source, descriptor: cleanDescriptor, environment: .portableStructural, chunkFrames: 4_096)
        let truncated = Lane3RepresentativeCodecExecutionProbe.openRejected(descriptor: truncatedDescriptor, environment: .portableStructural, failureCode: .openRejected)
        let corrupted = Lane3RepresentativeCodecExecutionProbe.openRejected(descriptor: corruptedDescriptor, environment: .portableStructural, failureCode: .openRejected)
        let longTrack = try Lane3AW44SelfTest.makeLongTrackResult(reference: source, observed: source)
        let completion = Lane3AW44SelfTest.completion(for: longTrack)
        let receipt = try Lane3CodecLongTrackEvidenceBinder.makeReceipt(
            cleanSource: source,
            sourceRole: .reference,
            cleanReport: clean,
            truncatedReport: truncated,
            corruptedReport: corrupted,
            longTrackResult: longTrack,
            completion: completion,
            identityChunkFrames: 4_096
        )
        _ = try Lane3CodecLongTrackEvidenceBinder.validate(receipt, cleanSource: source, cleanReport: clean, truncatedReport: truncated, corruptedReport: corrupted, longTrackResult: longTrack, completion: completion, identityChunkFrames: 4_096)
        Lane3AW44SelfTest.require(receipt.targetPCMIdentityMatched, "target identity must match")
        Lane3AW44SelfTest.require(receipt.completionRunBindingMatched, "completion run must match")
        Lane3AW44SelfTest.require(!receipt.derivativeLineageCryptographicallyProven, "derivative lineage must not be overclaimed")
        Lane3AW44SelfTest.require(!receipt.authenticitySignatureIncluded, "content hash is not a signature")

        do {
            let different = Lane3AW44SyntheticPCMSource(channels: 2, sampleRate: 100, frameCount: 180_000, salt: 0.125)
            _ = try Lane3CodecLongTrackEvidenceBinder.makeReceipt(cleanSource: different, sourceRole: .reference, cleanReport: clean, truncatedReport: truncated, corruptedReport: corrupted, longTrackResult: longTrack, completion: completion, identityChunkFrames: 4_096)
            preconditionFailure("different clean content was accepted")
        } catch Lane3CodecLongTrackEvidenceBindingError.cleanReportReexecutionMismatch {}

        let fakeRun = String(repeating: "a", count: 64)
        let tamperedLongTrack = try Lane3AW44SelfTest.makeLongTrackResult(reference: source, observed: source, runBindingOverride: fakeRun)
        do {
            _ = try Lane3CodecLongTrackEvidenceBinder.makeReceipt(cleanSource: source, sourceRole: .reference, cleanReport: clean, truncatedReport: truncated, corruptedReport: corrupted, longTrackResult: tamperedLongTrack, completion: Lane3AW44SelfTest.completion(for: tamperedLongTrack), identityChunkFrames: 4_096)
            preconditionFailure("self-consistent but non-recomputed AW30 binding was accepted")
        } catch Lane3CodecLongTrackEvidenceBindingError.invalidLongTrackResult {}

        let alternateReference = Lane3AW44SyntheticPCMSource(channels: 2, sampleRate: 100.25, frameCount: 180_000, salt: 0.25)
        let observedRoleRun = try Lane3AW44SelfTest.makeLongTrackResult(reference: alternateReference, observed: source)
        let observedRoleReceipt = try Lane3CodecLongTrackEvidenceBinder.makeReceipt(
            cleanSource: source,
            sourceRole: .observed,
            cleanReport: clean,
            truncatedReport: truncated,
            corruptedReport: corrupted,
            longTrackResult: observedRoleRun,
            completion: Lane3AW44SelfTest.completion(for: observedRoleRun),
            identityChunkFrames: 4_096
        )
        Lane3AW44SelfTest.require(observedRoleReceipt.sourceRole == .observed, "observed role must bind observed digest")
        print("L3-AW44 content binding PASS combined=\(receipt.combinedBindingSHA256.prefix(16)) observedRole=PASS")
    }
}
