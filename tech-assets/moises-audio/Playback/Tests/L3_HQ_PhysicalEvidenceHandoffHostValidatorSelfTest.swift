import Foundation

@main
struct L3HQPhysicalEvidenceHandoffHostValidatorSelfTestMain {
    static func main() throws {
        let corpus = makeCorpus()
        let manifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifestJSON = try encoder.encode(manifest)

        let receipt = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
            manifestJSON: manifestJSON,
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        precondition(receipt.schemaVersion == 1)
        precondition(receipt.sessionIdentifier == corpus.plan.sessionIdentifier)
        precondition(receipt.appBuildCommitSHA == corpus.plan.appBuildCommitSHA)
        precondition(receipt.manifestBindingSHA256 == manifest.manifestBindingSHA256)
        precondition(receipt.acceptedForHQReview)
        precondition(!receipt.parityPromotionAllowed)
        precondition(receipt.verifyIntegrity())
        precondition(
            Lane3PhysicalEvidenceHandoffHostValidator.verify(
                receipt: receipt,
                manifestJSON: manifestJSON,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        )

        let receiptJSON = try encoder.encode(receipt)
        let decodedReceipt = try JSONDecoder().decode(
            Lane3PhysicalEvidenceHandoffHostReceipt.self,
            from: receiptJSON
        )
        precondition(decodedReceipt == receipt)
        precondition(decodedReceipt.verifyIntegrity())

        try expect(.malformedManifest) {
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: Data("not-json".utf8),
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        try expect(.schemaShapeMismatch) {
            let changed = try mutateJSON(manifestJSON) { dictionary in
                dictionary["unexpectedField"] = "must-fail-closed"
            }
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: changed,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        try expect(.unsupportedSchemaVersion) {
            let changed = try mutateJSON(manifestJSON) { dictionary in
                dictionary["schemaVersion"] = 2
            }
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: changed,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        try expect(.unexpectedEvidenceScope) {
            let changed = try mutateJSON(manifestJSON) { dictionary in
                dictionary["evidenceScope"] = "LANE3_WRONG_SCOPE"
            }
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: changed,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        try expect(.parityPromotionRequested) {
            let changed = try mutateJSON(manifestJSON) { dictionary in
                dictionary["parityPromotionAllowed"] = true
            }
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: changed,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        try expect(.evidenceMismatch) {
            let changed = try mutateJSON(manifestJSON) { dictionary in
                dictionary["sessionIdentifier"] = "substituted-session"
            }
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: changed,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces
            )
        }

        let substitutedTraces = [
            makeTrace(
                sessionIdentifier: corpus.plan.sessionIdentifier,
                subject: .candidate,
                traceDigestCharacter: "9"
            ),
            corpus.traces[1]
        ]
        try expect(.evidenceMismatch) {
            _ = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: manifestJSON,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: substitutedTraces
            )
        }
        precondition(
            !Lane3PhysicalEvidenceHandoffHostValidator.verify(
                receipt: receipt,
                manifestJSON: manifestJSON,
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: substitutedTraces
            )
        )

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_HOST_VALIDATOR_SELF_TEST_PASS serializedBoundary=true strictSchema=true evidenceRebind=true receiptIntegrity=true nonParity=true")
    }

    private struct Corpus {
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        let traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    }

    private static func makeCorpus() -> Corpus {
        let sessionIdentifier = "hq-host-validation-session"
        let appBuildCommitSHA = String(repeating: "a", count: 40)
        let fixtureID = "hq-rights-cleared-fixture"
        let referenceSnapshotID = "moises-current-snapshot"
        let currentMoisesVersion = "current"

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
            makeTrace(
                sessionIdentifier: sessionIdentifier,
                subject: .candidate,
                traceDigestCharacter: "5"
            ),
            makeTrace(
                sessionIdentifier: sessionIdentifier,
                subject: .currentMoisesReference,
                traceDigestCharacter: "6"
            )
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
            preconditionFailure("expected manifest JSON object")
        }
        mutation(&dictionary)
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    private static func expect(
        _ expected: Lane3PhysicalEvidenceHandoffHostValidationError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            preconditionFailure("expected host validation failure: \(expected)")
        } catch let error as Lane3PhysicalEvidenceHandoffHostValidationError {
            precondition(error == expected, "unexpected error: \(error), expected: \(expected)")
        }
    }
}
