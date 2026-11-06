import Foundation

// MARK: - AW13-compatible long-track pipeline

public enum Lane3LongTrackUnifiedEvidencePipelineV2 {
    public static func analyze(
        productionGeneration: Lane3ProductionGenerationEvidenceReceipt,
        recoveryLineage: Lane3CombinedRecoveryAW05Receipt,
        offline: Lane3OfflineEvidenceReceipt,
        referencePCM: any Lane3PCMChunkReadable,
        observedPCM: any Lane3PCMChunkReadable,
        expectedEventFrames: [Int64],
        comparisonIntent: Lane3EvidenceComparisonIntent,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration(),
        envelopeConfiguration: Lane3CepstralEnvelopeConfiguration = Lane3CepstralEnvelopeConfiguration(),
        chunkFrames: Int = 16_384,
        executionController: Lane3LongTrackEvidenceExecutionController? = nil
    ) throws -> Lane3LongTrackUnifiedEvidenceResult {
        let referenceSource: any Lane3PCMChunkReadable
        let observedSource: any Lane3PCMChunkReadable
        if let executionController {
            referenceSource = Lane3CancellationAwarePCMChunkSource(
                base: referencePCM,
                role: .reference,
                controller: executionController
            )
            observedSource = Lane3CancellationAwarePCMChunkSource(
                base: observedPCM,
                role: .observed,
                controller: executionController
            )
        } else {
            referenceSource = referencePCM
            observedSource = observedPCM
        }

        do {
            try executionController?.begin(.validatingInputs)
            let metadata = try Lane3LongTrackPCMAccess.validatePair(
                reference: referenceSource,
                observed: observedSource,
                chunkFrames: chunkFrames
            )
            try validateProduction(productionGeneration)
            try validateRecovery(recoveryLineage, production: productionGeneration)

            try executionController?.begin(.timeDomain)
            let time = try Lane3LongTrackPCMDifferentialAnalyzer.analyze(
                reference: referenceSource,
                observed: observedSource,
                expectedEventFrames: expectedEventFrames,
                configuration: timeConfiguration,
                chunkFrames: chunkFrames
            )

            try executionController?.begin(.spectral)
            let spectral = try Lane3LongTrackSpectralPerceptualDifferentialAnalyzer.analyze(
                reference: referenceSource,
                observed: observedSource,
                globalLagFrames: time.globalLagFrames,
                configuration: spectralConfiguration,
                chunkFrames: chunkFrames
            )

            try executionController?.begin(.envelope)
            let envelopeReport = try Lane3LongTrackCepstralEnvelopeDifferentialAnalyzer.analyze(
                reference: referenceSource,
                observed: observedSource,
                globalLagFrames: time.globalLagFrames,
                configuration: envelopeConfiguration,
                chunkFrames: chunkFrames
            )

            try executionController?.begin(.assemblingCore)
            let receipt = productionGeneration.coordinatorReceipt
            let transport = Lane3TransportEvidenceReceipt(
                playbackGeneration: productionGeneration.activePlaybackGeneration,
                clickGeneration: productionGeneration.activeClickGeneration,
                transactionSerial: receipt.operationSerial,
                reason: productionGeneration.activeReason,
                gateValidatedCurrentBinding: productionGeneration.currentBindingValidated
            )
            let core = try Lane3IntegratedEvidenceAssembler.assemble(
                comparisonIntent: comparisonIntent,
                transport: transport,
                offline: offline,
                referencePCMFrameCount: referenceSource.frameCount,
                observedPCMFrameCount: observedSource.frameCount,
                observedPCMSampleRate: observedSource.sampleRate,
                expectedEventCount: expectedEventFrames.count,
                timeDomain: Lane3TimeDomainEvidenceSnapshot(report: time),
                spectral: Lane3SpectralEvidenceSnapshot(report: spectral)
            )
            let envelope = Lane3EnvelopeEvidenceSnapshot(report: envelopeReport)
            try validateEnvelope(envelope, core: core)

            try executionController?.begin(.pcmIdentity)
            let identity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: referenceSource,
                observed: observedSource,
                chunkFrames: chunkFrames
            )
            let runBinding = Lane3LongTrackPCMIdentityHasher.digestFields([
                offline.fixtureID,
                offline.controlSignatureFNV1A64,
                String(productionGeneration.activePlaybackGeneration),
                String(productionGeneration.activeClickGeneration),
                productionGeneration.activeReason,
                String(receipt.operationSerial),
                identity.algorithm,
                identity.referenceDigestSHA256,
                identity.observedDigestSHA256,
                String(time.globalLagFrames),
                String(envelope.windowsAnalyzed),
                String(expectedEventFrames.count)
            ])
            let report = Lane3UnifiedEvidenceReportV2(
                schemaVersion: 2,
                evidenceScope: "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY",
                fixtureID: offline.fixtureID,
                controlSignatureFNV1A64: offline.controlSignatureFNV1A64,
                comparisonIntent: comparisonIntent,
                productionGeneration: productionGeneration,
                recoveryLineage: recoveryLineage,
                pcmIdentity: identity,
                coreEvidence: core,
                envelope: envelope,
                runBindingSHA256: runBinding,
                sourceEvidenceScopes: core.sourceEvidenceScopes + [
                    envelope.evidenceScope,
                    recoveryLineage.evidenceScope,
                    productionGeneration.evidenceScope,
                    receipt.evidenceScope
                ],
                readyForRealAudioReview: true,
                humanAudibilityClaimed: false,
                standardizedPerceptualMetricClaimed: false,
                formantPreservationClaimed: false,
                parityPromotionAllowed: false
            )

            try executionController?.begin(.finalizing)
            let profile = try Lane3LongTrackEvidenceResourcePlanner.profile(
                channels: metadata.channels,
                chunkFrames: chunkFrames,
                timeConfiguration: timeConfiguration,
                spectralConfiguration: spectralConfiguration,
                envelopeConfiguration: envelopeConfiguration
            )
            try executionController?.markCompleted(runBindingSHA256: report.runBindingSHA256)
            return .init(
                reportV2: report,
                resourceProfile: profile,
                parityPromotionAllowed: false
            )
        } catch {
            executionController?.markFailed()
            throw error
        }
    }

    private static func validateProduction(
        _ production: Lane3ProductionGenerationEvidenceReceipt
    ) throws {
        try Lane3ProductionGenerationEvidenceCapture.validateAuthorizingReceipt(
            production.coordinatorReceipt
        )
        let receipt = production.coordinatorReceipt
        guard production.schemaVersion == 1,
              production.evidenceScope == "LANE3_AW12_CURRENT_PRODUCTION_GENERATION_RECEIPT_NON_PARITY",
              production.snapshotOperationSerial == receipt.operationSerial,
              production.activePlaybackGeneration == receipt.playbackGeneration,
              production.activeClickGeneration == receipt.clickGeneration,
              production.activeReason == receipt.reason,
              production.currentBindingValidated,
              !production.parityPromotionAllowed else {
            throw Lane3LongTrackEvidenceError.invalidProductionGenerationReceipt
        }
    }

    private static func validateRecovery(
        _ recovery: Lane3CombinedRecoveryAW05Receipt,
        production: Lane3ProductionGenerationEvidenceReceipt
    ) throws {
        guard recovery.evidenceScope == "LANE3_AW05_TO_AW11_GENERATION_RECEIPT_NON_PARITY",
              recovery.playbackGeneration > 0,
              recovery.clickGeneration > 0,
              !recovery.parityPromotionAllowed else {
            throw Lane3LongTrackEvidenceError.invalidRecoveryLineageReceipt
        }
        guard recovery.playbackGeneration == production.activePlaybackGeneration,
              recovery.clickGeneration == production.activeClickGeneration else {
            throw Lane3LongTrackEvidenceError.generationLineageMismatch
        }
        guard recovery.reason.rawValue == production.activeReason else {
            throw Lane3LongTrackEvidenceError.reasonLineageMismatch
        }
    }

    private static func validateEnvelope(
        _ envelope: Lane3EnvelopeEvidenceSnapshot,
        core: Lane3IntegratedEvidenceReport
    ) throws {
        guard envelope.evidenceScope == "LANE3_CEPSTRAL_ENVELOPE_FORMANT_PROXY_NON_PARITY" else {
            throw Lane3LongTrackEvidenceError.sourceEvidenceScopeRejected(envelope.evidenceScope)
        }
        guard !envelope.standardizedPerceptualClaimAllowed,
              !envelope.formantPreservationClaimAllowed,
              !envelope.componentParityPromotionAllowed else {
            throw Lane3LongTrackEvidenceError.componentClaimRejected
        }
        guard envelope.globalLagFramesApplied == core.timeDomain.globalLagFrames else {
            throw Lane3LongTrackEvidenceError.invalidMetric
        }
        guard envelope.windowsAnalyzed > 0 else {
            throw Lane3LongTrackEvidenceError.noEnvelopeWindows
        }
        guard envelope.referenceNonFiniteSampleCount == 0,
              envelope.observedNonFiniteSampleCount == 0 else {
            throw Lane3LongTrackEvidenceError.nonFiniteEvidence(
                reference: envelope.referenceNonFiniteSampleCount,
                observed: envelope.observedNonFiniteSampleCount
            )
        }
        var metrics = [
            envelope.meanEnvelopeRMSEDB,
            envelope.p95EnvelopeRMSEDB,
            envelope.meanEnvelopeCorrelation,
            envelope.meanAbsoluteSpectralTiltDeltaDBPerOctave
        ]
        if let value = envelope.medianAbsoluteFormantPeakErrorCents { metrics.append(value) }
        if let value = envelope.p95AbsoluteFormantPeakErrorCents { metrics.append(value) }
        guard envelope.cepstralCoefficientCount > 0,
              metrics.allSatisfy(\.isFinite) else {
            throw Lane3LongTrackEvidenceError.invalidMetric
        }
    }
}
