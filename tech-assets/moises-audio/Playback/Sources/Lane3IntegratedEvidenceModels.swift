import Foundation

public enum Lane3IntegratedEvidenceError: Error, Equatable, Sendable {
    case invalidTransportReceipt
    case invalidOfflineReceipt
    case outputSampleRateMismatch(expected: Double, actual: Double)
    case renderedFrameCountMismatch(expected: Int64, actual: Int64)
    case timeDomainFrameCountMismatch
    case eventCountMismatch(expected: Int, actual: Int)
    case onsetObservationCountMismatch(expected: Int, actual: Int)
    case alignmentMismatch(timeLag: Int, spectralLag: Int)
    case expectedFrequencyRatioMismatch(expected: Double, actual: Double)
    case nonFiniteEvidence(reference: Int64, observed: Int64)
    case sourceEvidenceScopeRejected(String)
    case componentClaimRejected
    case noSpectralWindows
    case invalidMetric
}

public enum Lane3EvidenceComparisonIntent: Equatable, Codable, Sendable {
    case sourceToTempoTransformed
    case sourceToPitchTransformed(semitones: Double)
    case peerSameControls

    public var expectedFrequencyRatio: Double {
        switch self {
        case .sourceToTempoTransformed, .peerSameControls:
            return 1
        case .sourceToPitchTransformed(let semitones):
            return pow(2, semitones / 12)
        }
    }
}

public struct Lane3TransportEvidenceReceipt: Equatable, Codable, Sendable {
    public let playbackGeneration: UInt64
    public let clickGeneration: UInt64
    public let transactionSerial: UInt64
    public let reason: String
    public let gateValidatedCurrentBinding: Bool

    public init(playbackGeneration: UInt64, clickGeneration: UInt64, transactionSerial: UInt64, reason: String, gateValidatedCurrentBinding: Bool) {
        self.playbackGeneration = playbackGeneration
        self.clickGeneration = clickGeneration
        self.transactionSerial = transactionSerial
        self.reason = reason
        self.gateValidatedCurrentBinding = gateValidatedCurrentBinding
    }
}

public struct Lane3OfflineEvidenceReceipt: Equatable, Codable, Sendable {
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let outputSampleRate: Double
    public let plannedFrameCount: Int64
    public let renderedFrameCount: Int64
    public let clickEventCount: Int
    public let actualAudioCaptured: Bool
    public let outputFileWritten: Bool
    public let eventEvidenceScope: String
    public let componentParityPromotionAllowed: Bool

    public init(fixtureID: String, controlSignatureFNV1A64: String, outputSampleRate: Double, plannedFrameCount: Int64, renderedFrameCount: Int64, clickEventCount: Int, actualAudioCaptured: Bool, outputFileWritten: Bool, eventEvidenceScope: String, componentParityPromotionAllowed: Bool) {
        self.fixtureID = fixtureID
        self.controlSignatureFNV1A64 = controlSignatureFNV1A64
        self.outputSampleRate = outputSampleRate
        self.plannedFrameCount = plannedFrameCount
        self.renderedFrameCount = renderedFrameCount
        self.clickEventCount = clickEventCount
        self.actualAudioCaptured = actualAudioCaptured
        self.outputFileWritten = outputFileWritten
        self.eventEvidenceScope = eventEvidenceScope
        self.componentParityPromotionAllowed = componentParityPromotionAllowed
    }
}

public struct Lane3TimeDomainEvidenceSnapshot: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let referenceFrameCount: Int64
    public let observedFrameCount: Int64
    public let globalLagFrames: Int
    public let globalNormalizedCorrelation: Double
    public let onsetObservationCount: Int
    public let maximumAbsoluteResidualOnsetErrorFrames: Int64?
    public let unexpectedDiscontinuityCount: Int
    public let maximumUnexpectedDerivative: Double
    public let observedClippedSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let componentParityPromotionAllowed: Bool

    public init(evidenceScope: String, referenceFrameCount: Int64, observedFrameCount: Int64, globalLagFrames: Int, globalNormalizedCorrelation: Double, onsetObservationCount: Int, maximumAbsoluteResidualOnsetErrorFrames: Int64?, unexpectedDiscontinuityCount: Int, maximumUnexpectedDerivative: Double, observedClippedSampleCount: Int64, observedNonFiniteSampleCount: Int64, componentParityPromotionAllowed: Bool) {
        self.evidenceScope = evidenceScope
        self.referenceFrameCount = referenceFrameCount
        self.observedFrameCount = observedFrameCount
        self.globalLagFrames = globalLagFrames
        self.globalNormalizedCorrelation = globalNormalizedCorrelation
        self.onsetObservationCount = onsetObservationCount
        self.maximumAbsoluteResidualOnsetErrorFrames = maximumAbsoluteResidualOnsetErrorFrames
        self.unexpectedDiscontinuityCount = unexpectedDiscontinuityCount
        self.maximumUnexpectedDerivative = maximumUnexpectedDerivative
        self.observedClippedSampleCount = observedClippedSampleCount
        self.observedNonFiniteSampleCount = observedNonFiniteSampleCount
        self.componentParityPromotionAllowed = componentParityPromotionAllowed
    }
}

public struct Lane3SpectralEvidenceSnapshot: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let globalLagFramesApplied: Int
    public let windowsAnalyzed: Int
    public let expectedFrequencyRatio: Double
    public let estimatedFrequencyRatio: Double
    public let frequencyRatioErrorCents: Double
    public let p95AbsoluteSpectralPeakRatioErrorCents: Double?
    public let meanLogSpectralDistanceDB: Double
    public let meanAbsoluteHighBandEnergyDeltaDB: Double
    public let meanBandEnergyCosineDistance: Double
    public let rmsEnvelopeCorrelation: Double
    public let meanSpectralFluxDelta: Double
    public let referenceNonFiniteSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let perceptualClaimAllowed: Bool
    public let componentParityPromotionAllowed: Bool

    public init(evidenceScope: String, globalLagFramesApplied: Int, windowsAnalyzed: Int, expectedFrequencyRatio: Double, estimatedFrequencyRatio: Double, frequencyRatioErrorCents: Double, p95AbsoluteSpectralPeakRatioErrorCents: Double?, meanLogSpectralDistanceDB: Double, meanAbsoluteHighBandEnergyDeltaDB: Double, meanBandEnergyCosineDistance: Double, rmsEnvelopeCorrelation: Double, meanSpectralFluxDelta: Double, referenceNonFiniteSampleCount: Int64, observedNonFiniteSampleCount: Int64, perceptualClaimAllowed: Bool, componentParityPromotionAllowed: Bool) {
        self.evidenceScope = evidenceScope
        self.globalLagFramesApplied = globalLagFramesApplied
        self.windowsAnalyzed = windowsAnalyzed
        self.expectedFrequencyRatio = expectedFrequencyRatio
        self.estimatedFrequencyRatio = estimatedFrequencyRatio
        self.frequencyRatioErrorCents = frequencyRatioErrorCents
        self.p95AbsoluteSpectralPeakRatioErrorCents = p95AbsoluteSpectralPeakRatioErrorCents
        self.meanLogSpectralDistanceDB = meanLogSpectralDistanceDB
        self.meanAbsoluteHighBandEnergyDeltaDB = meanAbsoluteHighBandEnergyDeltaDB
        self.meanBandEnergyCosineDistance = meanBandEnergyCosineDistance
        self.rmsEnvelopeCorrelation = rmsEnvelopeCorrelation
        self.meanSpectralFluxDelta = meanSpectralFluxDelta
        self.referenceNonFiniteSampleCount = referenceNonFiniteSampleCount
        self.observedNonFiniteSampleCount = observedNonFiniteSampleCount
        self.perceptualClaimAllowed = perceptualClaimAllowed
        self.componentParityPromotionAllowed = componentParityPromotionAllowed
    }
}

public struct Lane3IntegratedEvidenceReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let comparisonIntent: Lane3EvidenceComparisonIntent
    public let transport: Lane3TransportEvidenceReceipt
    public let offline: Lane3OfflineEvidenceReceipt
    public let timeDomain: Lane3TimeDomainEvidenceSnapshot
    public let spectral: Lane3SpectralEvidenceSnapshot
    public let expectedEventCount: Int
    public let sourceEvidenceScopes: [String]
    public let readyForRealAudioReview: Bool
    public let humanAudibilityClaimed: Bool
    public let standardizedPerceptualMetricClaimed: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3IntegratedEvidenceAssembler {
    public static func assemble(
        comparisonIntent: Lane3EvidenceComparisonIntent,
        transport: Lane3TransportEvidenceReceipt,
        offline: Lane3OfflineEvidenceReceipt,
        referencePCMFrameCount: Int64,
        observedPCMFrameCount: Int64,
        observedPCMSampleRate: Double,
        expectedEventCount: Int,
        timeDomain: Lane3TimeDomainEvidenceSnapshot,
        spectral: Lane3SpectralEvidenceSnapshot,
        maximumExpectedRatioErrorCents: Double = 0.5
    ) throws -> Lane3IntegratedEvidenceReport {
        guard transport.playbackGeneration > 0,
              transport.clickGeneration > 0,
              transport.transactionSerial > 0,
              !transport.reason.isEmpty,
              transport.gateValidatedCurrentBinding else {
            throw Lane3IntegratedEvidenceError.invalidTransportReceipt
        }
        guard !offline.fixtureID.isEmpty,
              !offline.controlSignatureFNV1A64.isEmpty,
              offline.outputSampleRate.isFinite,
              offline.outputSampleRate > 0,
              offline.plannedFrameCount > 0,
              offline.renderedFrameCount > 0,
              offline.clickEventCount >= 0,
              offline.actualAudioCaptured,
              offline.plannedFrameCount == offline.renderedFrameCount else {
            throw Lane3IntegratedEvidenceError.invalidOfflineReceipt
        }
        guard offline.eventEvidenceScope == "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION" else {
            throw Lane3IntegratedEvidenceError.sourceEvidenceScopeRejected(offline.eventEvidenceScope)
        }
        guard timeDomain.evidenceScope == "LANE3_PCM_DIFFERENTIAL_NON_PARITY" else {
            throw Lane3IntegratedEvidenceError.sourceEvidenceScopeRejected(timeDomain.evidenceScope)
        }
        guard spectral.evidenceScope == "LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY" else {
            throw Lane3IntegratedEvidenceError.sourceEvidenceScopeRejected(spectral.evidenceScope)
        }
        guard !offline.componentParityPromotionAllowed,
              !timeDomain.componentParityPromotionAllowed,
              !spectral.componentParityPromotionAllowed,
              !spectral.perceptualClaimAllowed else {
            throw Lane3IntegratedEvidenceError.componentClaimRejected
        }
        guard observedPCMSampleRate.isFinite,
              abs(observedPCMSampleRate - offline.outputSampleRate) <= 0.5 else {
            throw Lane3IntegratedEvidenceError.outputSampleRateMismatch(expected: offline.outputSampleRate, actual: observedPCMSampleRate)
        }
        guard observedPCMFrameCount == offline.renderedFrameCount else {
            throw Lane3IntegratedEvidenceError.renderedFrameCountMismatch(expected: offline.renderedFrameCount, actual: observedPCMFrameCount)
        }
        guard referencePCMFrameCount > 0,
              timeDomain.referenceFrameCount == referencePCMFrameCount,
              timeDomain.observedFrameCount == observedPCMFrameCount else {
            throw Lane3IntegratedEvidenceError.timeDomainFrameCountMismatch
        }
        guard expectedEventCount == offline.clickEventCount else {
            throw Lane3IntegratedEvidenceError.eventCountMismatch(expected: offline.clickEventCount, actual: expectedEventCount)
        }
        guard timeDomain.onsetObservationCount == expectedEventCount else {
            throw Lane3IntegratedEvidenceError.onsetObservationCountMismatch(expected: expectedEventCount, actual: timeDomain.onsetObservationCount)
        }
        guard timeDomain.globalLagFrames == spectral.globalLagFramesApplied else {
            throw Lane3IntegratedEvidenceError.alignmentMismatch(timeLag: timeDomain.globalLagFrames, spectralLag: spectral.globalLagFramesApplied)
        }
        guard spectral.windowsAnalyzed > 0 else {
            throw Lane3IntegratedEvidenceError.noSpectralWindows
        }
        let expectedRatio = comparisonIntent.expectedFrequencyRatio
        guard expectedRatio.isFinite, expectedRatio > 0,
              spectral.expectedFrequencyRatio.isFinite, spectral.expectedFrequencyRatio > 0 else {
            throw Lane3IntegratedEvidenceError.invalidMetric
        }
        let ratioErrorCents = abs(1_200 * log2(spectral.expectedFrequencyRatio / expectedRatio))
        guard ratioErrorCents.isFinite, ratioErrorCents <= maximumExpectedRatioErrorCents else {
            throw Lane3IntegratedEvidenceError.expectedFrequencyRatioMismatch(expected: expectedRatio, actual: spectral.expectedFrequencyRatio)
        }
        guard timeDomain.observedNonFiniteSampleCount == 0,
              spectral.referenceNonFiniteSampleCount == 0,
              spectral.observedNonFiniteSampleCount == 0 else {
            throw Lane3IntegratedEvidenceError.nonFiniteEvidence(reference: spectral.referenceNonFiniteSampleCount, observed: max(timeDomain.observedNonFiniteSampleCount, spectral.observedNonFiniteSampleCount))
        }
        let finiteMetrics = [
            timeDomain.globalNormalizedCorrelation,
            timeDomain.maximumUnexpectedDerivative,
            spectral.estimatedFrequencyRatio,
            spectral.frequencyRatioErrorCents,
            spectral.meanLogSpectralDistanceDB,
            spectral.meanAbsoluteHighBandEnergyDeltaDB,
            spectral.meanBandEnergyCosineDistance,
            spectral.rmsEnvelopeCorrelation,
            spectral.meanSpectralFluxDelta
        ]
        guard finiteMetrics.allSatisfy(\.isFinite),
              maximumExpectedRatioErrorCents.isFinite,
              maximumExpectedRatioErrorCents >= 0 else {
            throw Lane3IntegratedEvidenceError.invalidMetric
        }

        return Lane3IntegratedEvidenceReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_INTEGRATED_PLAYBACK_DSP_EVIDENCE_NON_PARITY",
            fixtureID: offline.fixtureID,
            controlSignatureFNV1A64: offline.controlSignatureFNV1A64,
            comparisonIntent: comparisonIntent,
            transport: transport,
            offline: offline,
            timeDomain: timeDomain,
            spectral: spectral,
            expectedEventCount: expectedEventCount,
            sourceEvidenceScopes: [offline.eventEvidenceScope, timeDomain.evidenceScope, spectral.evidenceScope],
            readyForRealAudioReview: true,
            humanAudibilityClaimed: false,
            standardizedPerceptualMetricClaimed: false,
            parityPromotionAllowed: false
        )
    }
}
