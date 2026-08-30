import Foundation

@main
struct L3HQPhysicalEvidenceHandoffSerializedPackageSelfTestMain {
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
        let planJSON = try encoder.encode(corpus.plan)
        let bundleJSON = try encoder.encode(corpus.bundle)
        let tracesJSON = try encoder.encode(corpus.traces)

        let receipt = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
            manifestJSON: manifestJSON,
            planJSON: planJSON,
            deviceBundleJSON: bundleJSON,
            resourceTracesJSON: tracesJSON
        )
        precondition(receipt.schemaVersion == 1)
        precondition(receipt.acceptedForHQReview)
        precondition(!receipt.parityPromotionAllowed)
        precondition(receipt.hostReceipt.sessionIdentifier == corpus.plan.sessionIdentifier)
        precondition(receipt.hostReceipt.manifestBindingSHA256 == manifest.manifestBindingSHA256)
        precondition(receipt.verifyIntegrity())
        precondition(
            Lane3PhysicalEvidenceHandoffSerializedPackageValidator.verify(
                receipt: receipt,
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: tracesJSON
            )
        )

        let receiptJSON = try encoder.encode(receipt)
        let roundTrippedReceipt = try JSONDecoder().decode(
            Lane3PhysicalEvidenceHandoffSerializedPackageReceipt.self,
            from: receiptJSON
        )
        precondition(roundTrippedReceipt == receipt)
        precondition(roundTrippedReceipt.verifyIntegrity())

        try expect(.malformedJSON(.plan)) {
            _ = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
                manifestJSON: manifestJSON,
                planJSON: Data("not-json".utf8),
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: tracesJSON
            )
        }

        let planWithUnknownField = try mutateObjectJSON(planJSON) { object in
            object["unexpectedHostField"] = "must-fail-closed"
        }
        try expect(.nonCanonicalStructure(.plan)) {
            _ = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
                manifestJSON: manifestJSON,
                planJSON: planWithUnknownField,
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: tracesJSON
            )
        }

        let bundleWithUnknownNestedField = try mutateObjectJSON(bundleJSON) { object in
            guard var privacy = object["privacy"] as? [String: Any] else {
                preconditionFailure("expected privacy object")
            }
            privacy["unexpectedNestedField"] = true
            object["privacy"] = privacy
        }
        try expect(.nonCanonicalStructure(.deviceBundle)) {
            _ = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: bundleWithUnknownNestedField,
                resourceTracesJSON: tracesJSON
            )
        }

        let tracesWithUnknownField = try mutateArrayObjectJSON(tracesJSON, index: 0) { object in
            object["unexpectedTraceField"] = 1
        }
        try expect(.nonCanonicalStructure(.resourceTraces)) {
            _ = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: tracesWithUnknownField
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
        let substitutedTracesJSON = try encoder.encode(substitutedTraces)
        try expect(.hostValidationFailed) {
            _ = try Lane3PhysicalEvidenceHandoffSerializedPackageValidator.validate(
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: substitutedTracesJSON
            )
        }
        precondition(
            !Lane3PhysicalEvidenceHandoffSerializedPackageValidator.verify(
                receipt: receipt,
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: bundleJSON,
                resourceTracesJSON: substitutedTracesJSON
            )
        )

        // Formatting/key order must not create a different package identity.
        let prettyEncoder = JSONEncoder()
        prettyEncoder.outputFormatting = [.prettyPrinted]
        let prettyManifestJSON = try prettyEncoder.encode(manifest)
        let prettyPlanJSON = try prettyEncoder.encode(corpus.plan)
        let prettyBundleJSON = try prettyEncoder.encode(corpus.bundle)
        let prettyTracesJSON = try prettyEncoder.encode(corpus.traces)
        precondition(
            Lane3PhysicalEvidenceHandoffSerializedPackageValidator.verify(
                receipt: receipt,
                manifestJSON: prettyManifestJSON,
                planJSON: prettyPlanJSON,
                deviceBundleJSON: prettyBundleJSON,
                resourceTracesJSON: prettyTracesJSON
            )
        )

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_SERIALIZED_PACKAGE_SELF_TEST_PASS allInputsSerialized=true strictRoundTrip=true nestedUnknownRejected=true evidenceRebind=true replayReceipt=true nonParity=true")
    }

    private struct Corpus {
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        let traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    }

    private static func makeCorpus() -> Corpus {
        let sessionIdentifier = "hq-serialized-package-session"
        let appBuildCommitSHA = String(repeating: "b", count: 40)
        let fixtureID = "hq-rights-cleared-package-fixture"
        let referenceSnapshotID = "moises-current-package-snapshot"
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

    private static func mutateObjectJSON(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            preconditionFailure("expected JSON object")
        }
        mutation(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func mutateArrayObjectJSON(
        _ data: Data,
        index: Int,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        guard var array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              array.indices.contains(index) else {
            preconditionFailure("expected JSON object array")
        }
        mutation(&array[index])
        return try JSONSerialization.data(withJSONObject: array, options: [.sortedKeys])
    }

    private static func expect(
        _ expected: Lane3PhysicalEvidenceHandoffSerializedPackageError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            preconditionFailure("expected serialized package failure: \(expected)")
        } catch let error as Lane3PhysicalEvidenceHandoffSerializedPackageError {
            precondition(error == expected, "unexpected error: \(error), expected: \(expected)")
        }
    }
}
