import XCTest
@testable import MoisesAudioCore

final class AnalysisDeviceWorkloadReceiptTests: XCTestCase {
    private let sourceSHA = String(repeating: "a", count: 64)
    private let manifestSHA = String(repeating: "b", count: 64)
    private let fixedDate = Date(timeIntervalSince1970: 1_787_500_000)

    private var source: AnalysisDeviceWorkloadSourceBinding {
        .init(fixtureID: "fixture-1", sourceSHA256: sourceSHA, sourceDurationSeconds: 120, sourceSampleRate: 44_100, sourceChannelCount: 2)
    }
    private var identity: AnalysisDeviceWorkloadIdentity {
        .init(analyzerID: "ProjectOwnedMusicAnalyzer", analyzerVersion: "lane4-w25", analysisConfigurationID: "product-baseline-v1", buildIdentity: "build-101")
    }
    private var policy: AnalysisDeviceWorkloadPolicy {
        .init(authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W25-APPROVED", manifestID: "manifest-1", manifestSHA256: manifestSHA, identity: identity, fixtures: ["fixture-1": source])
    }
    private var snapshot: AnalysisSnapshot { .init(tempo: nil, key: nil, chords: [], sections: []) }
    private var completeStages: [AnalysisDeviceWorkloadStageEvent] {
        AnalysisDeviceWorkloadStage.requiredCompleteOrder.enumerated().map { index, stage in
            .init(stage: stage, startedOffsetSeconds: Double(index) * 0.1, endedOffsetSeconds: Double(index) * 0.1 + 0.05, status: .completed)
        }
    }

    private func evidence(
        runID: String = "run-1",
        kind: AnalysisDevicePerformanceRunKind = .completeAnalysis,
        manifestID: String = "manifest-1",
        manifestSHA256: String? = nil,
        fixtureID: String = "fixture-1",
        completedNormally: Bool? = nil,
        requested: Double? = nil,
        observed: Double? = nil
    ) -> AnalysisDevicePerformanceEvidence {
        .init(
            provenance: .init(
                runID: runID, runKind: kind, startedAt: fixedDate,
                runtimeClass: .physicalIOSDevice, deviceModel: "iPhone", osVersion: "26.6",
                appBundleIdentifier: "example.moises", appVersion: "1", buildVersion: "101",
                manifestID: manifestID, manifestSHA256: manifestSHA256 ?? manifestSHA,
                fixtureID: fixtureID, fixtureDurationSeconds: 120
            ),
            finishedAt: fixedDate.addingTimeInterval(2), wallSeconds: 2,
            requestedSampleIntervalSeconds: 1, maximumSampleCount: 10,
            memoryTelemetry: .availableChannel, thermalTelemetry: .availableChannel,
            batteryTelemetry: .availableChannel, memoryPressureObservation: .availableChannel,
            memorySamples: [], thermalSamples: [], batterySamples: [], memoryPressureEvents: [],
            cancellation: .init(requestedOffsetSeconds: requested, observedTerminationOffsetSeconds: observed),
            completedNormally: completedNormally ?? (kind == .completeAnalysis)
        )
    }

    private func receipt(
        runID: String = "run-1",
        performanceID: String? = nil,
        kind: AnalysisDevicePerformanceRunKind = .completeAnalysis,
        manifestID: String = "manifest-1",
        manifestSHA256: String? = nil,
        source: AnalysisDeviceWorkloadSourceBinding? = nil,
        executionID: String = "execution-1",
        stages: [AnalysisDeviceWorkloadStageEvent]? = nil,
        snapshotData: Data?? = nil,
        snapshotSHA256: String?? = nil,
        outputSummary: AnalysisDeviceWorkloadOutputSummary?? = nil
    ) throws -> AnalysisDeviceWorkloadReceipt {
        let selectedSource = source ?? self.source
        let selectedStages = stages ?? completeStages
        let canonical = try AnalysisSnapshotRobustness.canonicalJSON(snapshot)
        let selectedData = snapshotData ?? .some(canonical)
        let selectedHash = snapshotSHA256 ?? .some(AnalysisDeviceWorkloadSHA256.hexDigest(canonical))
        let selectedSummary = outputSummary ?? .some(.init(snapshot: snapshot))
        let selectedManifestSHA = manifestSHA256 ?? manifestSHA
        let started = fixedDate.addingTimeInterval(0.1)
        let performanceID = performanceID ?? runID
        let binding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
            runID: runID, performanceEvidenceRunID: performanceID, runKind: kind,
            manifestID: manifestID, manifestSHA256: selectedManifestSHA, source: selectedSource,
            identity: identity, executionID: executionID, workloadStartedAt: started,
            stages: selectedStages, snapshotSHA256: selectedHash, outputSummary: selectedSummary
        )
        return .init(
            runID: runID, performanceEvidenceRunID: performanceID, runKind: kind,
            manifestID: manifestID, manifestSHA256: selectedManifestSHA, source: selectedSource,
            identity: identity, executionID: executionID, workloadStartedAt: started,
            stages: selectedStages, snapshotCanonicalJSON: selectedData, snapshotSHA256: selectedHash,
            outputSummary: selectedSummary, executionBindingSHA256: binding
        )
    }

    private func contains(_ report: AnalysisDeviceWorkloadValidationReport, _ code: AnalysisDeviceWorkloadIssueCode) -> Bool {
        report.issues.contains { $0.code == code }
    }

    func testValidFullWorkloadAndDeterministicCodec() throws {
        let value = try receipt()
        let report = AnalysisDeviceWorkloadReceiptValidator.validate(value, performanceEvidence: evidence(), policy: policy)
        XCTAssertEqual(report.status, .fullWorkloadCompletePendingHQ)
        XCTAssertEqual(try AnalysisDeviceWorkloadReceiptCodec.canonicalJSON(value), try AnalysisDeviceWorkloadReceiptCodec.canonicalJSON(value))
        XCTAssertEqual(AnalysisDeviceWorkloadSHA256.hexDigest(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testMissingTempoAndSectionFailClosed() throws {
        var stages = completeStages; stages.remove(at: 1)
        var report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(stages: stages), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .missingRequiredStage)); XCTAssertTrue(contains(report, .stageOrderViolation))
        stages = completeStages; stages.remove(at: 5)
        report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(stages: stages), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .missingRequiredStage))
    }

    func testOrderAndDuplicateStageFailClosed() throws {
        var stages = completeStages; stages.swapAt(1, 2)
        var report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(stages: stages), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .stageOrderViolation))
        stages = completeStages; stages.insert(stages[1], at: 2)
        report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(stages: stages), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .duplicateStage))
    }

    func testRunManifestAndSourceSwapsFailClosed() throws {
        var report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(runID: "run-x"), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .performanceBindingMismatch))
        report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(manifestID: "manifest-x"), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .manifestBindingMismatch))
        let swapped = AnalysisDeviceWorkloadSourceBinding(fixtureID: "fixture-1", sourceSHA256: manifestSHA, sourceDurationSeconds: 120, sourceSampleRate: 44_100, sourceChannelCount: 2)
        report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(source: swapped), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .sourceBindingMismatch))
    }

    func testSnapshotTamperingFailsClosed() throws {
        let report = AnalysisDeviceWorkloadReceiptValidator.validate(try receipt(snapshotSHA256: .some(sourceSHA)), performanceEvidence: evidence(), policy: policy)
        XCTAssertTrue(contains(report, .snapshotHashMismatch))
    }

    func testCopiedExecutionReceiptAcrossRunsFailsClosedButEqualSnapshotsAreAllowed() throws {
        let copiedA = try receipt(runID: "run-a", executionID: "same-execution")
        let copiedB = try receipt(runID: "run-b", executionID: "same-execution")
        let copied = AnalysisDeviceWorkloadReceiptValidator.validateBatch(receipts: [copiedA, copiedB], performanceRuns: [evidence(runID: "run-a"), evidence(runID: "run-b")], policy: policy)
        XCTAssertTrue(copied.contains { contains($0, .reusedExecution) })

        let independentA = try receipt(runID: "run-a", executionID: "exec-a")
        let independentB = try receipt(runID: "run-b", executionID: "exec-b")
        let independent = AnalysisDeviceWorkloadReceiptValidator.validateBatch(receipts: [independentA, independentB], performanceRuns: [evidence(runID: "run-a"), evidence(runID: "run-b")], policy: policy)
        XCTAssertTrue(independent.allSatisfy { $0.status == .fullWorkloadCompletePendingHQ })
        XCTAssertEqual(independentA.snapshotSHA256, independentB.snapshotSHA256)
    }

    func testCancellationRequiresRealWorkAndConsistentTelemetry() throws {
        let beforeStages = [AnalysisDeviceWorkloadStageEvent(stage: .signalPreparation, startedOffsetSeconds: 0.5, endedOffsetSeconds: 0.6, status: .cancelled)]
        let before = try receipt(kind: .cancellationProbe, stages: beforeStages, snapshotData: .some(nil), snapshotSHA256: .some(nil), outputSummary: .some(nil))
        var report = AnalysisDeviceWorkloadReceiptValidator.validate(before, performanceEvidence: evidence(kind: .cancellationProbe, completedNormally: false, requested: 0.1, observed: 0.7), policy: policy)
        XCTAssertTrue(contains(report, .noRealWorkBeforeCancellation))

        let afterStages = [
            AnalysisDeviceWorkloadStageEvent(stage: .signalPreparation, startedOffsetSeconds: 0.01, endedOffsetSeconds: 0.05, status: .completed),
            AnalysisDeviceWorkloadStageEvent(stage: .tempo, startedOffsetSeconds: 0.05, endedOffsetSeconds: 0.15, status: .cancelled)
        ]
        let after = try receipt(kind: .cancellationProbe, stages: afterStages, snapshotData: .some(nil), snapshotSHA256: .some(nil), outputSummary: .some(nil))
        report = AnalysisDeviceWorkloadReceiptValidator.validate(after, performanceEvidence: evidence(kind: .cancellationProbe, completedNormally: false, requested: 0.1, observed: 0.2), policy: policy)
        XCTAssertEqual(report.status, .realWorkCancellationPendingHQ)
    }

    func testCompleteAndCancelSemanticsCannotBeMixed() throws {
        let value = try receipt(kind: .cancellationProbe)
        let report = AnalysisDeviceWorkloadReceiptValidator.validate(value, performanceEvidence: evidence(kind: .cancellationProbe, completedNormally: false, requested: 0.2, observed: 1.0), policy: policy)
        XCTAssertTrue(contains(report, .semanticMismatch))
    }
}
