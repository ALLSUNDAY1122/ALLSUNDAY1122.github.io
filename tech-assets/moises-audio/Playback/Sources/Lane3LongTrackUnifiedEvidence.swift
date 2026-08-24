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
        chunkFrames: Int = 16_384
    ) throws -> Lane3LongTrackUnifiedEvidenceResult {
        let metadata = try Lane3LongTrackPCMAccess.validatePair(reference: referencePCM, observed: observedPCM, chunkFrames: chunkFrames)
        try validateProduction(productionGeneration)
        try validateRecovery(recoveryLineage, production: productionGeneration)
        let time = try Lane3LongTrackPCMDifferentialAnalyzer.analyze(reference: referencePCM, observed: observedPCM, expectedEventFrames: expectedEventFrames, configuration: timeConfiguration, chunkFrames: chunkFrames)
        let spectral = try Lane3LongTrackSpectralPerceptualDifferentialAnalyzer.analyze(reference: referencePCM, observed: observedPCM, globalLagFrames: time.globalLagFrames, configuration: spectralConfiguration, chunkFrames: chunkFrames)
        let envelopeReport = try Lane3LongTrackCepstralEnvelopeDifferentialAnalyzer.analyze(reference: referencePCM, observed: observedPCM, globalLagFrames: time.globalLagFrames, configuration: envelopeConfiguration, chunkFrames: chunkFrames)
        let receipt = productionGeneration.coordinatorReceipt
        let transport = Lane3TransportEvidenceReceipt(playbackGeneration: productionGeneration.activePlaybackGeneration, clickGeneration: productionGeneration.activeClickGeneration, transactionSerial: receipt.operationSerial, reason: productionGeneration.activeReason, gateValidatedCurrentBinding: productionGeneration.currentBindingValidated)
        let core = try Lane3IntegratedEvidenceAssembler.assemble(comparisonIntent: comparisonIntent, transport: transport, offline: offline, referencePCMFrameCount: referencePCM.frameCount, observedPCMFrameCount: observedPCM.frameCount, observedPCMSampleRate: observedPCM.sampleRate, expectedEventCount: expectedEventFrames.count, timeDomain: Lane3TimeDomainEvidenceSnapshot(report: time), spectral: Lane3SpectralEvidenceSnapshot(report: spectral))
        let envelope = Lane3EnvelopeEvidenceSnapshot(report: envelopeReport)
        try validateEnvelope(envelope, core: core)
        let identity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(reference: referencePCM, observed: observedPCM, chunkFrames: chunkFrames)
        let runBinding = Lane3LongTrackPCMIdentityHasher.digestFields([offline.fixtureID,offline.controlSignatureFNV1A64,String(productionGeneration.activePlaybackGeneration),String(productionGeneration.activeClickGeneration),productionGeneration.activeReason,String(receipt.operationSerial),identity.algorithm,identity.referenceDigestSHA256,identity.observedDigestSHA256,String(time.globalLagFrames),String(envelope.windowsAnalyzed),String(expectedEventFrames.count)])
        let report = Lane3UnifiedEvidenceReportV2(schemaVersion:2,evidenceScope:"LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY",fixtureID:offline.fixtureID,controlSignatureFNV1A64:offline.controlSignatureFNV1A64,comparisonIntent:comparisonIntent,productionGeneration:productionGeneration,recoveryLineage:recoveryLineage,pcmIdentity:identity,coreEvidence:core,envelope:envelope,runBindingSHA256:runBinding,sourceEvidenceScopes:core.sourceEvidenceScopes+[envelope.evidenceScope,recoveryLineage.evidenceScope,productionGeneration.evidenceScope,receipt.evidenceScope],readyForRealAudioReview:true,humanAudibilityClaimed:false,standardizedPerceptualMetricClaimed:false,formantPreservationClaimed:false,parityPromotionAllowed:false)
        let profile = try Lane3LongTrackEvidenceResourcePlanner.profile(
            channels: metadata.channels,
            chunkFrames: chunkFrames,
            timeConfiguration: timeConfiguration,
            spectralConfiguration: spectralConfiguration,
            envelopeConfiguration: envelopeConfiguration
        )
        return .init(reportV2:report,resourceProfile:profile,parityPromotionAllowed:false)
    }

    private static func validateProduction(_ p:Lane3ProductionGenerationEvidenceReceipt)throws{try Lane3ProductionGenerationEvidenceCapture.validateAuthorizingReceipt(p.coordinatorReceipt);let r=p.coordinatorReceipt;guard p.schemaVersion==1,p.evidenceScope=="LANE3_AW12_CURRENT_PRODUCTION_GENERATION_RECEIPT_NON_PARITY",p.snapshotOperationSerial==r.operationSerial,p.activePlaybackGeneration==r.playbackGeneration,p.activeClickGeneration==r.clickGeneration,p.activeReason==r.reason,p.currentBindingValidated,!p.parityPromotionAllowed else{throw Lane3LongTrackEvidenceError.invalidProductionGenerationReceipt}}
    private static func validateRecovery(_ r:Lane3CombinedRecoveryAW05Receipt,production p:Lane3ProductionGenerationEvidenceReceipt)throws{guard r.evidenceScope=="LANE3_AW05_TO_AW11_GENERATION_RECEIPT_NON_PARITY",r.playbackGeneration>0,r.clickGeneration>0,!r.parityPromotionAllowed else{throw Lane3LongTrackEvidenceError.invalidRecoveryLineageReceipt};guard r.playbackGeneration==p.activePlaybackGeneration,r.clickGeneration==p.activeClickGeneration else{throw Lane3LongTrackEvidenceError.generationLineageMismatch};guard r.reason.rawValue==p.activeReason else{throw Lane3LongTrackEvidenceError.reasonLineageMismatch}}
    private static func validateEnvelope(_ e:Lane3EnvelopeEvidenceSnapshot,core:Lane3IntegratedEvidenceReport)throws{guard e.evidenceScope=="LANE3_CEPSTRAL_ENVELOPE_FORMANT_PROXY_NON_PARITY" else{throw Lane3LongTrackEvidenceError.sourceEvidenceScopeRejected(e.evidenceScope)};guard !e.standardizedPerceptualClaimAllowed,!e.formantPreservationClaimAllowed,!e.componentParityPromotionAllowed else{throw Lane3LongTrackEvidenceError.componentClaimRejected};guard e.globalLagFramesApplied==core.timeDomain.globalLagFrames else{throw Lane3LongTrackEvidenceError.invalidMetric};guard e.windowsAnalyzed>0 else{throw Lane3LongTrackEvidenceError.noEnvelopeWindows};guard e.referenceNonFiniteSampleCount==0,e.observedNonFiniteSampleCount==0 else{throw Lane3LongTrackEvidenceError.nonFiniteEvidence(reference:e.referenceNonFiniteSampleCount,observed:e.observedNonFiniteSampleCount)};var m=[e.meanEnvelopeRMSEDB,e.p95EnvelopeRMSEDB,e.meanEnvelopeCorrelation,e.meanAbsoluteSpectralTiltDeltaDBPerOctave];if let x=e.medianAbsoluteFormantPeakErrorCents{m.append(x)};if let x=e.p95AbsoluteFormantPeakErrorCents{m.append(x)};guard e.cepstralCoefficientCount>0,m.allSatisfy(\.isFinite) else{throw Lane3LongTrackEvidenceError.invalidMetric}}
}
