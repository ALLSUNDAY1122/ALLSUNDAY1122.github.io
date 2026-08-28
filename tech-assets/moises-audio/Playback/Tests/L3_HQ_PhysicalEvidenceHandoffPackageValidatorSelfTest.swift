import Foundation

@main
struct L3HQPhysicalEvidenceHandoffPackageValidatorSelfTestMain {
    static func main() throws {
        let corpus = makeCorpus()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let manifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        let artifacts = try makeArtifacts(
            manifest: manifest,
            plan: corpus.plan,
            bundle: corpus.bundle,
            traces: corpus.traces,
            encoder: encoder
        )

        let receipt = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: artifacts)
        precondition(receipt.schemaVersion == 1)
        precondition(receipt.sessionIdentifier == corpus.plan.sessionIdentifier)
        precondition(receipt.appBuildCommitSHA == corpus.plan.appBuildCommitSHA)
        precondition(receipt.artifactCount == artifacts.count)
        precondition(receipt.packageBindingSHA256.count == 64)
        precondition(receipt.hostReceiptBindingSHA256.count == 64)
        precondition(receipt.acceptedForHQReview)
        precondition(!receipt.parityPromotionAllowed)
        precondition(receipt.verifyIntegrity())
        precondition(Lane3PhysicalEvidenceHandoffPackageValidator.verify(receipt: receipt, artifacts: artifacts))

        let reordered = Array(artifacts.reversed())
        let reorderedReceipt = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: reordered)
        precondition(reorderedReceipt == receipt)

        var whitespacePlanArtifacts = artifacts
        guard let planIndex = whitespacePlanArtifacts.firstIndex(where: { $0.role == Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole }) else {
            preconditionFailure("missing session-plan artifact")
        }
        var whitespacePlanPayload = whitespacePlanArtifacts[planIndex].payload
        whitespacePlanPayload.append(contentsOf: [0x0a, 0x20, 0x20])
        whitespacePlanArtifacts[planIndex] = .init(
            role: Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole,
            payload: whitespacePlanPayload
        )
        let whitespaceReceipt = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: whitespacePlanArtifacts)
        precondition(whitespaceReceipt.sessionIdentifier == receipt.sessionIdentifier)
        precondition(whitespaceReceipt.packageBindingSHA256 != receipt.packageBindingSHA256)
        precondition(!Lane3PhysicalEvidenceHandoffPackageValidator.verify(receipt: receipt, artifacts: whitespacePlanArtifacts))

        var malformedPlanArtifacts = artifacts
        malformedPlanArtifacts[planIndex] = .init(
            role: Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole,
            payload: Data("not-json".utf8)
        )
        try expect(.malformedArtifact(Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: malformedPlanArtifacts)
        }

        var malformedBundleArtifacts = artifacts
        guard let bundleIndex = malformedBundleArtifacts.firstIndex(where: { $0.role == Lane3PhysicalEvidenceHandoffPackageValidator.deviceBundleRole }) else {
            preconditionFailure("missing device-bundle artifact")
        }
        malformedBundleArtifacts[bundleIndex] = .init(
            role: Lane3PhysicalEvidenceHandoffPackageValidator.deviceBundleRole,
            payload: Data("not-json".utf8)
        )
        try expect(.malformedArtifact(Lane3PhysicalEvidenceHandoffPackageValidator.deviceBundleRole)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: malformedBundleArtifacts)
        }

        let candidateRole = Lane3PhysicalEvidenceHandoffPackageValidator.resourceTraceRole(
            subject: .candidate,
            scenario: .longTrackStability
        )
        guard let candidateIndex = artifacts.firstIndex(where: { $0.role == candidateRole }) else {
            preconditionFailure("missing candidate trace artifact")
        }

        var malformedTraceArtifacts = artifacts
        malformedTraceArtifacts[candidateIndex] = .init(role: candidateRole, payload: Data("not-json".utf8))
        try expect(.malformedArtifact(candidateRole)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: malformedTraceArtifacts)
        }

        var wrongTraceRoleArtifacts = artifacts
        wrongTraceRoleArtifacts[candidateIndex] = .init(
            role: Lane3PhysicalEvidenceHandoffPackageValidator.resourceTraceRole(
                subject: .currentMoisesReference,
                scenario: .seekLoop
            ),
            payload: artifacts[candidateIndex].payload
        )
        try expect(.rolePayloadMismatch(wrongTraceRoleArtifacts[candidateIndex].role)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: wrongTraceRoleArtifacts)
        }

        let missingManifest = artifacts.filter { $0.role != Lane3PhysicalEvidenceHandoffPackageValidator.manifestRole }
        try expect(.missingArtifact(Lane3PhysicalEvidenceHandoffPackageValidator.manifestRole)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: missingManifest)
        }

        try expect(.duplicateRole(Lane3PhysicalEvidenceHandoffPackageValidator.manifestRole)) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(
                artifacts: artifacts + [artifacts.first(where: { $0.role == Lane3PhysicalEvidenceHandoffPackageValidator.manifestRole })!]
            )
        }

        try expect(.unexpectedRole("unexpected-artifact")) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(
                artifacts: artifacts + [.init(role: "unexpected-artifact", payload: Data("{}".utf8))]
            )
        }

        var semanticallyChangedPlanArtifacts = artifacts
        let changedPlanPayload = try mutateJSON(artifacts[planIndex].payload) { dictionary in
            dictionary["sessionIdentifier"] = "substituted-session"
        }
        semanticallyChangedPlanArtifacts[planIndex] = .init(
            role: Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole,
            payload: changedPlanPayload
        )
        try expect(.evidenceRejected) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: semanticallyChangedPlanArtifacts)
        }

        let alternateTrace = makeTrace(
            sessionIdentifier: corpus.plan.sessionIdentifier,
            subject: .candidate,
            traceDigestCharacter: "9"
        )
        var substitutedTraceArtifacts = artifacts
        substitutedTraceArtifacts[candidateIndex] = .init(
            role: candidateRole,
            payload: try encoder.encode(alternateTrace)
        )
        try expect(.evidenceRejected) {
            _ = try Lane3PhysicalEvidenceHandoffPackageValidator.validate(artifacts: substitutedTraceArtifacts)
        }
        precondition(!Lane3PhysicalEvidenceHandoffPackageValidator.verify(receipt: receipt, artifacts: substitutedTraceArtifacts))

        let receiptJSON = try encoder.encode(receipt)
        let decodedReceipt = try JSONDecoder().decode(Lane3PhysicalEvidenceHandoffPackageReceipt.self, from: receiptJSON)
        precondition(decodedReceipt == receipt)
        precondition(decodedReceipt.verifyIntegrity())

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_VALIDATOR_SELF_TEST_PASS exactBytes=true roleBound=true evidenceRebind=true receiptIntegrity=true nonParity=true")
    }

    private struct Corpus {
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        let traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    }

    private static func makeArtifacts(
        manifest: Lane3PhysicalEvidenceHandoffManifest,
        plan: Lane3PhysicalEvidenceSessionPlan,
        bundle: Lane3DeviceEvidenceBundle,
        traces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        encoder: JSONEncoder
    ) throws -> [Lane3PhysicalEvidenceHandoffSerializedArtifact] {
        var artifacts: [Lane3PhysicalEvidenceHandoffSerializedArtifact] = [
            .init(role: Lane3PhysicalEvidenceHandoffPackageValidator.manifestRole, payload: try encoder.encode(manifest)),
            .init(role: Lane3PhysicalEvidenceHandoffPackageValidator.sessionPlanRole, payload: try encoder.encode(plan)),
            .init(role: Lane3PhysicalEvidenceHandoffPackageValidator.deviceBundleRole, payload: try encoder.encode(bundle))
        ]
        for trace in traces {
            artifacts.append(.init(
                role: Lane3PhysicalEvidenceHandoffPackageValidator.resourceTraceRole(
                    subject: trace.subject,
                    scenario: trace.scenario
                ),
                payload: try encoder.encode(trace)
            ))
        }
        return artifacts
    }

    private static func makeCorpus() -> Corpus {
        let sessionIdentifier = "hq-package-validation-session"
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

    private static func expect(
        _ expected: Lane3PhysicalEvidenceHandoffPackageValidationError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            preconditionFailure("expected package validation failure: \(expected)")
        } catch let error as Lane3PhysicalEvidenceHandoffPackageValidationError {
            precondition(error == expected, "unexpected error: \(error), expected: \(expected)")
        }
    }
}
