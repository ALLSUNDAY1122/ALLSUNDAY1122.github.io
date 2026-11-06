import Foundation

@main
struct BenchmarkMain {
    static func main() throws {
        let transport = Lane3TransportEvidenceReceipt(
            playbackGeneration: 10, clickGeneration: 20, transactionSerial: 5,
            reason: "tempoChange", gateValidatedCurrentBinding: true
        )
        let offline = Lane3OfflineEvidenceReceipt(
            fixtureID: "bench", controlSignatureFNV1A64: "0123456789abcdef",
            outputSampleRate: 48_000, plannedFrameCount: 2_880_000, renderedFrameCount: 2_880_000,
            clickEventCount: 8, actualAudioCaptured: true, outputFileWritten: true,
            eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
            componentParityPromotionAllowed: false
        )
        let time = Lane3TimeDomainEvidenceSnapshot(
            evidenceScope: "LANE3_PCM_DIFFERENTIAL_NON_PARITY",
            referenceFrameCount: 2_880_128, observedFrameCount: 2_880_000,
            globalLagFrames: 128, globalNormalizedCorrelation: 0.999,
            onsetObservationCount: 8, maximumAbsoluteResidualOnsetErrorFrames: 1,
            unexpectedDiscontinuityCount: 0, maximumUnexpectedDerivative: 0.02,
            observedClippedSampleCount: 0, observedNonFiniteSampleCount: 0,
            componentParityPromotionAllowed: false
        )

        let rounds = 20
        let operations = 100_000
        var durations: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<operations {
                let semitones = Double(((index + round) % 25) - 12)
                let ratio = pow(2, semitones / 12)
                let spectral = Lane3SpectralEvidenceSnapshot(
                    evidenceScope: "LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY",
                    globalLagFramesApplied: 128, windowsAnalyzed: 256,
                    expectedFrequencyRatio: ratio, estimatedFrequencyRatio: ratio,
                    frequencyRatioErrorCents: 0, p95AbsoluteSpectralPeakRatioErrorCents: 2,
                    meanLogSpectralDistanceDB: 0.5, meanAbsoluteHighBandEnergyDeltaDB: 0.1,
                    meanBandEnergyCosineDistance: 0.01, rmsEnvelopeCorrelation: 0.999,
                    meanSpectralFluxDelta: 0.01, referenceNonFiniteSampleCount: 0,
                    observedNonFiniteSampleCount: 0, perceptualClaimAllowed: false,
                    componentParityPromotionAllowed: false
                )
                let report = try Lane3IntegratedEvidenceAssembler.assemble(
                    comparisonIntent: .sourceToPitchTransformed(semitones: semitones),
                    transport: transport, offline: offline,
                    referencePCMFrameCount: 2_880_128, observedPCMFrameCount: 2_880_000,
                    observedPCMSampleRate: 48_000, expectedEventCount: 8,
                    timeDomain: time, spectral: spectral
                )
                checksum &+= report.transport.playbackGeneration
                checksum &+= UInt64(report.spectral.windowsAnalyzed)
            }
            durations.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }

        let sorted = durations.sorted()
        let median = (sorted[9] + sorted[10]) / 2
        print(String(format: "median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%llu", median, sorted[18], sorted[19], checksum))
    }
}
