import Foundation

public extension Lane3TransportEvidenceReceipt {
    static func capture(
        playbackToken: PlaybackTransportRescheduleToken,
        dspGate: PracticeDSPTransportRescheduleGate,
        binding: PracticeDSPTransportGenerationBinding
    ) throws -> Lane3TransportEvidenceReceipt {
        guard playbackToken.generation == binding.playbackGeneration,
              playbackToken.reason.rawValue == binding.reason.rawValue else {
            throw Lane3IntegratedEvidenceError.invalidTransportReceipt
        }
        try dspGate.validateReplacement(binding: binding)
        return Lane3TransportEvidenceReceipt(
            playbackGeneration: binding.playbackGeneration,
            clickGeneration: binding.clickGeneration,
            transactionSerial: dspGate.transactionSerial,
            reason: binding.reason.rawValue,
            gateValidatedCurrentBinding: true
        )
    }
}

public extension Lane3TimeDomainEvidenceSnapshot {
    init(report: Lane3PCMDifferentialReport) {
        self.init(
            evidenceScope: report.evidenceScope,
            referenceFrameCount: report.referenceFrameCount,
            observedFrameCount: report.observedFrameCount,
            globalLagFrames: report.globalLagFrames,
            globalNormalizedCorrelation: report.globalNormalizedCorrelation,
            onsetObservationCount: report.onsetObservations.count,
            maximumAbsoluteResidualOnsetErrorFrames: report.maximumAbsoluteResidualOnsetErrorFrames,
            unexpectedDiscontinuityCount: report.unexpectedDiscontinuityCount,
            maximumUnexpectedDerivative: report.maximumUnexpectedDerivative,
            observedClippedSampleCount: report.observedClippedSampleCount,
            observedNonFiniteSampleCount: report.observedNonFiniteSampleCount,
            componentParityPromotionAllowed: report.parityPromotionAllowed
        )
    }
}

public extension Lane3SpectralEvidenceSnapshot {
    init(report: Lane3SpectralDifferentialReport) {
        self.init(
            evidenceScope: report.evidenceScope,
            globalLagFramesApplied: report.globalLagFramesApplied,
            windowsAnalyzed: report.windowsAnalyzed,
            expectedFrequencyRatio: report.expectedFrequencyRatio,
            estimatedFrequencyRatio: report.estimatedFrequencyRatio,
            frequencyRatioErrorCents: report.frequencyRatioErrorCents,
            p95AbsoluteSpectralPeakRatioErrorCents: report.p95AbsoluteSpectralPeakRatioErrorCents,
            meanLogSpectralDistanceDB: report.meanLogSpectralDistanceDB,
            meanAbsoluteHighBandEnergyDeltaDB: report.meanAbsoluteHighBandEnergyDeltaDB,
            meanBandEnergyCosineDistance: report.meanBandEnergyCosineDistance,
            rmsEnvelopeCorrelation: report.rmsEnvelopeCorrelation,
            meanSpectralFluxDelta: report.meanSpectralFluxDelta,
            referenceNonFiniteSampleCount: report.referenceNonFiniteSampleCount,
            observedNonFiniteSampleCount: report.observedNonFiniteSampleCount,
            perceptualClaimAllowed: report.perceptualClaimAllowed,
            componentParityPromotionAllowed: report.parityPromotionAllowed
        )
    }
}

public enum Lane3IntegratedEvidencePipeline {
    public static func analyze(
        playbackToken: PlaybackTransportRescheduleToken,
        dspGate: PracticeDSPTransportRescheduleGate,
        binding: PracticeDSPTransportGenerationBinding,
        offline: Lane3OfflineEvidenceReceipt,
        referencePCM: Lane3PCMBufferDescriptor,
        observedPCM: Lane3PCMBufferDescriptor,
        expectedEventFrames: [Int64],
        comparisonIntent: Lane3EvidenceComparisonIntent,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration()
    ) throws -> Lane3IntegratedEvidenceReport {
        let transport = try Lane3TransportEvidenceReceipt.capture(
            playbackToken: playbackToken,
            dspGate: dspGate,
            binding: binding
        )
        let timeReport = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: referencePCM,
            observed: observedPCM,
            expectedEventFrames: expectedEventFrames,
            configuration: timeConfiguration
        )
        let spectralReport = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: referencePCM,
            observed: observedPCM,
            globalLagFrames: timeReport.globalLagFrames,
            configuration: spectralConfiguration
        )
        return try Lane3IntegratedEvidenceAssembler.assemble(
            comparisonIntent: comparisonIntent,
            transport: transport,
            offline: offline,
            referencePCMFrameCount: referencePCM.frameCount,
            observedPCMFrameCount: observedPCM.frameCount,
            observedPCMSampleRate: observedPCM.sampleRate,
            expectedEventCount: expectedEventFrames.count,
            timeDomain: Lane3TimeDomainEvidenceSnapshot(report: timeReport),
            spectral: Lane3SpectralEvidenceSnapshot(report: spectralReport)
        )
    }
}

#if canImport(AVFAudio)
public extension Lane3OfflineEvidenceReceipt {
    static func capture(
        appleResult: Lane3AppleOfflineRenderResult
    ) throws -> Lane3OfflineEvidenceReceipt {
        let plan = appleResult.plan
        let manifest = appleResult.executionManifest
        let observation = appleResult.observation
        guard plan.fixtureID == manifest.fixtureID,
              plan.fixtureID == observation.fixtureID,
              plan.controlSignatureFNV1A64 == manifest.controlSignatureFNV1A64,
              plan.controlSignatureFNV1A64 == observation.controlSignatureFNV1A64,
              plan.outputFrameCount == manifest.outputFrameCount,
              plan.outputFrameCount == observation.outputFrameCount,
              plan.outputFrameCount == appleResult.renderedFrameCount,
              abs(plan.outputSampleRate - manifest.outputSampleRate) <= 0.5,
              !manifest.parityPromotionAllowed,
              !appleResult.parityPromotionAllowed else {
            throw Lane3IntegratedEvidenceError.invalidOfflineReceipt
        }
        return Lane3OfflineEvidenceReceipt(
            fixtureID: plan.fixtureID,
            controlSignatureFNV1A64: plan.controlSignatureFNV1A64,
            outputSampleRate: plan.outputSampleRate,
            plannedFrameCount: plan.outputFrameCount,
            renderedFrameCount: appleResult.renderedFrameCount,
            clickEventCount: manifest.clickEventCount,
            actualAudioCaptured: observation.actualAudioCaptured,
            outputFileWritten: appleResult.outputFileWritten,
            eventEvidenceScope: appleResult.eventEvidenceScope,
            componentParityPromotionAllowed: appleResult.parityPromotionAllowed
        )
    }
}

public extension Lane3IntegratedEvidencePipeline {
    static func analyzeAppleOfflineResult(
        playbackToken: PlaybackTransportRescheduleToken,
        dspGate: PracticeDSPTransportRescheduleGate,
        binding: PracticeDSPTransportGenerationBinding,
        appleResult: Lane3AppleOfflineRenderResult,
        referencePCM: Lane3PCMBufferDescriptor,
        observedPCM: Lane3PCMBufferDescriptor,
        comparisonIntent: Lane3EvidenceComparisonIntent,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration()
    ) throws -> Lane3IntegratedEvidenceReport {
        let expectedClickFrames = appleResult.plan.events.compactMap { event -> Int64? in
            switch event.kind {
            case .countInClick, .metronomeClick:
                return event.frame
            default:
                return nil
            }
        }
        return try analyze(
            playbackToken: playbackToken,
            dspGate: dspGate,
            binding: binding,
            offline: try Lane3OfflineEvidenceReceipt.capture(appleResult: appleResult),
            referencePCM: referencePCM,
            observedPCM: observedPCM,
            expectedEventFrames: expectedClickFrames,
            comparisonIntent: comparisonIntent,
            timeConfiguration: timeConfiguration,
            spectralConfiguration: spectralConfiguration
        )
    }
}
#endif
