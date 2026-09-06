import Foundation

@main
struct L3HQPhysicalEvidenceHandoffResourceArtifactValidatorSelfTestMain {
    static func main() throws {
        let candidateData = Data("candidate-resource-artifact-v1".utf8)
        let referenceData = Data("reference-resource-artifact-v1".utf8)
        let corpus = makeCorpus(
            candidateDigest: "017aa1bcfc60219392a32753806160416dd99ece4bba5ea9703fa065491f639e",
            referenceDigest: "65a6289f09126a6d04f544eb9fd56faea2c10f7b2e538cba617d20c20e98ecda"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let commitment = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.make(
            expectedPlan: corpus.plan
        )
        let commitmentJSON = try encoder.encode(commitment)
        let manifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        let manifestJSON = try encoder.encode(manifest)
        let committedReceipt = try Lane3PhysicalEvidenceHandoffCommittedPlanHostValidator.validate(
            commitmentJSON: commitmentJSON,
            expectedPlan: corpus.plan,
            manifestJSON: manifestJSON,
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        let committedReceiptJSON = try encoder.encode(committedReceipt)
        let artifacts = [
            Lane3PhysicalEvidenceHandoffResourceArtifact(
                sessionIdentifier: corpus.plan.sessionIdentifier,
                subject: .candidate,
                scenario: .longTrackStability,
                data: candidateData
            ),
            Lane3PhysicalEvidenceHandoffResourceArtifact(
                sessionIdentifier: corpus.plan.sessionIdentifier,
                subject: .currentMoisesReference,
                scenario: .longTrackStability,
                data: referenceData
            )
        ]

        let accepted = try Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator.validate(
            receiptJSON: committedReceiptJSON,
            commitmentJSON: commitmentJSON,
            expectedPlan: corpus.plan,
            manifestJSON: manifestJSON,
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces,
            resourceArtifacts: artifacts
        )
        precondition(accepted.verifyIntegrity())
        precondition(accepted.acceptedForHQReview)
        precondition(!accepted.parityPromotionAllowed)
        precondition(accepted.committedPlanReceiptBindingSHA256 == committedReceipt.receiptBindingSHA256)
        precondition(
            Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator.verify(
                receipt: accepted,
                receiptJSON: committedReceiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: corpus.plan,
                manifestJSON: manifestJSON,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces,
                resourceArtifacts: artifacts
            )
        )

        var mutated = artifacts
        mutated[0] = Lane3PhysicalEvidenceHandoffResourceArtifact(
            sessionIdentifier: corpus.plan.sessionIdentifier,
            subject: .candidate,
            scenario: .longTrackStability,
            data: Data("candidate-resource-artifact-mutated".utf8)
        )
        try expectError(
            .artifactDigestMismatch,
            receiptJSON: committedReceiptJSON,
            commitmentJSON: commitmentJSON,
            manifestJSON: manifestJSON,
            corpus: corpus,
            artifacts: mutated
        )

        try expectError(
            .missingArtifact,
            receiptJSON: committedReceiptJSON,
            commitmentJSON: commitmentJSON,
            manifestJSON: manifestJSON,
            corpus: corpus,
            artifacts: [artifacts[0]]
        )

        try expectError(
            .duplicateArtifactIdentity,
            receiptJSON: committedReceiptJSON,
            commitmentJSON: commitmentJSON,
            manifestJSON: manifestJSON,
            corpus: corpus,
            artifacts: artifacts + [artifacts[0]]
        )

        let unexpected = Lane3PhysicalEvidenceHandoffResourceArtifact(
            sessionIdentifier: "unrelated-session",
            subject: .candidate,
            scenario: .longTrackStability,
            data: candidateData
        )
        try expectError(
            .unexpectedArtifact,
            receiptJSON: committedReceiptJSON,
            commitmentJSON: commitmentJSON,
            manifestJSON: manifestJSON,
            corpus: corpus,
            artifacts: artifacts + [unexpected]
        )

        let corruptedReceiptJSON = try mutateJSON(committedReceiptJSON) { dictionary in
            dictionary["receiptBindingSHA256"] = String(repeating: "f", count: 64)
        }
        try expectError(
            .committedPlanReceiptRejected,
            receiptJSON: corruptedReceiptJSON,
            commitmentJSON: commitmentJSON,
            manifestJSON: manifestJSON,
            corpus: corpus,
            artifacts: artifacts
        )

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_RESOURCE_ARTIFACT_VALIDATOR_SELF_TEST_PASS rawBytesRehashed=true missingRejected=true duplicateRejected=true unexpectedRejected=true committedReceiptRebound=true nonParity=true")
    }

    private struct Corpus {
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        let traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    }

    private static func makeCorpus(
        candidateDigest: String,
        referenceDigest: String
    ) -> Corpus {
        let input = Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: "hq-resource-artifact-session",
            appBuildCommitSHA: String(repeating: "a", count: 40),
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: "hq-rights-cleared-fixture",
            fixtureDurationSeconds: 1_800,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: "moises-current-snapshot",
            currentMoisesVersion: "current-a",
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
                fixtureID: plan.fixtureID,
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
            appBuildCommitSHA: plan.appBuildCommitSHA,
            deviceModel: plan.deviceModel,
            osVersion: plan.osVersion,
            audioRoute: plan.audioRoute,
            physicalDevice: true,
            selectedXcodeBuild: true,
            currentMoisesReferenceSnapshotID: plan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: plan.currentMoisesVersion,
            cases: cases,
            listeningReviews: reviews
        )
        let traces = [
            makeTrace(
                sessionIdentifier: plan.sessionIdentifier,
                subject: .candidate,
                digest: candidateDigest
            ),
            makeTrace(
                sessionIdentifier: plan.sessionIdentifier,
                subject: .currentMoisesReference,
                digest: referenceDigest
            )
        ]
        let completion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces
        )
        precondition(completion.readyForHQReview)
        return Corpus(plan: plan, bundle: bundle, traces: traces)
    }

    private static func makeTrace(
        sessionIdentifier: String,
        subject: Lane3PhysicalEvidenceResourceSubject,
        digest: String
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
            traceArtifactSHA256: digest
        )
    }

    private static func expectError(
        _ expected: Lane3PhysicalEvidenceHandoffResourceArtifactValidationError,
        receiptJSON: Data,
        commitmentJSON: Data,
        manifestJSON: Data,
        corpus: Corpus,
        artifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator.validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: corpus.plan,
                manifestJSON: manifestJSON,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces,
                resourceArtifacts: artifacts
            )
            preconditionFailure("invalid resource-artifact handoff must fail closed")
        } catch let error as Lane3PhysicalEvidenceHandoffResourceArtifactValidationError {
            precondition(error == expected)
        }
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
}
