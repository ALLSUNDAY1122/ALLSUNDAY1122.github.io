import Foundation
import XCTest

final class SplatReconstructionTelemetryTests: XCTestCase {
    func testResourcePauseReasonMapsToStructuredStopReason() {
        XCTAssertEqual(
            SplatReconstructionStopReason(resourcePauseReason: .memoryWarning),
            .memoryWarning
        )
        XCTAssertEqual(
            SplatReconstructionStopReason(resourcePauseReason: .availableMemoryReserve),
            .availableMemoryReserve
        )
        XCTAssertEqual(
            SplatReconstructionStopReason(resourcePauseReason: .residentMemoryBudget),
            .residentMemoryBudget
        )
        XCTAssertEqual(
            SplatReconstructionStopReason(resourcePauseReason: .thermalPressure),
            .thermal
        )
    }

    func testOutcomeInferenceKeepsMemoryWarningSeparateFromResidentBudget() {
        XCTAssertEqual(
            SplatReconstructionStopReason.inferred(from: "paused-memoryWarning"),
            .memoryWarning
        )
        XCTAssertEqual(
            SplatReconstructionStopReason.inferred(from: "paused-residentMemoryBudget"),
            .residentMemoryBudget
        )
        XCTAssertEqual(
            SplatReconstructionPhase.inferred(from: "preflight-availableMemoryReserve"),
            .preflight
        )
        XCTAssertEqual(
            SplatReconstructionPhase.inferred(from: "paused-availableMemoryReserve"),
            .trainingStep
        )
    }

    func testCheckpointResumeOutcomeDistinguishesMissingLoadedZeroLoadedProgressAndFailed() {
        XCTAssertEqual(
            SplatCheckpointResumeOutcome.classify(checkpointExists: false, loadedIteration: nil),
            .noCheckpoint
        )
        XCTAssertEqual(
            SplatCheckpointResumeOutcome.classify(checkpointExists: true, loadedIteration: 0),
            .loaded,
            "Iteration zero can be a valid checkpoint and must not be rejected"
        )
        XCTAssertEqual(
            SplatCheckpointResumeOutcome.classify(checkpointExists: true, loadedIteration: 240),
            .loaded
        )
        XCTAssertEqual(
            SplatCheckpointResumeOutcome.classify(checkpointExists: true, loadedIteration: nil),
            .loadFailed
        )
    }

    func testTrainingRunGateDoesNotAdmitRetryUntilPreviousRunFinishesCleanup() {
        let gate = SplatTrainingRunGate()
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let first = gate.beginRun(id: firstID)
        XCTAssertNotNil(first)
        XCTAssertFalse(gate.isIdle)
        XCTAssertNil(gate.beginRun(id: secondID), "A retry must not overlap the previous Dataset/Trainer lifetime")

        gate.finishRun(first!)
        XCTAssertTrue(gate.isIdle)
        XCTAssertNotNil(gate.beginRun(id: secondID))
    }

    func testV3ReportSerializesStructuredEvidence() throws {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()
        _ = guardrail.evaluate(
            splatCount: 123_456,
            residentMemoryBytes: 777_000_000,
            availableMemoryBytes: 555_000_000,
            thermalState: .fair
        )
        let runID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let context = SplatReconstructionRunContext(
            runID: runID,
            sessionID: "scan-session-1",
            sourceFrameCount: 72,
            sourceImageWidth: 1920,
            sourceImageHeight: 1440,
            effectiveDownscale: 2,
            checkpointPath: "training.msplat-checkpoint"
        )

        let report = guardrail.makeReport(
            startedAt: Date(timeIntervalSince1970: 1_000),
            startUptime: ProcessInfo.processInfo.systemUptime,
            passStartIteration: 400,
            targetIteration: 7_000,
            finalIteration: 520,
            finalSplatCount: 123_456,
            initialThermalState: "nominal",
            finalThermalState: "fair",
            outcome: "paused-residentMemoryBudget",
            context: context,
            phase: .trainingStep,
            stopReason: .residentMemoryBudget,
            checkpointIteration: 520,
            resumeOutcome: .loaded
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        let decoded = try JSONDecoder.withISO8601Dates.decode(SplatReconstructionRunReport.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 3)
        XCTAssertEqual(decoded.runID, runID.uuidString)
        XCTAssertEqual(decoded.sessionID, "scan-session-1")
        XCTAssertEqual(decoded.phase, .trainingStep)
        XCTAssertEqual(decoded.stopReason, .residentMemoryBudget)
        XCTAssertEqual(decoded.sourceFrameCount, 72)
        XCTAssertEqual(decoded.sourceImageWidth, 1920)
        XCTAssertEqual(decoded.sourceImageHeight, 1440)
        XCTAssertEqual(decoded.effectiveDownscale, 2)
        XCTAssertEqual(decoded.currentResidentMemoryBytes, 777_000_000)
        XCTAssertEqual(decoded.currentAvailableMemoryBytes, 555_000_000)
        XCTAssertEqual(decoded.worstThermalState, "fair")
        XCTAssertEqual(decoded.checkpointIteration, 520)
        XCTAssertEqual(decoded.resumeOutcome, .loaded)
    }

    func testV2ReportRemainsDecodableAfterV3OptionalFieldsAreAdded() throws {
        let json = """
        {
          "schemaVersion": 2,
          "startedAt": "2026-08-25T00:00:00Z",
          "finishedAt": "2026-08-25T00:01:00Z",
          "elapsedSeconds": 60,
          "passStartIteration": 0,
          "targetIteration": 7000,
          "finalIteration": 120,
          "finalSplatCount": 50000,
          "peakSplatCount": 51000,
          "peakResidentMemoryBytes": 800000000,
          "residentMemoryBudgetBytes": 1200000000,
          "minimumAvailableMemoryBytes": 400000000,
          "minimumAvailableMemoryReserveBytes": 300000000,
          "maxSplatCount": 500000,
          "physicalMemoryBytes": 8000000000,
          "initialThermalState": "nominal",
          "finalThermalState": "nominal",
          "outcome": "paused-memoryWarning"
        }
        """
        let decoded = try JSONDecoder.withISO8601Dates.decode(
            SplatReconstructionRunReport.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertNil(decoded.runID)
        XCTAssertNil(decoded.phase)
        XCTAssertNil(decoded.stopReason)
        XCTAssertEqual(decoded.outcome, "paused-memoryWarning")
    }
}

private extension JSONDecoder {
    static var withISO8601Dates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
