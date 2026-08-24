import Foundation

private let aw24BenchHashA = String(repeating: "a", count: 64)
private let aw24BenchHashB = String(repeating: "b", count: 64)
private let aw24BenchBuildSHA = String(repeating: "c", count: 40)

private func aw24BenchCase(
    _ scenario: Lane3DeviceEvidenceScenario
) -> Lane3DeviceEvidenceCaseReceipt {
    let repetitions = scenario == .longTrackStability
        ? 1
        : (scenario == .interruptionRecovery ? 5 : 10)
    return Lane3DeviceEvidenceCaseReceipt(
        scenario: scenario,
        fixtureID: "fixture-\(scenario.rawValue)",
        controlSignatureFNV1A64: "1234abcd",
        aw13RunBindingSHA256: aw24BenchHashA,
        candidateCaptureSHA256: aw24BenchHashA,
        currentMoisesCaptureSHA256: aw24BenchHashB,
        repetitionsCompleted: repetitions,
        successfulRepetitions: repetitions,
        observedDurationSeconds: scenario == .longTrackStability ? 1_900 : 30,
        realAudio: true,
        rightsClearedFixture: true,
        currentMoisesCompared: true,
        timing: Lane3DeviceEvidenceTimingSummary(
            samples: max(1, repetitions),
            p50Milliseconds: 4,
            p95Milliseconds: 8,
            maxMilliseconds: 10
        ),
        health: Lane3DeviceEvidenceRuntimeHealth(
            unscopedBackendApplyCalls: 0,
            unscopedClickInvalidationCalls: 0,
            telemetryCounterOverflowed: false,
            clickPopEvents: 0,
            desyncEvents: 0,
            underrunEvents: 0,
            nonFiniteSampleEvents: 0
        )
    )
}

@main
struct L3AW24DeviceEvidenceBundleBenchmark {
    static func main() {
        let evidenceCases = Lane3DeviceEvidenceScenario.allCases.map { aw24BenchCase($0) }
        let reviews = evidenceCases.map {
            Lane3DeviceListeningReview(
                scenario: $0.scenario,
                caseBindingSHA256: $0.caseBindingSHA256,
                listeningPasses: 3,
                obviousInferiorityObserved: false,
                clickPopObserved: false,
                warbleInferiorityObserved: false,
                phasinessInferiorityObserved: false,
                formantDamageInferiorityObserved: false
            )
        }
        let bundle = Lane3DeviceEvidenceBundle(
            appBuildCommitSHA: aw24BenchBuildSHA,
            deviceModel: "iPhone17,1",
            osVersion: "iOS-test",
            audioRoute: .wiredHeadphones,
            physicalDevice: true,
            selectedXcodeBuild: true,
            currentMoisesReferenceSnapshotID: "moises-current-ios-snapshot",
            currentMoisesVersion: "reference-version",
            cases: evidenceCases,
            listeningReviews: reviews
        )

        let rounds = 20
        let validationsPerRound = 1_000
        var durations: [Double] = []
        var checksum = 0
        for _ in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<validationsPerRound {
                let report = Lane3DeviceEvidenceValidator.validate(bundle)
                precondition(report.readyForHQParityReview)
                checksum &+= report.issues.count + bundle.cases.count
            }
            let end = DispatchTime.now().uptimeNanoseconds
            durations.append(Double(end - start) / 1_000_000)
        }

        let sorted = durations.sorted()
        let median = sorted[rounds / 2]
        let p95 = sorted[Int((Double(rounds) * 0.95).rounded(.up)) - 1]
        let maxValue = sorted.last!
        print(String(
            format: "L3-AW24 benchmark PASS rounds=%d validationsPerRound=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%d",
            rounds,
            validationsPerRound,
            median,
            p95,
            maxValue,
            checksum
        ))
    }
}
