import Foundation

@main
struct L3HQPhysicalEvidenceHandoffManifestSelfTestMain {
    static func main() throws {
        let corpus = makeCorpus(
            sessionIdentifier: "hq-handoff-session-a",
            appBuildCommitSHA: String(repeating: "a", count: 40),
            fixtureID: "hq-rights-cleared-fixture-a",
            referenceSnapshotID: "moises-current-snapshot-a",
            currentMoisesVersion: "current-a"
        )

        let manifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        precondition(manifest.schemaVersion == 1)
        precondition(manifest.evidenceScope == "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_MANIFEST_V1_NON_PARITY")
        precondition(manifest.sessionIdentifier == corpus.plan.sessionIdentifier)
        precondition(manifest.appBuildCommitSHA == corpus.plan.appBuildCommitSHA)
        precondition(manifest.fixtureID == corpus.plan.fixtureID)
        precondition(manifest.currentMoisesReferenceSnapshotID == corpus.plan.currentMoisesReferenceSnapshotID)
        precondition(manifest.planBindingSHA256.count == 64)
        precondition(manifest.deviceBundleBindingSHA256.count == 64)
        precondition(manifest.resourceTraceSetBindingSHA256.count == 64)
        precondition(manifest.manifestBindingSHA256.count == 64)
        precondition(manifest.verifyIntegrity())
        precondition(!manifest.parityPromotionAllowed)

        let verified = try Lane3PhysicalEvidenceHandoffManifestBuilder.verify(
            manifest,
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: corpus.traces
        )
        precondition(verified)

        let reordered = Lane3DeviceEvidenceBundle(
            appBuildCommitSHA: corpus.bundle.appBuildCommitSHA,
            deviceModel: corpus.bundle.deviceModel,
            osVersion: corpus.bundle.osVersion,
            audioRoute: corpus.bundle.audioRoute,
            physicalDevice: corpus.bundle.physicalDevice,
            selectedXcodeBuild: corpus.bundle.selectedXcodeBuild,
            currentMoisesReferenceSnapshotID: corpus.bundle.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: corpus.bundle.currentMoisesVersion,
            privacy: corpus.bundle.privacy,
            cases: Array(corpus.bundle.cases.reversed()),
            listeningReviews: Array(corpus.bundle.listeningReviews.reversed())
        )
        let reorderedManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: reordered,
            resourceTraces: Array(corpus.traces.reversed())
        )
        precondition(reorderedManifest == manifest)

        let alternateTrace = makeTrace(
            sessionIdentifier: corpus.plan.sessionIdentifier,
            subject: .candidate,
            traceDigestCharacter: "7"
        )
        let traceChangedManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: corpus.plan,
            deviceBundle: corpus.bundle,
            resourceTraces: [alternateTrace, corpus.traces[1]]
        )
        precondition(traceChangedManifest.resourceTraceSetBindingSHA256 != manifest.resourceTraceSetBindingSHA256)
        precondition(traceChangedManifest.manifestBindingSHA256 != manifest.manifestBindingSHA256)

        let secondCorpus = makeCorpus(
            sessionIdentifier: "hq-handoff-session-b",
            appBuildCommitSHA: String(repeating: "b", count: 40),
            fixtureID: "hq-rights-cleared-fixture-b",
            referenceSnapshotID: "moises-current-snapshot-b",
            currentMoisesVersion: "current-b"
        )
        let secondManifest = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
            plan: secondCorpus.plan,
            deviceBundle: secondCorpus.bundle,
            resourceTraces: secondCorpus.traces
        )
        precondition(secondManifest.manifestBindingSHA256 != manifest.manifestBindingSHA256)
        precondition(secondManifest.planBindingSHA256 != manifest.planBindingSHA256)
        precondition(secondManifest.deviceBundleBindingSHA256 != manifest.deviceBundleBindingSHA256)

        do {
            _ = try Lane3PhysicalEvidenceHandoffManifestBuilder.make(
                plan: corpus.plan,
                deviceBundle: corpus.bundle,
                resourceTraces: corpus.traces + [corpus.traces[0]]
            )
            preconditionFailure("duplicate candidate trace must be rejected by strict completion gate")
        } catch Lane3PhysicalEvidenceHandoffManifestError.completionGateRejected {
            // Expected fail-closed behavior.
        }

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_MANIFEST_SELF_TEST_PASS deterministic=true identitySensitive=true traceSensitive=true strictGate=true nonParity=true")
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

        let bundle = makeBundle(
            appBuildCommitSHA: appBuildCommitSHA,
            fixtureID: fixtureID,
            referenceSnapshotID: referenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion
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

    private static func makeBundle(
        appBuildCommitSHA: String,
        fixtureID: String,
        referenceSnapshotID: String,
        currentMoisesVersion: String
    ) -> Lane3DeviceEvidenceBundle {
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
