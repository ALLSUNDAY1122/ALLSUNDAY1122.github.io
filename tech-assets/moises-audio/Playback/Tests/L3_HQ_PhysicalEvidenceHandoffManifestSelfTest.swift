import Foundation

@main
enum L3HQPhysicalEvidenceHandoffManifestSelfTest {
    static func main() throws {
        let fixtureID = "rights-cleared-long-track-v1"
        let buildSHA = String(repeating: "a", count: 40)
        let candidateDigest = String(repeating: "c", count: 64)
        let referenceDigest = String(repeating: "d", count: 64)
        let snapshotDigest = String(repeating: "e", count: 64)

        let plan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makePreflightInput(buildSHA: buildSHA, fixtureID: fixtureID)
        )
        precondition(plan.sessionStartAllowed)

        let bundle = makeDeviceBundle(buildSHA: buildSHA, fixtureID: fixtureID)
        let traces = [
            makeResourceTrace(subject: .candidate, digest: candidateDigest),
            makeResourceTrace(subject: .currentMoisesReference, digest: referenceDigest)
        ]
        let completion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces
        )
        precondition(completion.readyForHQReview)

        let manifest = try Lane3PhysicalEvidenceHandoffManifest.make(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces,
            completionReport: completion,
            candidateResourceArtifactSHA256: candidateDigest,
            currentMoisesResourceArtifactSHA256: referenceDigest,
            currentMoisesSnapshotSHA256: snapshotDigest
        )
        try manifest.verify(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces,
            completionReport: completion,
            candidateResourceArtifactSHA256: candidateDigest,
            currentMoisesResourceArtifactSHA256: referenceDigest,
            currentMoisesSnapshotSHA256: snapshotDigest
        )
        precondition(manifest.handoffBindingSHA256 == manifest.recomputedHandoffBindingSHA256())
        precondition(manifest.handoffBindingSHA256.count == 64)
        precondition(!manifest.parityPromotionAllowed)

        let duplicate = try Lane3PhysicalEvidenceHandoffManifest.make(
            plan: plan,
            deviceBundle: bundle,
            resourceTraces: traces,
            completionReport: completion,
            candidateResourceArtifactSHA256: candidateDigest,
            currentMoisesResourceArtifactSHA256: referenceDigest,
            currentMoisesSnapshotSHA256: snapshotDigest
        )
        precondition(duplicate == manifest)

        try expectError(.invalidCandidateResourceArtifactBinding) {
            _ = try Lane3PhysicalEvidenceHandoffManifest.make(
                plan: plan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: String(repeating: "f", count: 64),
                currentMoisesResourceArtifactSHA256: referenceDigest,
                currentMoisesSnapshotSHA256: snapshotDigest
            )
        }

        try expectError(.invalidCurrentMoisesResourceArtifactBinding) {
            _ = try Lane3PhysicalEvidenceHandoffManifest.make(
                plan: plan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: candidateDigest,
                currentMoisesResourceArtifactSHA256: String(repeating: "f", count: 64),
                currentMoisesSnapshotSHA256: snapshotDigest
            )
        }

        try expectError(.manifestMismatch) {
            try manifest.verify(
                plan: plan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: candidateDigest,
                currentMoisesResourceArtifactSHA256: referenceDigest,
                currentMoisesSnapshotSHA256: String(repeating: "f", count: 64)
            )
        }

        let otherBuildPlan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makePreflightInput(buildSHA: String(repeating: "b", count: 40), fixtureID: fixtureID)
        )
        try expectError(.completionReportMismatch) {
            try manifest.verify(
                plan: otherBuildPlan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: candidateDigest,
                currentMoisesResourceArtifactSHA256: referenceDigest,
                currentMoisesSnapshotSHA256: snapshotDigest
            )
        }

        let otherFixturePlan = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(
            input: makePreflightInput(buildSHA: buildSHA, fixtureID: "other-rights-cleared-fixture")
        )
        try expectError(.completionReportMismatch) {
            try manifest.verify(
                plan: otherFixturePlan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: candidateDigest,
                currentMoisesResourceArtifactSHA256: referenceDigest,
                currentMoisesSnapshotSHA256: snapshotDigest
            )
        }

        let encoded = try JSONEncoder().encode(manifest)
        guard var json = String(data: encoded, encoding: .utf8) else {
            preconditionFailure("manifest JSON encoding was not UTF-8")
        }
        json = json.replacingOccurrences(
            of: manifest.handoffBindingSHA256,
            with: String(repeating: "0", count: 64)
        )
        let tampered = try JSONDecoder().decode(
            Lane3PhysicalEvidenceHandoffManifest.self,
            from: Data(json.utf8)
        )
        try expectError(.manifestMismatch) {
            try tampered.verify(
                plan: plan,
                deviceBundle: bundle,
                resourceTraces: traces,
                completionReport: completion,
                candidateResourceArtifactSHA256: candidateDigest,
                currentMoisesResourceArtifactSHA256: referenceDigest,
                currentMoisesSnapshotSHA256: snapshotDigest
            )
        }

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_SELF_TEST_PASS checks=8 deterministic=true non_parity=true")
    }

    private static func makePreflightInput(
        buildSHA: String,
        fixtureID: String
    ) -> Lane3PhysicalEvidenceSessionPreflightInput {
        Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: "physical-session-001",
            appBuildCommitSHA: buildSHA,
            deviceModel: "iPhone-test-model",
            osVersion: "iOS-test-version",
            audioRoute: .builtInSpeaker,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: fixtureID,
            fixtureDurationSeconds: 1_800,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: "current-moises-snapshot-001",
            currentMoisesVersion: "current-moises-version-test",
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
    }

    private static func makeDeviceBundle(
        buildSHA: String,
        fixtureID: String
    ) -> Lane3DeviceEvidenceBundle {
        var receipts: [Lane3DeviceEvidenceCaseReceipt] = []
        var reviews: [Lane3DeviceListeningReview] = []
        for scenario in Lane3DeviceEvidenceScenario.allCases {
            let repetitions: Int
            switch scenario {
            case .longTrackStability: repetitions = 1
            case .interruptionRecovery: repetitions = 5
            default: repetitions = 10
            }
            let receipt = Lane3DeviceEvidenceCaseReceipt(
                scenario: scenario,
                fixtureID: fixtureID,
                controlSignatureFNV1A64: "0123456789abcdef",
                aw13RunBindingSHA256: String(repeating: "1", count: 64),
                candidateCaptureSHA256: String(repeating: "2", count: 64),
                currentMoisesCaptureSHA256: String(repeating: "3", count: 64),
                repetitionsCompleted: repetitions,
                successfulRepetitions: repetitions,
                observedDurationSeconds: scenario == .longTrackStability ? 1_800 : 1,
                realAudio: true,
                rightsClearedFixture: true,
                currentMoisesCompared: true,
                timing: Lane3DeviceEvidenceTimingSummary(
                    samples: repetitions,
                    p50Milliseconds: 10,
                    p95Milliseconds: 20,
                    maxMilliseconds: 30
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
            receipts.append(receipt)
            reviews.append(Lane3DeviceListeningReview(
                scenario: scenario,
                caseBindingSHA256: receipt.caseBindingSHA256,
                listeningPasses: 3,
                obviousInferiorityObserved: false,
                clickPopObserved: false,
                warbleInferiorityObserved: false,
                phasinessInferiorityObserved: false,
                formantDamageInferiorityObserved: false
            ))
        }

        return Lane3DeviceEvidenceBundle(
            appBuildCommitSHA: buildSHA,
            deviceModel: "iPhone-test-model",
            osVersion: "iOS-test-version",
            audioRoute: .builtInSpeaker,
            physicalDevice: true,
            selectedXcodeBuild: true,
            currentMoisesReferenceSnapshotID: "current-moises-snapshot-001",
            currentMoisesVersion: "current-moises-version-test",
            cases: receipts,
            listeningReviews: reviews
        )
    }

    private static func makeResourceTrace(
        subject: Lane3PhysicalEvidenceResourceSubject,
        digest: String
    ) -> Lane3PhysicalEvidenceResourceTraceReceipt {
        Lane3PhysicalEvidenceResourceTraceReceipt(
            sessionIdentifier: "physical-session-001",
            subject: subject,
            observedDurationSeconds: 1_800,
            sampleCount: 61,
            maximumSampleIntervalSeconds: 30,
            peakRSSBytes: 128 * 1_024 * 1_024,
            thermalNominalSamples: 61,
            thermalFairSamples: 0,
            thermalSeriousSamples: 0,
            thermalCriticalSamples: 0,
            batteryStartLevel: 0.90,
            batteryEndLevel: 0.80,
            externalPowerConnectedDuringBatteryWindow: false,
            traceArtifactSHA256: digest
        )
    }

    private static func expectError(
        _ expected: Lane3PhysicalEvidenceHandoffManifestError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            preconditionFailure("expected error \(expected)")
        } catch let error as Lane3PhysicalEvidenceHandoffManifestError {
            precondition(error == expected, "expected \(expected), observed \(error)")
        }
    }
}
