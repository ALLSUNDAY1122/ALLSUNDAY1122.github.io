import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisCurrentDeviceWorkloadCancellationIntegrityTests: XCTestCase {
    private let sha = String(repeating: "b", count: 64)

    func testCancellationAfterObservedChunkCanEmitCompanion() async throws {
        let samples = Array(repeating: Float(0.1), count: 80_000)
        let signal = AnalysisChunkedSignal(
            descriptor: .init(sampleRate: 8_000, sampleCount: Int64(samples.count)),
            source: W36OneChunkThenBlockPuller(samples: samples),
            sourceMemoryContract: .boundedPull
        )
        let runContext = context(sampleCount: samples.count)
        let task = Task {
            await AnalysisCurrentDeviceWorkloadRunner.run(
                signal: signal,
                context: runContext
            )
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let execution = await task.value

        XCTAssertEqual(execution.outcome, .cancelled)
        XCTAssertGreaterThan(execution.observedSourceChunkCount, 0)
        XCTAssertGreaterThan(execution.observedSourceSampleCount, 0)
        XCTAssertNotNil(execution.algorithmEvidence)
        XCTAssertEqual(execution.algorithmEvidence?.captureState, .cancelledBeforeFinalization)
    }

    func testCancellationBeforeFirstSourceChunkCannotEmitCompanion() async throws {
        let sampleCount = 80_000
        let signal = AnalysisChunkedSignal(
            descriptor: .init(sampleRate: 8_000, sampleCount: Int64(sampleCount)),
            source: W36BlockBeforeFirstChunkPuller(),
            sourceMemoryContract: .boundedPull
        )
        let runContext = context(sampleCount: sampleCount)
        let task = Task {
            await AnalysisCurrentDeviceWorkloadRunner.run(
                signal: signal,
                context: runContext
            )
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let execution = await task.value

        XCTAssertEqual(execution.outcome, .cancelled)
        XCTAssertEqual(execution.observedSourceChunkCount, 0)
        XCTAssertEqual(execution.observedSourceSampleCount, 0)
        XCTAssertNil(execution.algorithmEvidence)
        XCTAssertNotNil(execution.failureDescription)
    }

    private func context(sampleCount: Int) -> AnalysisDeviceWorkloadRunContext {
        .init(
            runID: "cancel-run",
            runKind: .cancellationProbe,
            manifestID: "manifest",
            manifestSHA256: sha,
            source: .init(
                fixtureID: "fixture",
                sourceSHA256: sha,
                sourceDurationSeconds: Double(sampleCount) / 8_000,
                sourceSampleRate: 8_000,
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
}

private actor W36OneChunkThenBlockPuller: AnalysisPCMChunkPulling {
    private let samples: [Float]
    private var emitted = false

    init(samples: [Float]) { self.samples = samples }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try AnalysisCancellationPolicy.check()
        if emitted {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            return nil
        }
        emitted = true
        let end = min(512, samples.count)
        return .init(startSampleIndex: 0, monoSamples: Array(samples[0..<end]))
    }
}

private actor W36BlockBeforeFirstChunkPuller: AnalysisPCMChunkPulling {
    func nextChunk() async throws -> AnalysisPCMChunk? {
        try await Task.sleep(nanoseconds: 10_000_000_000)
        return nil
    }
}
