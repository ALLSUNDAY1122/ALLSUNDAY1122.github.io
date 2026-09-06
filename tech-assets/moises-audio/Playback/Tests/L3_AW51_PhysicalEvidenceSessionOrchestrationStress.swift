import Foundation

@main
struct L3AW51PhysicalEvidenceSessionOrchestrationStressMain {
    static func main() {
        var readyCells = 0
        var rejectedCells = 0

        for index in 0..<1_000 {
            let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
                input: makeInput(sessionSuffix: "ready-\(index)")
            )
            precondition(plan.sessionStartAllowed)
            precondition(plan.preflightIssues.isEmpty)
            precondition(plan.steps.count == 27)
            precondition(plan.targetedParityRows.count == 8)
            precondition(!plan.parityPromotionAllowed)
            readyCells += 1
        }

        for scenario in Lane3DeviceEvidenceScenario.allCases {
            let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
                input: makeInput(sessionSuffix: "missing-\(scenario.rawValue)", missingScenario: scenario)
            )
            precondition(!plan.sessionStartAllowed)
            precondition(plan.preflightIssues.contains {
                $0.kind == .missingScenarioHarness && $0.scenario == scenario
            })
            rejectedCells += 1
        }

        // Thirteen independent physical-session prerequisites are toggled off one at a time over
        // one hundred rounds. Every cell must remain fail-closed.
        for round in 0..<100 {
            for disabledCapability in 0..<13 {
                let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
                    input: makeInput(
                        sessionSuffix: "cap-\(round)-\(disabledCapability)",
                        disabledCapability: disabledCapability
                    )
                )
                precondition(!plan.sessionStartAllowed)
                precondition(!plan.preflightIssues.isEmpty)
                precondition(!plan.parityPromotionAllowed)
                rejectedCells += 1
            }
        }

        let bluetooth = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makeInput(sessionSuffix: "bluetooth", audioRoute: .bluetoothA2DP)
        )
        precondition(!bluetooth.sessionStartAllowed)
        precondition(bluetooth.preflightIssues.contains { $0.kind == .timingRouteUnsupported })
        rejectedCells += 1

        let shortTrack = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makeInput(sessionSuffix: "short", fixtureDurationSeconds: 1_799.999)
        )
        precondition(!shortTrack.sessionStartAllowed)
        precondition(shortTrack.preflightIssues.contains { $0.kind == .insufficientLongTrackFixture })
        rejectedCells += 1

        let unsafePrivacy = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makeInput(
                sessionSuffix: "privacy",
                privacy: Lane3DeviceEvidencePrivacySnapshot(filePathCaptured: true)
            )
        )
        precondition(!unsafePrivacy.sessionStartAllowed)
        precondition(unsafePrivacy.preflightIssues.contains { $0.kind == .privacyBoundaryViolation })
        rejectedCells += 1

        let badSHA = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makeInput(sessionSuffix: "bad-sha", appBuildCommitSHA: String(repeating: "A", count: 40))
        )
        precondition(!badSHA.sessionStartAllowed)
        precondition(badSHA.preflightIssues.contains { $0.kind == .invalidBuildCommitSHA })
        rejectedCells += 1

        precondition(readyCells == 1_000)
        precondition(rejectedCells == 1_312)
        print("L3-AW51 physical evidence session preflight stress PASS readyCells=\(readyCells) rejectedCells=\(rejectedCells)")
    }

    private static func makeInput(
        sessionSuffix: String,
        missingScenario: Lane3DeviceEvidenceScenario? = nil,
        disabledCapability: Int? = nil,
        audioRoute: Lane3DeviceEvidenceAudioRoute = .wiredHeadphones,
        fixtureDurationSeconds: Double = 1_800,
        privacy: Lane3DeviceEvidencePrivacySnapshot = Lane3DeviceEvidencePrivacySnapshot(),
        appBuildCommitSHA: String = String(repeating: "a", count: 40)
    ) -> Lane3PhysicalEvidenceSessionPreflightInput {
        let scenarios = Lane3DeviceEvidenceScenario.allCases.filter { $0 != missingScenario }
        return Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: "aw51-\(sessionSuffix)",
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: audioRoute,
            physicalIPhone: disabledCapability != 11,
            selectedXcodeBuild: disabledCapability != 12,
            fixtureID: "aw51-fixture",
            fixtureDurationSeconds: fixtureDurationSeconds,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: "moises-current-iphone-aw51",
            currentMoisesVersion: "current",
            privacy: privacy,
            availableScenarioHarnesses: scenarios,
            timingInstrumentationReady: disabledCapability != 0,
            externalAudibleMarkerReady: disabledCapability != 1,
            candidateCaptureReady: disabledCapability != 2,
            currentMoisesCaptureReady: disabledCapability != 3,
            humanListeningReady: disabledCapability != 4,
            interruptionTriggerReady: disabledCapability != 5,
            processRSSSamplingReady: disabledCapability != 6,
            thermalSamplingReady: disabledCapability != 7,
            batterySamplingReady: disabledCapability != 8,
            batteryDrainMeasurementModeReady: disabledCapability != 9,
            currentMoisesResourceSamplingReady: disabledCapability != 10
        )
    }
}
