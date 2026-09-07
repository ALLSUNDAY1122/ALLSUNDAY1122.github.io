import Foundation

@main
struct L3HQPhysicalEvidenceHandoffExpectedPlanHostValidatorSelfTestMain {
    static func main() throws {
        let sessionIdentifier = "hq-expected-plan-session"
        let expected = makeCorpus(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: String(repeating: "a", count: 40),
            fixtureID: "hq-rights-cleared-fixture-a",
            referenceSnapshotID: "moises-current-snapshot-a",
            currentMoisesVersion: "current-a"
        )
        let substituted = makeCorpus(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: String(repeating: "b", count: 40),
            fixtureID: "hq-rights-cleared-fixture-b",
            referenceSnapshotID: "moises-current-snapshot-b",
            currentMoisesVersion: "current-b"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let expectedManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: expected.plan,
            deviceBundle: expected.bundle,
            resourceTraces: expected.traces
        )
        let expectedManifestJSON = try encoder.encode(expectedManifest)

        let receipt = try Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator.validate(
            expectedPlan: expected.plan,
            manifestJSON: expectedManifestJSON,
            plan: expected.plan,
            deviceBundle: expected.bundle,
            resourceTraces: expected.traces
        )
        precondition(receipt.acceptedForHQReview)
        precondition(!receipt.parityPromotionAllowed)
        precondition(receipt.sessionIdentifier == expected.plan.sessionIdentifier)
        precondition(receipt.appBuildCommitSHA == expected.plan.appBuildCommitSHA)
        precondition(receipt.verifyIntegrity())
        precondition(
            Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator.verify(
                receipt: receipt,
                expectedPlan: expected.plan,
                manifestJSON: expectedManifestJSON,
                plan: expected.plan,
                deviceBundle: expected.bundle,
                resourceTraces: expected.traces
            )
        )

        let substitutedManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: substituted.plan,
            deviceBundle: substituted.bundle,
            resourceTraces: substituted.traces
        )
        let substitutedManifestJSON = try encoder.encode(substitutedManifest)

        // The original validator correctly accepts B when B is presented as one
        // internally coherent tuple. It has no independent knowledge that HQ
        // selected A before collection.
        let unanchoredReceipt = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
            manifestJSON: substitutedManifestJSON,
            plan: substituted.plan,
            deviceBundle: substituted.bundle,
            resourceTraces: substituted.traces
        )
        precondition(unanchoredReceipt.acceptedForHQReview)
        precondition(unanchoredReceipt.appBuildCommitSHA == substituted.plan.appBuildCommitSHA)

        // The expected-plan layer must reject that same coherent tuple because
        // it is not the exact preselected HQ plan, even though the session label
        // itself was intentionally kept identical.
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator.validate(
                expectedPlan: expected.plan,
                manifestJSON: substitutedManifestJSON,
                plan: substituted.plan,
                deviceBundle: substituted.bundle,
                resourceTraces: substituted.traces
            )
            preconditionFailure("coherent alternate plan must fail the HQ expected-plan anchor")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanValidationError {
            precondition(error == .expectedPlanMismatch)
        }

        precondition(
            !Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator.verify(
                receipt: unanchoredReceipt,
                expectedPlan: expected.plan,
                manifestJSON: substitutedManifestJSON,
                plan: substituted.plan,
                deviceBundle: substituted.bundle,
                resourceTraces: substituted.traces
            )
        )

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_EXPECTED_PLAN_HOST_VALIDATOR_SELF_TEST_PASS exactPlanAnchor=true coherentAlternateRejected=true sameSessionLabelRejected=true nonParity=true")
    }

    private struct Corpus {
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        let traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    }

    private static func makeCorpus(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        fixtureID: String,
        referenceSnapshotID: String,
        currentMoisesVersion: String
    ) -> Corpus {
        let input = Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: fixtureID,
            fixtureDurationSeconds: 1_800,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: referenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
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
        let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(input: input)
        precondition(plan.sessionStartAllowed)
        precondition(plan.preflightIssues.isEmpty)

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
            case .longTrackStability:
                repetitions = 1
            case .interruptionRecovery:
                repetitions = 5
            case .mixerGainRamp, .seekLoop, .tempo, .pitch, .metronome, .countIn:
                repetitions = 10
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
        let reviews = cases.map { item in
            Lane3DeviceListeningReview(
                scenario: item.scenario,
                caseBindingSHA256: item.caseBindingSHA256,
                listeningPasses: 3,
                obviousInferiorityObserved: false,
                clickPopObserved: false,
                warbleInferiorityObserved: false,
                phasinessInferiorityObserved: false,
                formantDamageInferiorityObserved: false
            )
        }
        let bundle = Lane3DeviceEvidenceBundle(
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalDevice: true,
            selectedXcodeBuild: true,
            currentMoisesReferenceSnapshotID: referenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
            cases: cases,
            listeningReviews: reviews
        )
        let traces = [
            makeTrace(sessionIdentifier: sessionIdentifier, subject: .candidate, traceDigestCharacter: "5"),
            makeTrace(sessionIdentifier: sessionIdentifier, subject: .currentMoisesReference, traceDigestCharacter: "6")
        ]
        let completion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces
        )
        precondition(completion.readyForHQReview)
        precondition(completion.strictIssues.isEmpty)
        return Corpus(plan: plan, bundle: bundle, traces: traces)
    }

    private static func makeTrace(
        sessionIdentifier: String,
        subject: Lane3PhysicalEvidenceResourceSubject,
        traceDigestCharacter: Character
    ) -> Lane3PhysicalEvidenceResourceTraceReceipt {
        Lane3PhysicalEvidenceResourceTraceReceipt(
            sessionIdentifier: sessionIdentifier,
            subject: subject,
            observedDurationSeconds: 1_800,
            sampleCount: 60,
            maximumSampleIntervalSeconds: 30,
            peakRSSBytes: 256 * 1_024 * 1_024,
            thermalNominalSamples: 60,
            thermalFairSamples: 0,
            thermalSeriousSamples: 0,
            thermalCriticalSamples: 0,
            batteryStartLevel: 0.8,
            batteryEndLevel: 0.7,
            externalPowerConnectedDuringBatteryWindow: false,
            traceArtifactSHA256: String(repeating: traceDigestCharacter, count: 64)
        )
    }
}
