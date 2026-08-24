import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisCurrentDeviceWorkloadRunnerTests: XCTestCase {
    private let sha = String(repeating: "a", count: 64)

    func testCompleteRunUsesCurrentChunkedRuntimeAndBindsOneExecution() async throws {
        let samples = harmonicSamples(sampleRate: 8_000, seconds: 4)
        let runnerSignal = makeSignal(samples: samples, contract: .boundedPull)
        let directSignal = makeSignal(samples: samples, contract: .boundedPull)
        let context = makeContext(sampleRate: 8_000, sampleCount: samples.count, kind: .completeAnalysis)

        let execution = await AnalysisCurrentDeviceWorkloadRunner.run(
            signal: runnerSignal,
            context: context
        )
        let direct = try await AnalysisCurrentChunkedProductRuntime.analyze(signal: directSignal)

        XCTAssertEqual(execution.outcome, .completed)
        XCTAssertEqual(execution.snapshot, direct.snapshot)
        XCTAssertEqual(execution.receipt.stages.map(\.stage), AnalysisDeviceWorkloadStage.requiredCompleteOrder)
        XCTAssertTrue(execution.receipt.stages.allSatisfy { $0.status == .completed })
        XCTAssertNotNil(execution.receipt.snapshotCanonicalJSON)
        XCTAssertNotNil(execution.receipt.snapshotSHA256)
        XCTAssertTrue(execution.boundedSourceContractAccepted)
        XCTAssertEqual(execution.inputDiagnostics?.wholeSourcePCMMaterializedByChunkedPath, false)
        XCTAssertEqual(execution.featureDiagnostics?.exactSinglePreparedTraversal, true)

        let algorithm = try XCTUnwrap(execution.algorithmEvidence)
        XCTAssertEqual(algorithm.workloadExecutionID, execution.receipt.executionID)
        XCTAssertEqual(algorithm.performanceEvidenceRunID, execution.receipt.performanceEvidenceRunID)
        XCTAssertEqual(algorithm.sourceInputContract, .boundedPull)
        XCTAssertEqual(algorithm.captureState, .finalized)
        XCTAssertEqual(algorithm.snapshotSHA256, execution.receipt.snapshotSHA256)
        XCTAssertEqual(algorithm.runtimeIdentity?.exactSinglePreparedTraversal, true)
    }

    func testWholeSignalCompatibilityContractFailsBeforeWork() async {
        let samples = harmonicSamples(sampleRate: 8_000, seconds: 4)
        let context = makeContext(sampleRate: 8_000, sampleCount: samples.count, kind: .completeAnalysis)
        let execution = await AnalysisCurrentDeviceWorkloadRunner.run(
            signal: makeSignal(samples: samples, contract: .wholeSignalCompatibilityMaterialized),
            context: context
        )

        XCTAssertEqual(execution.outcome, .failed)
        XCTAssertFalse(execution.boundedSourceContractAccepted)
        XCTAssertTrue(execution.receipt.stages.isEmpty)
        XCTAssertNil(execution.algorithmEvidence)
        XCTAssertNil(execution.snapshot)
        XCTAssertNotNil(execution.failureDescription)
    }

    func testUnspecifiedSourceContractFailsClosed() async {
        let samples = harmonicSamples(sampleRate: 8_000, seconds: 4)
        let context = makeContext(sampleRate: 8_000, sampleCount: samples.count, kind: .completeAnalysis)
        let execution = await AnalysisCurrentDeviceWorkloadRunner.run(
            signal: makeSignal(samples: samples, contract: .unspecified),
            context: context
        )
        XCTAssertEqual(execution.outcome, .failed)
        XCTAssertTrue(execution.receipt.stages.isEmpty)
        XCTAssertNil(execution.algorithmEvidence)
    }

    func testSourceMetadataMismatchFailsBeforeWork() async {
        let samples = harmonicSamples(sampleRate: 8_000, seconds: 4)
        let wrongContext = makeContext(sampleRate: 8_000, sampleCount: samples.count + 8_000, kind: .completeAnalysis)
        let execution = await AnalysisCurrentDeviceWorkloadRunner.run(
            signal: makeSignal(samples: samples, contract: .boundedPull),
            context: wrongContext
        )
        XCTAssertEqual(execution.outcome, .failed)
        XCTAssertTrue(execution.receipt.stages.isEmpty)
        XCTAssertNil(execution.algorithmEvidence)
    }

    func testShortCompleteRunStillProducesCanonicalSevenStageReceipt() async {
        let samples = harmonicSamples(sampleRate: 8_000, seconds: 1)
        let context = makeContext(sampleRate: 8_000, sampleCount: samples.count, kind: .completeAnalysis)
        let execution = await AnalysisCurrentDeviceWorkloadRunner.run(
            signal: makeSignal(samples: samples, contract: .boundedPull),
            context: context
        )

        XCTAssertEqual(execution.outcome, .completed)
        XCTAssertEqual(execution.receipt.stages.map(\.stage), AnalysisDeviceWorkloadStage.requiredCompleteOrder)
        XCTAssertEqual(execution.snapshot, AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: []))
        XCTAssertEqual(execution.algorithmEvidence?.sourceInputContract, .boundedPull)
    }

    func testCancellationProbeEmitsTerminalCancelledStageAndNonFinalizedCompanion() async throws {
        let sampleRate = 8_000.0
        let samples = harmonicSamples(sampleRate: Int(sampleRate), seconds: 20)
        let puller = SlowAfterFirstChunkPuller(samples: samples, chunkSize: 512)
        let signal = AnalysisChunkedSignal(
            descriptor: .init(sampleRate: sampleRate, sampleCount: Int64(samples.count)),
            source: puller,
            sourceMemoryContract: .boundedPull
        )
        let context = makeContext(sampleRate: sampleRate, sampleCount: samples.count, kind: .cancellationProbe)

        let task = Task {
            await AnalysisCurrentDeviceWorkloadRunner.run(signal: signal, context: context)
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let execution = await task.value

        XCTAssertEqual(execution.outcome, .cancelled)
        XCTAssertEqual(execution.receipt.stages.last?.status, .cancelled)
        XCTAssertTrue(execution.receipt.stages.dropLast().allSatisfy { $0.status == .completed })
        XCTAssertNil(execution.receipt.snapshotCanonicalJSON)
        XCTAssertNil(execution.receipt.snapshotSHA256)
        let algorithm = try XCTUnwrap(execution.algorithmEvidence)
        XCTAssertEqual(algorithm.captureState, .cancelledBeforeFinalization)
        XCTAssertNil(algorithm.runtimeIdentity)
        XCTAssertNil(algorithm.runtimeIdentitySHA256)
        XCTAssertEqual(algorithm.sourceInputContract, .boundedPull)
        XCTAssertEqual(algorithm.workloadExecutionID, execution.receipt.executionID)
    }

    private func makeSignal(
        samples: [Float],
        contract: AnalysisChunkedSourceMemoryContract
    ) -> AnalysisChunkedSignal {
        AnalysisChunkedSignal(
            descriptor: .init(sampleRate: 8_000, sampleCount: Int64(samples.count)),
            source: ArrayChunkPuller(samples: samples, chunkSize: 257),
            sourceMemoryContract: contract
        )
    }

    private func makeContext(
        sampleRate: Double,
        sampleCount: Int,
        kind: AnalysisDevicePerformanceRunKind
    ) -> AnalysisDeviceWorkloadRunContext {
        AnalysisDeviceWorkloadRunContext(
            runID: "run-\(kind.rawValue.lowercased())",
            runKind: kind,
            manifestID: "manifest",
            manifestSHA256: sha,
            source: .init(
                fixtureID: "fixture",
                sourceSHA256: sha,
                sourceDurationSeconds: Double(sampleCount) / sampleRate,
                sourceSampleRate: sampleRate,
                sourceChannelCount: 1
            ),
            identity: .init(
                analyzerID: "ProjectOwnedMusicAnalyzer",
                analyzerVersion: "w36",
                analysisConfigurationID: "product-baseline",
                buildIdentity: "build"
            )
        )
    }

    private func harmonicSamples(sampleRate: Int, seconds: Int) -> [Float] {
        let count = sampleRate * seconds
        return (0..<count).map { index in
            let t = Double(index) / Double(sampleRate)
            let value = 0.30 * sin(2 * Double.pi * 261.625565 * t)
                + 0.22 * sin(2 * Double.pi * 329.627557 * t)
                + 0.18 * sin(2 * Double.pi * 391.995436 * t)
            return Float(value)
        }
    }
}

private actor ArrayChunkPuller: AnalysisPCMChunkPulling {
    private let samples: [Float]
    private let chunkSize: Int
    private var offset = 0

    init(samples: [Float], chunkSize: Int) {
        self.samples = samples
        self.chunkSize = chunkSize
    }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try AnalysisCancellationPolicy.check()
        guard offset < samples.count else { return nil }
        let start = offset
        let end = min(samples.count, start + chunkSize)
        offset = end
        return .init(startSampleIndex: Int64(start), monoSamples: Array(samples[start..<end]))
    }
}

private actor SlowAfterFirstChunkPuller: AnalysisPCMChunkPulling {
    private let samples: [Float]
    private let chunkSize: Int
    private var offset = 0
    private var emittedFirst = false

    init(samples: [Float], chunkSize: Int) {
        self.samples = samples
        self.chunkSize = chunkSize
    }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try AnalysisCancellationPolicy.check()
        guard offset < samples.count else { return nil }
        if emittedFirst {
            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        let start = offset
        let end = min(samples.count, start + chunkSize)
        offset = end
        emittedFirst = true
        return .init(startSampleIndex: Int64(start), monoSamples: Array(samples[start..<end]))
    }
}
