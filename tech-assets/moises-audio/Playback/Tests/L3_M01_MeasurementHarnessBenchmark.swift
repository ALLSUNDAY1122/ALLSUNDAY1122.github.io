import Foundation

@main
struct L3M01MeasurementHarnessBenchmark {
    static func main() throws {
        let fixture = Lane3FixtureManifest(
            fixtureID: "benchmark-metadata-only",
            provenance: "benchmark metadata; not PARITY evidence",
            rights: .syntheticOnly,
            genre: "benchmark",
            durationSeconds: 10_800,
            sampleRate: 48_000,
            stemRoles: ["vocals", "drums", "bass", "other"],
            containsRealAudio: false
        )
        let loopExpected = (0..<1_000).map { 30.0 + Double($0) * 10.0 }
        let loopActual = loopExpected.enumerated().map { index, value in
            value + Double(index % 5) * 0.0001
        }
        let clickExpected = (0..<7_200).map { Double($0) * 0.5 }
        let clickActual = clickExpected.enumerated().map { index, value in
            value + Double(index % 3) * 0.0001
        }
        let playback = Lane3PlaybackMeasurementInput(
            stemOnsetSeconds: ["vocals": 10.0, "drums": 10.0007, "bass": 10.0009, "other": 10.0003],
            seekCommandSeconds: 20,
            firstPostSeekOutputSeconds: 20.04,
            loopTiming: Lane3TimingSeries(expectedSeconds: loopExpected, actualSeconds: loopActual),
            gainTransitions: [
                Lane3GainTransitionObservation(
                    transitionID: "benchmark",
                    maximumAbsoluteSampleStep: 0.1,
                    localRMS: 0.05,
                    settlingMilliseconds: 8,
                    audibleArtifactReviewed: false,
                    audibleArtifactPassed: nil
                )
            ]
        )
        let dsp = Lane3DSPMeasurementInput(
            metronomeTiming: Lane3TimingSeries(expectedSeconds: clickExpected, actualSeconds: clickActual),
            countInTiming: Lane3TimingSeries(
                expectedSeconds: [-2.0, -1.5, -1.0, -0.5],
                actualSeconds: [-1.9998, -1.4998, -0.9998, -0.4998]
            ),
            practice: Lane3PracticeDSPObservation(
                requestedTempoRatio: 0.9,
                measuredTempoRatio: 0.9004,
                requestedPitchSemitones: 2,
                measuredPitchSemitones: 2.02,
                renderLatencyMilliseconds: 32,
                transientPeakLossDB: 1.2,
                noiseFloorIncreaseDB: 2.5,
                artifactListeningReviewed: false,
                artifactListeningPassed: nil
            )
        )

        var samples: [Double] = []
        samples.reserveCapacity(200)
        for index in 0..<200 {
            let start = ContinuousClock.now
            let report = try Lane3DeviceMeasurementHarness.evaluate(
                runID: "benchmark-\(index)",
                capturedAtISO8601: "2026-08-22T17:20:00+09:00",
                captureSurface: .harnessOnly,
                fixture: fixture,
                actualAudioCaptured: false,
                referenceDifferentialCompleted: false,
                playback: playback,
                dsp: dsp
            )
            precondition(!report.parityEvidenceEligible)
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            samples.append(
                Double(components.seconds) * 1_000
                    + Double(components.attoseconds) / 1e15
            )
        }
        samples.sort()
        func percentile(_ p: Double) -> Double {
            let index = min(
                samples.count - 1,
                Int((Double(samples.count - 1) * p).rounded())
            )
            return samples[index]
        }
        print(
            String(
                format: "L3-M01 harness benchmark: loops=1000 clicks=7200 runs=200 median_ms=%.4f p95_ms=%.4f p99_ms=%.4f max_ms=%.4f",
                percentile(0.5),
                percentile(0.95),
                percentile(0.99),
                samples.last ?? 0
            )
        )
    }
}
