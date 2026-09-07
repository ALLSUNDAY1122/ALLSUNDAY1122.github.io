import Foundation

@main
struct L3AW51PhysicalEvidenceSessionOrchestrationSelfTestMain {
    static func main() throws {
        let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(input: readyInput())
        precondition(plan.sessionStartAllowed)
        precondition(plan.preflightIssues.isEmpty)
        precondition(plan.steps.count == 27)
        precondition(plan.steps.map(\.ordinal) == Array(1...27))
        precondition(Set(plan.targetedParityRows) == Set([
            "MOI-P006", "MOI-P007", "MOI-P008", "MOI-P010",
            "MOI-P012", "MOI-P014", "MOI-P015", "MOI-P021"
        ]))
        precondition(!plan.parityPromotionAllowed)

        let bundle = makeBundle(fixtureID: plan.fixtureID)
        let traces = [
            makeTrace(subject: .candidate),
            makeTrace(subject: .currentMoisesReference)
        ]
        let completion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces
        )
        precondition(completion.baseline.readyForHQReview)
        precondition(completion.strictIssues.isEmpty)
        precondition(completion.readyForHQReview)
        precondition(!completion.parityPromotionAllowed)

        let fixtureMismatch = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: makeBundle(fixtureID: "wrong-fixture"),
            resourceTraces: traces
        )
        precondition(fixtureMismatch.baseline.readyForHQReview)
        precondition(fixtureMismatch.strictIssues.contains { $0.kind == .fixtureMismatch })
        precondition(!fixtureMismatch.readyForHQReview)

        let duplicateTrace = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces + [makeTrace(subject: .candidate)]
        )
        precondition(duplicateTrace.strictIssues.contains { $0.kind == .duplicateCandidateResourceTrace })
        precondition(!duplicateTrace.readyForHQReview)

        let negativeThermal = makeTrace(
            subject: .candidate,
            thermalNominalSamples: -1,
            thermalFairSamples: 61
        )
        let negativeThermalReport = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: [negativeThermal, makeTrace(subject: .currentMoisesReference)]
        )
        precondition(negativeThermalReport.baseline.readyForHQReview)
        precondition(negativeThermalReport.strictIssues.contains { $0.kind == .negativeThermalCounter })
        precondition(!negativeThermalReport.readyForHQReview)

        let blocked = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: readyInput(
                audioRoute: .bluetoothA2DP,
                fixtureDurationSeconds: 1_799,
                processRSSSamplingReady: false
            )
        )
        precondition(!blocked.sessionStartAllowed)
        precondition(blocked.preflightIssues.contains { $0.kind == .timingRouteUnsupported })
        precondition(blocked.preflightIssues.contains { $0.kind == .insufficientLongTrackFixture })
        precondition(blocked.preflightIssues.contains { $0.kind == .processRSSSamplerUnavailable })

        print("L3-AW51 physical evidence session orchestration self-test PASS steps=27 targetedRows=8 strictCompletion=true")
    }

    private static func readyInput(
        audioRoute: Lane3DeviceEvidenceAudioRoute = .wiredHeadphones,
        fixtureDurationSeconds: Double = 1_800,
        processRSSSamplingReady: Bool = true
    ) -> Lane3PhysicalEvidenceSessionPreflightInput {
        Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: "aw51-session-001",
            appBuildCommitSHA: String(repeating: "a", count: 40),
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: audioRoute,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: "aw51-fixture",
            fixtureDurationSeconds: fixtureDurationSeconds,
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
            processRSSSamplingReady: processRSSSamplingReady,
            thermalSamplingReady: true,
            batterySamplingReady: true,
            batteryDrainMeasurementModeReady: true,
            currentMoisesResourceSamplingReady: true
        )
    }

    private static func makeBundle(fixtureID: String) -> Lane3DeviceEvidenceBundle {
        let timing = Lane3DeviceEvidenceTimingSummary(
            samples: 10,
            p50Milliseconds: 1,
            p95Milliseconds: 2,
            maxMilliseconds: 3
        )
        let health = Lane3DeviceEvidenceRuntimeHealth(
            unscopedBackendApplyCalls: 0,
            unscopedClickInvalidationCalls: 0,
            telemetryCounterOverflowed: false,
            clickPopEvents: 0,
            desyncEvents: 0,
            underrunEvents: 0,
            nonFiniteSampleEvents: 0
        )
        let cases = Lane3DeviceEvidenceScenario.allCases.map { scenario -> Lane3DeviceEvidenceCaseReceipt in
            let repetitions: Int
            switch scenario {
            case .longTrackStability: repetitions = 1
            case .interruptionRecovery: repetitions = 5
            case .mixerGainRamp, .seekLoop, .tempo, .pitch, .metronome, .countIn: repetitions = 10
            }
            return Lane3DeviceEvidenceCaseReceipt(
                scenario: scenario,
                fixtureID: fixtureID,
                controlSignatureFNV1A64: String(repeating: "1", count: 16),
                aw13RunBindingSHA256: String(repeating: "2", count: 64),
                candidateCaptureSHA256: String(repeating: "3", count: 64),
                currentMoisesCaptureSHA256: String(repeating: "4", count: 64),
                repetitionsCompleted: repetitions,
                successfulRepetitions: repetitions,
                observedDurationSeconds: scenario == .longTrackStability ? 1_800 : 30,
                realAudio: true,
                rightsClearedFixture: true,
                currentMoisesCompared: true,
                timing: timing,
                health: health
            )
        }
        let reviews = cases.map {
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
        return Lane3DeviceEvidenceBundle(
            appBuildCommitSHA: String(repeating: "a", count: 40),
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalDevice: true,
            selectedXcodeBuild: true,
            currentMoisesReferenceSnapshotID: "moises-current-iphone-aw51",
            currentMoisesVersion: "current",
            cases: cases,
            listeningReviews: reviews
        )
    }

    private static func makeTrace(
        subject: Lane3PhysicalEvidenceResourceSubject,
        thermalNominalSamples: Int = 60,
        thermalFairSamples: Int = 0
    ) -> Lane3PhysicalEvidenceResourceTraceReceipt {
        Lane3PhysicalEvidenceResourceTraceReceipt(
            sessionIdentifier: "aw51-session-001",
            subject: subject,
            observedDurationSeconds: 1_800,
            sampleCount: 60,
            maximumSampleIntervalSeconds: 30,
            peakRSSBytes: 256 * 1_024 * 1_024,
            thermalNominalSamples: thermalNominalSamples,
            thermalFairSamples: thermalFairSamples,
            thermalSeriousSamples: 0,
            thermalCriticalSamples: 0,
            batteryStartLevel: 0.8,
            batteryEndLevel: 0.7,
            externalPowerConnectedDuringBatteryWindow: false,
            traceArtifactSHA256: subject == .candidate
                ? String(repeating: "5", count: 64)
                : String(repeating: "6", count: 64)
        )
    }
}
