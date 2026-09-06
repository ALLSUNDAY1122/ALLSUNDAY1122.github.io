import Foundation

@main
struct L3AW51PhysicalEvidenceSessionOrchestrationBenchmarkMain {
    static func main() {
        let iterations = 20_000
        let input = Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: "aw51-benchmark",
            appBuildCommitSHA: String(repeating: "a", count: 40),
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: "aw51-fixture",
            fixtureDurationSeconds: 1_800,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: "moises-current-iphone-aw51",
            currentMoisesVersion: "current",
            availableScenarioHarnesses: Lane3DeviceEvidenceScenario.allCases,
            timingInstrumentationReady: true,
            externalAudibleMarkerReady: true,
            candidateCaptureReady: true,
            currentMoisesCaptureReady: true,
            humanListeningReady: true,
            interruptionTriggerReady: true,
            processRSSSamplingReady: true,
            thermalSamplingReady: true,
            batterySamplingReady: true,
            batteryDrainMeasurementModeReady: true,
            currentMoisesResourceSamplingReady: true
        )

        var ordinalChecksum = 0
        let start = ContinuousClock.now
        for _ in 0..<iterations {
            let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(input: input)
            precondition(plan.sessionStartAllowed)
            precondition(plan.steps.count == 27)
            ordinalChecksum &+= plan.steps.reduce(0) { $0 &+ $1.ordinal }
        }
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000
        let microsecondsPerPlan = seconds * 1_000_000 / Double(iterations)

        // Keep the benchmark observable and prevent the plan from being optimized away.
        precondition(ordinalChecksum == iterations * 378)
        print(
            "L3-AW51 physical evidence session orchestration benchmark "
            + "iterations=\(iterations) stepsPerPlan=27 usPerPlan=\(microsecondsPerPlan) "
            + "physicalDeviceTimingClaim=false"
        )
    }
}
