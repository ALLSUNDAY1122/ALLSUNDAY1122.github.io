import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioCorpusExecutionTests: XCTestCase {
    private let generatedAt = Date(timeIntervalSince1970: 1_785_000_000)

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func runtime(
        platform: String = "iphoneos",
        architecture: String = "arm64",
        decoderKind: AnalysisPhysicalRealAudioDecoderKind = .genuineLane2BoundedDecoder
    ) -> AnalysisPhysicalRealAudioRuntimeBinding {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W47-APPROVED",
            platform: platform,
            architecture: architecture,
            sourceRevision: "source-revision-1",
            buildIdentity: "build-identity-1",
            deviceModel: "iPhone17,1",
            osVersion: "20.0",
            physicalSessionID: "physical-session-1",
            analyzerID: "project-analysis",
            analyzerVersion: "w47",
            analysisConfigurationID: "product-baseline",
            engine: "project-owned-dsp",
            engineVersion: "w47-physical",
            decoder: .init(
                kind: decoderKind,
                decoderID: "lane2-decoder",
                decoderVersion: "1",
                decoderSessionID: "decoder-session-1"
            )
        )
    }

    private func manifest() -> AnalysisRealAudioBenchmarkManifest {
        let referenceKey = MusicalKey(tonicPitchClass: 0, mode: "major", confidence: nil)
        let chord = ChordEvent(startSeconds: 0, endSeconds: 8, normalizedLabel: "C:maj", confidence: nil)
        let section = SongSection(startSeconds: 0, endSeconds: 8, structuralLabel: "A", functionalLabel: "verse", confidence: nil)
        let rightsA = AnalysisRightsEvidence(
            grantID: "grant-a",
            rightsClass: .projectOwned,
            permittedUses: [.analysisBenchmark, .internalQualityReview, .differentialReference],
            sourceSHA256: sha("a")
        )
        let rightsB = AnalysisRightsEvidence(
            grantID: "grant-b",
            rightsClass: .licensedTest,
            permittedUses: [.analysisBenchmark, .internalQualityReview, .differentialReference],
            sourceSHA256: sha("b")
        )
        func benchmarkCase(_ id: String, _ project: String, _ asset: String, _ rights: AnalysisRightsEvidence) -> AnalysisRealAudioBenchmarkCase {
            .init(
                fixtureID: id,
                projectID: UUID(uuidString: project)!,
                assetID: UUID(uuidString: asset)!,
                relativePath: "bench/\(id).wav",
                genre: id == "fixture-a" ? "rock" : "jazz",
                sourceKind: .realAudio,
                expectedDurationSeconds: 8,
                rights: rights,
                reference: .init(
                    bpm: 120,
                    beatTimesSeconds: [0.5, 1.0, 1.5, 2.0],
                    key: referenceKey,
                    chords: [chord],
                    sections: [section]
                )
            )
        }
        return .init(
            manifestID: "manifest-w47",
            createdAt: generatedAt,
            cases: [
                benchmarkCase("fixture-a", "00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000011", rightsA),
                benchmarkCase("fixture-b", "00000000-0000-0000-0000-000000000002", "00000000-0000-0000-0000-000000000012", rightsB)
            ]
        )
    }

    private func manifestSHA() throws -> String {
        AnalysisDeviceWorkloadSHA256.hexDigest(try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest()))
    }

    private func snapshot() -> AnalysisSnapshot {
        .init(
            tempo: .init(bpm: 120, confidence: 0.9, beatTimesSeconds: [0.5, 1.0, 1.5, 2.0]),
            key: .init(tonicPitchClass: 0, mode: "major", confidence: 0.9),
            chords: [.init(startSeconds: 0, endSeconds: 8, normalizedLabel: "C:maj", confidence: 0.9)],
            sections: [.init(startSeconds: 0, endSeconds: 8, structuralLabel: "A", functionalLabel: "verse", confidence: 0.9)]
        )
    }

    private func receipt(
        fixtureID: String,
        sourceSHA: String,
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        runID: String,
        executionID: String,
        decoderExecutionID: String,
        sampleCount: Int64 = 800,
        observedSamples: Int64 = 800,
        stages: [AnalysisDeviceWorkloadStageEvent]? = nil,
        snapshot: AnalysisSnapshot? = nil
    ) throws -> AnalysisPhysicalRealAudioFixtureExecutionReceipt {
        let actualSnapshot = snapshot ?? self.snapshot()
        let data = try AnalysisSnapshotRobustness.canonicalJSON(actualSnapshot)
        let snapshotSHA = AnalysisDeviceWorkloadSHA256.hexDigest(data)
        let source = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: fixtureID,
            sourceSHA256: sourceSHA,
            sourceDurationSeconds: 8,
            sourceSampleRate: 100,
            sourceChannelCount: 2
        )
        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: runtime.analyzerID,
            analyzerVersion: runtime.analyzerVersion,
            analysisConfigurationID: runtime.analysisConfigurationID,
            buildIdentity: runtime.buildIdentity
        )
        let stageEvents = stages ?? AnalysisDeviceWorkloadStage.requiredCompleteOrder.enumerated().map {
            .init(stage: $0.element, startedOffsetSeconds: Double($0.offset), endedOffsetSeconds: Double($0.offset) + 0.5, status: .completed)
        }
        let binding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .completeAnalysis,
            manifestID: "manifest-w47",
            manifestSHA256: try manifestSHA(),
            source: source,
            identity: identity,
            executionID: executionID,
            workloadStartedAt: generatedAt,
            stages: stageEvents,
            snapshotSHA256: snapshotSHA,
            outputSummary: .init(snapshot: actualSnapshot)
        )
        let workload = AnalysisDeviceWorkloadReceipt(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .completeAnalysis,
            manifestID: "manifest-w47",
            manifestSHA256: try manifestSHA(),
            source: source,
            identity: identity,
            executionID: executionID,
            workloadStartedAt: generatedAt,
            stages: stageEvents,
            snapshotCanonicalJSON: data,
            snapshotSHA256: snapshotSHA,
            outputSummary: .init(snapshot: actualSnapshot),
            executionBindingSHA256: binding
        )
        return .init(
            fixtureID: fixtureID,
            runtimeBindingSHA256: try AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(runtime),
            decoderExecutionID: decoderExecutionID,
            sourceSHA256: sourceSHA,
            sourceSampleRate: 100,
            sourceSampleCount: sampleCount,
            sourceChannelCount: 2,
            observedSourceChunkCount: 4,
            observedSourceSampleCount: observedSamples,
            workloadReceipt: workload
        )
    }

    private func validReceipts(_ runtime: AnalysisPhysicalRealAudioRuntimeBinding) throws -> [AnalysisPhysicalRealAudioFixtureExecutionReceipt] {
        [
            try receipt(fixtureID: "fixture-a", sourceSHA: sha("a"), runtime: runtime, runID: "run-a", executionID: "execution-a", decoderExecutionID: "decoder-a"),
            try receipt(fixtureID: "fixture-b", sourceSHA: sha("b"), runtime: runtime, runID: "run-b", executionID: "execution-b", decoderExecutionID: "decoder-b")
        ]
    }

    func testCompletePackageReopensAndFeedsExactW46ProjectRoot() throws {
        let runtime = runtime()
        let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest(),
            manifestSHA256: try manifestSHA(),
            runtime: runtime,
            receipts: validReceipts(runtime),
            generatedAt: generatedAt
        )
        XCTAssertEqual(package.status, .readyForW46ProjectInputPendingHQ)
        XCTAssertTrue(AnalysisPhysicalRealAudioCorpusAssembler.reopen(package, manifest: manifest(), evaluatedAt: generatedAt).isEmpty)
        XCTAssertEqual(package.expectedFixtureIDs, ["fixture-a", "fixture-b"])
        XCTAssertEqual(Set(package.receipts.map(\.workloadReceipt.executionID)).count, 2)
        XCTAssertEqual(package.auditedProjectReport.rows.count, 10)
        XCTAssertEqual(package.auditedProjectReportSHA256, try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(package.auditedProjectReport))
    }

    func testSelectiveFixtureSubsetFailsClosed() throws {
        let runtime = runtime()
        let receipts = try validReceipts(runtime)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: [receipts[0]], generatedAt: generatedAt
        )) { error in
            guard case let AnalysisPhysicalRealAudioCorpusExecutionError.invalid(issues) = error else { return XCTFail("unexpected error") }
            XCTAssertTrue(issues.contains { $0.code == .fixtureInventoryMismatch })
        }
    }

    func testSimulatorOrCompatibilityDecoderBindingFailsClosed() throws {
        let simulator = runtime(platform: "iphonesimulator")
        let simulatorIssues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: simulator, receipts: [], evaluatedAt: generatedAt
        )
        XCTAssertTrue(simulatorIssues.contains { $0.code == .invalidRuntimeBinding })

        let compatibility = runtime(decoderKind: .compatibilityWholeSignal)
        let compatibilityIssues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: compatibility, receipts: [], evaluatedAt: generatedAt
        )
        XCTAssertTrue(compatibilityIssues.contains { $0.code == .nonGenuineDecoder })
    }

    func testSourceSHADriftAndObservedSampleDriftFailClosed() throws {
        let runtime = runtime()
        var receipts = try validReceipts(runtime)
        receipts[0] = try receipt(
            fixtureID: "fixture-a", sourceSHA: sha("c"), runtime: runtime, runID: "run-a", executionID: "execution-a", decoderExecutionID: "decoder-a", observedSamples: 799
        )
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: receipts, evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .sourceBindingMismatch && $0.fixtureID == "fixture-a" })
        XCTAssertTrue(issues.contains { $0.code == .sourceObservationMismatch && $0.fixtureID == "fixture-a" })
    }

    func testReusedWorkloadAndDecoderExecutionIDsFailClosed() throws {
        let runtime = runtime()
        let a = try receipt(fixtureID: "fixture-a", sourceSHA: sha("a"), runtime: runtime, runID: "run-a", executionID: "same-execution", decoderExecutionID: "same-decoder")
        let b = try receipt(fixtureID: "fixture-b", sourceSHA: sha("b"), runtime: runtime, runID: "run-b", executionID: "same-execution", decoderExecutionID: "same-decoder")
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: [a, b], evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .duplicateExecutionID })
        XCTAssertTrue(issues.contains { $0.code == .duplicateDecoderExecutionID })
    }

    func testMissingStageFailsClosed() throws {
        let runtime = runtime()
        let incomplete = Array(AnalysisDeviceWorkloadStage.requiredCompleteOrder.dropLast()).enumerated().map {
            AnalysisDeviceWorkloadStageEvent(stage: $0.element, startedOffsetSeconds: Double($0.offset), endedOffsetSeconds: Double($0.offset) + 0.5, status: .completed)
        }
        var receipts = try validReceipts(runtime)
        receipts[0] = try receipt(
            fixtureID: "fixture-a", sourceSHA: sha("a"), runtime: runtime, runID: "run-a", executionID: "execution-a", decoderExecutionID: "decoder-a", stages: incomplete
        )
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: receipts, evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .invalidWorkloadStages && $0.fixtureID == "fixture-a" })
    }

    func testSnapshotMutationWithRecomputedWorkloadBindingCannotReuseOldProjectReport() throws {
        let runtime = runtime()
        let baseReceipts = try validReceipts(runtime)
        let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: baseReceipts, generatedAt: generatedAt
        )
        let changedSnapshot = AnalysisSnapshot(
            tempo: .init(bpm: 80, confidence: 0.1, beatTimesSeconds: [0.75, 1.5]),
            key: .init(tonicPitchClass: 7, mode: "minor", confidence: 0.1),
            chords: [.init(startSeconds: 0, endSeconds: 8, normalizedLabel: "G:min", confidence: 0.1)],
            sections: [.init(startSeconds: 0, endSeconds: 8, structuralLabel: "B", functionalLabel: "chorus", confidence: 0.1)]
        )
        var mutatedReceipts = baseReceipts
        mutatedReceipts[0] = try receipt(
            fixtureID: "fixture-a", sourceSHA: sha("a"), runtime: runtime, runID: "run-a", executionID: "execution-a", decoderExecutionID: "decoder-a", snapshot: changedSnapshot
        )
        let forged = AnalysisPhysicalRealAudioCorpusExecutionPackage(
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            runtime: package.runtime,
            runtimeBindingSHA256: package.runtimeBindingSHA256,
            expectedFixtureIDs: package.expectedFixtureIDs,
            receipts: mutatedReceipts,
            auditedProjectReport: package.auditedProjectReport,
            auditedProjectReportSHA256: package.auditedProjectReportSHA256,
            limitations: package.limitations,
            declaredPackageRootSHA256: package.declaredPackageRootSHA256
        )
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.reopen(forged, manifest: manifest(), evaluatedAt: generatedAt)
        XCTAssertTrue(issues.contains { $0.code == .reportRebuildMismatch })
        XCTAssertTrue(issues.contains { $0.code == .packageRootMismatch })
    }

    func testPackageRootTamperFailsClosed() throws {
        let runtime = runtime()
        let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: validReceipts(runtime), generatedAt: generatedAt
        )
        let tampered = AnalysisPhysicalRealAudioCorpusExecutionPackage(
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            runtime: package.runtime,
            runtimeBindingSHA256: package.runtimeBindingSHA256,
            expectedFixtureIDs: package.expectedFixtureIDs,
            receipts: package.receipts,
            auditedProjectReport: package.auditedProjectReport,
            auditedProjectReportSHA256: package.auditedProjectReportSHA256,
            limitations: package.limitations,
            declaredPackageRootSHA256: sha("9")
        )
        XCTAssertTrue(AnalysisPhysicalRealAudioCorpusAssembler.reopen(tampered, manifest: manifest(), evaluatedAt: generatedAt).contains { $0.code == .packageRootMismatch })
    }

    func testCanonicalPackageCodecRoundTripReopens() throws {
        let runtime = runtime()
        let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
            manifest: manifest(),
            manifestSHA256: try manifestSHA(),
            runtime: runtime,
            receipts: validReceipts(runtime),
            generatedAt: generatedAt
        )
        let encoded = try AnalysisPhysicalRealAudioCorpusCodec.encode(package)
        let decoded = try AnalysisPhysicalRealAudioCorpusCodec.decode(encoded)
        XCTAssertEqual(decoded, package)
        XCTAssertTrue(AnalysisPhysicalRealAudioCorpusAssembler.reopen(decoded, manifest: manifest(), evaluatedAt: generatedAt).isEmpty)
    }

    func testSyntheticFixtureFailsClosedEvenWithOtherwiseValidShape() throws {
        let base = manifest()
        let first = base.cases[0]
        let synthetic = AnalysisRealAudioBenchmarkCase(
            fixtureID: first.fixtureID,
            projectID: first.projectID,
            assetID: first.assetID,
            relativePath: first.relativePath,
            genre: first.genre,
            sourceKind: .syntheticTest,
            expectedDurationSeconds: first.expectedDurationSeconds,
            rights: first.rights,
            reference: first.reference
        )
        let altered = AnalysisRealAudioBenchmarkManifest(
            manifestID: base.manifestID,
            createdAt: base.createdAt,
            cases: [synthetic, base.cases[1]]
        )
        let alteredSHA = AnalysisDeviceWorkloadSHA256.hexDigest(try AnalysisRealAudioBenchmarkCodec.encodeManifest(altered))
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: altered,
            manifestSHA256: alteredSHA,
            runtime: runtime(),
            receipts: [],
            evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .nonRealFixture && $0.fixtureID == "fixture-a" })
    }

    func testDuplicateRunIDFailsClosedIndependentlyOfExecutionIDs() throws {
        let runtime = runtime()
        let a = try receipt(fixtureID: "fixture-a", sourceSHA: sha("a"), runtime: runtime, runID: "same-run", executionID: "execution-a", decoderExecutionID: "decoder-a")
        let b = try receipt(fixtureID: "fixture-b", sourceSHA: sha("b"), runtime: runtime, runID: "same-run", executionID: "execution-b", decoderExecutionID: "decoder-b")
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: try manifestSHA(), runtime: runtime, receipts: [a, b], evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .duplicateRunID })
    }

    func testManifestSHADriftFailsClosedBeforeReceiptUse() throws {
        let issues = AnalysisPhysicalRealAudioCorpusAssembler.validateInputs(
            manifest: manifest(), manifestSHA256: sha("f"), runtime: runtime(), receipts: [], evaluatedAt: generatedAt
        )
        XCTAssertTrue(issues.contains { $0.code == .invalidManifest })
    }
}
