import Foundation

@main
struct L3HQPhysicalEvidenceHandoffCommittedPlanReceiptValidatorSelfTestMain {
    static func main() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let baseline = makeCorpus(
            sessionIdentifier: "hq-persisted-receipt-session",
            appBuildCommitSHA: String(repeating: "a", count: 40),
            fixtureID: "hq-rights-cleared-fixture-a",
            referenceSnapshotID: "moises-current-snapshot-a",
            currentMoisesVersion: "current-a"
        )
        let commitment = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.make(
            expectedPlan: baseline.plan
        )
        let commitmentJSON = try encoder.encode(commitment)
        let manifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: baseline.plan,
            deviceBundle: baseline.bundle,
            resourceTraces: baseline.traces
        )
        let manifestJSON = try encoder.encode(manifest)
        let committedReceipt = try Lane3PhysicalEvidenceHandoffCommittedPlanHostValidator.validate(
            commitmentJSON: commitmentJSON,
            expectedPlan: baseline.plan,
            manifestJSON: manifestJSON,
            plan: baseline.plan,
            deviceBundle: baseline.bundle,
            resourceTraces: baseline.traces
        )
        precondition(committedReceipt.verifyIntegrity())
        let receiptJSON = try encoder.encode(committedReceipt)

        let rebound = try Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator.validate(
            receiptJSON: receiptJSON,
            commitmentJSON: commitmentJSON,
            expectedPlan: baseline.plan,
            manifestJSON: manifestJSON,
            plan: baseline.plan,
            deviceBundle: baseline.bundle,
            resourceTraces: baseline.traces
        )
        precondition(rebound == committedReceipt)
        precondition(
            Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator.verify(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: baseline.plan,
                manifestJSON: manifestJSON,
                plan: baseline.plan,
                deviceBundle: baseline.bundle,
                resourceTraces: baseline.traces
            )
        )

        try expectError(.schemaShapeMismatch, receiptJSON: try mutateJSON(receiptJSON) { dictionary in
            dictionary["unexpected"] = "reject"
        }, baseline: baseline, commitmentJSON: commitmentJSON, manifestJSON: manifestJSON)
        try expectError(.schemaShapeMismatch, receiptJSON: try mutateJSON(receiptJSON) { dictionary in
            dictionary.removeValue(forKey: "handoffReceiptBindingSHA256")
        }, baseline: baseline, commitmentJSON: commitmentJSON, manifestJSON: manifestJSON)
        try expectError(.invalidReceiptIntegrity, receiptJSON: try mutateJSON(receiptJSON) { dictionary in
            dictionary["receiptBindingSHA256"] = String(repeating: "f", count: 64)
        }, baseline: baseline, commitmentJSON: commitmentJSON, manifestJSON: manifestJSON)
        try expectError(.parityPromotionRequested, receiptJSON: try mutateJSON(receiptJSON) { dictionary in
            dictionary["parityPromotionAllowed"] = true
        }, baseline: baseline, commitmentJSON: commitmentJSON, manifestJSON: manifestJSON)
        try expectError(.receiptNotAccepted, receiptJSON: try mutateJSON(receiptJSON) { dictionary in
            dictionary["acceptedForHQReview"] = false
        }, baseline: baseline, commitmentJSON: commitmentJSON, manifestJSON: manifestJSON)

        let alternate = makeCorpus(
            sessionIdentifier: baseline.plan.sessionIdentifier,
            appBuildCommitSHA: String(repeating: "b", count: 40),
            fixtureID: "hq-rights-cleared-fixture-b",
            referenceSnapshotID: "moises-current-snapshot-b",
            currentMoisesVersion: "current-b"
        )
        let alternateCommitment = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.make(
            expectedPlan: alternate.plan
        )
        let alternateCommitmentJSON = try encoder.encode(alternateCommitment)
        let alternateManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: alternate.plan,
            deviceBundle: alternate.bundle,
            resourceTraces: alternate.traces
        )
        let alternateManifestJSON = try encoder.encode(alternateManifest)

        do {
            _ = try Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator.validate(
                receiptJSON: receiptJSON,
                commitmentJSON: alternateCommitmentJSON,
                expectedPlan: alternate.plan,
                manifestJSON: alternateManifestJSON,
                plan: alternate.plan,
                deviceBundle: alternate.bundle,
                resourceTraces: alternate.traces
            )
            preconditionFailure("persisted receipt must not rebound to an alternate coherent source tuple")
        } catch let error as Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError {
            precondition(error == .sourceArtifactsMismatch)
        }

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_COMMITTED_PLAN_RECEIPT_VALIDATOR_SELF_TEST_PASS rebound=true schemaClosed=true digestMutationRejected=true parityRejected=true alternateSourceTupleRejected=true nonParity=true")
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

    private static func mutateJSON(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        guard var dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            preconditionFailure("expected JSON object")
        }
        mutation(&dictionary)
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    private static func expectError(
        _ expected: Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError,
        receiptJSON: Data,
        baseline: Corpus,
        commitmentJSON: Data,
        manifestJSON: Data
    ) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator.validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: baseline.plan,
                manifestJSON: manifestJSON,
                plan: baseline.plan,
                deviceBundle: baseline.bundle,
                resourceTraces: baseline.traces
            )
            preconditionFailure("mutated persisted receipt must fail closed")
        } catch let error as Lane3PhysicalEvidenceHandoffCommittedPlanReceiptValidationError {
            precondition(error == expected)
        }
    }
}
