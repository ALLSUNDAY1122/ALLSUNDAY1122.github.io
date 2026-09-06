import Foundation

func expectError(_ body: () throws -> Void) {
    do { try body(); fatalError("expected error") } catch { }
}

let transport = Lane3TransportEvidenceReceipt(
    playbackGeneration: 12, clickGeneration: 27, transactionSerial: 9,
    reason: "tempoChange", gateValidatedCurrentBinding: true
)
let offline = Lane3OfflineEvidenceReceipt(
    fixtureID: "aw09-fixture", controlSignatureFNV1A64: "0123456789abcdef",
    outputSampleRate: 48_000, plannedFrameCount: 96_000, renderedFrameCount: 96_000,
    clickEventCount: 4, actualAudioCaptured: true, outputFileWritten: true,
    eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
    componentParityPromotionAllowed: false
)
let time = Lane3TimeDomainEvidenceSnapshot(
    evidenceScope: "LANE3_PCM_DIFFERENTIAL_NON_PARITY",
    referenceFrameCount: 96_137, observedFrameCount: 96_000, globalLagFrames: 137,
    globalNormalizedCorrelation: 0.998, onsetObservationCount: 4,
    maximumAbsoluteResidualOnsetErrorFrames: 1, unexpectedDiscontinuityCount: 0,
    maximumUnexpectedDerivative: 0.04, observedClippedSampleCount: 0,
    observedNonFiniteSampleCount: 0, componentParityPromotionAllowed: false
)

func spectral(
    lag: Int = 137,
    ratio: Double = 2,
    nonFinite: Int64 = 0,
    perceptualClaim: Bool = false
) -> Lane3SpectralEvidenceSnapshot {
    Lane3SpectralEvidenceSnapshot(
        evidenceScope: "LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY",
        globalLagFramesApplied: lag, windowsAnalyzed: 120,
        expectedFrequencyRatio: ratio, estimatedFrequencyRatio: ratio,
        frequencyRatioErrorCents: 0, p95AbsoluteSpectralPeakRatioErrorCents: 3.2,
        meanLogSpectralDistanceDB: 1.3, meanAbsoluteHighBandEnergyDeltaDB: 0.4,
        meanBandEnergyCosineDistance: 0.02, rmsEnvelopeCorrelation: 0.995,
        meanSpectralFluxDelta: 0.01, referenceNonFiniteSampleCount: 0,
        observedNonFiniteSampleCount: nonFinite, perceptualClaimAllowed: perceptualClaim,
        componentParityPromotionAllowed: false
    )
}

func assemble(
    intent: Lane3EvidenceComparisonIntent = .sourceToPitchTransformed(semitones: 12),
    transportReceipt: Lane3TransportEvidenceReceipt = transport,
    observedFrames: Int64 = 96_000,
    sampleRate: Double = 48_000,
    eventCount: Int = 4,
    timeSnapshot: Lane3TimeDomainEvidenceSnapshot = time,
    spectralSnapshot: Lane3SpectralEvidenceSnapshot = spectral()
) throws -> Lane3IntegratedEvidenceReport {
    try Lane3IntegratedEvidenceAssembler.assemble(
        comparisonIntent: intent, transport: transportReceipt, offline: offline,
        referencePCMFrameCount: 96_137, observedPCMFrameCount: observedFrames,
        observedPCMSampleRate: sampleRate, expectedEventCount: eventCount,
        timeDomain: timeSnapshot, spectral: spectralSnapshot
    )
}

let report = try assemble()
precondition(report.evidenceScope == "LANE3_INTEGRATED_PLAYBACK_DSP_EVIDENCE_NON_PARITY")
precondition(report.readyForRealAudioReview)
precondition(!report.parityPromotionAllowed)
precondition(!report.humanAudibilityClaimed)
precondition(!report.standardizedPerceptualMetricClaimed)
precondition(try JSONDecoder().decode(Lane3IntegratedEvidenceReport.self, from: JSONEncoder().encode(report)) == report)

expectError {
    _ = try assemble(transportReceipt: Lane3TransportEvidenceReceipt(
        playbackGeneration: 12, clickGeneration: 27, transactionSerial: 9,
        reason: "tempoChange", gateValidatedCurrentBinding: false
    ))
}
expectError { _ = try assemble(observedFrames: 95_999) }
expectError { _ = try assemble(eventCount: 3) }
expectError { _ = try assemble(spectralSnapshot: spectral(lag: 136)) }
expectError { _ = try assemble(intent: .sourceToTempoTransformed) }
expectError { _ = try assemble(sampleRate: 44_100) }
expectError { _ = try assemble(spectralSnapshot: spectral(nonFinite: 1)) }
expectError { _ = try assemble(spectralSnapshot: spectral(perceptualClaim: true)) }

let badTime = Lane3TimeDomainEvidenceSnapshot(
    evidenceScope: time.evidenceScope,
    referenceFrameCount: time.referenceFrameCount,
    observedFrameCount: time.observedFrameCount,
    globalLagFrames: time.globalLagFrames,
    globalNormalizedCorrelation: time.globalNormalizedCorrelation,
    onsetObservationCount: 3,
    maximumAbsoluteResidualOnsetErrorFrames: time.maximumAbsoluteResidualOnsetErrorFrames,
    unexpectedDiscontinuityCount: time.unexpectedDiscontinuityCount,
    maximumUnexpectedDerivative: time.maximumUnexpectedDerivative,
    observedClippedSampleCount: time.observedClippedSampleCount,
    observedNonFiniteSampleCount: 0,
    componentParityPromotionAllowed: false
)
expectError { _ = try assemble(timeSnapshot: badTime) }

for index in 0..<200_000 {
    let semitones = Double((index % 49) - 24) / 2
    let ratio = pow(2, semitones / 12)
    _ = try assemble(
        intent: .sourceToPitchTransformed(semitones: semitones),
        spectralSnapshot: spectral(ratio: ratio)
    )
}

print("L3-AW09 integrated evidence assembler self-test PASS")
