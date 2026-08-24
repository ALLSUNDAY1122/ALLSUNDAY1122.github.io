import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisChunkedInputPipelineTests: XCTestCase {
    func testChunkSizeInvariantMatchesWholeSignalW29Features() async throws {
        var samples = w30Fixture(seconds: 4, sampleRate: 44_100)
        samples[101] = .nan
        samples[777] = .infinity
        samples[1_111] = 100
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: samples)
        let whole = try AnalysisSinglePassPreparedFeatureExtractor.extract(
            reader: AnalysisPreparedSampleReader(signal: source)
        )

        for chunkSize in [3, 127, 4_096, 16_384] {
            let result = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: w30ChunkedSignal(samples: samples, sampleRate: 44_100, chunkSize: chunkSize)
            )
            XCTAssertEqual(result.features.tempoOnset, whole.tempoOnset)
            XCTAssertEqual(result.features.tempoFrameSize, whole.tempoFrameSize)
            XCTAssertEqual(result.features.tempoHopSize, whole.tempoHopSize)
            XCTAssertEqual(result.features.keyWindows, whole.keyWindows)
            XCTAssertEqual(result.features.keyGlobalRMS, whole.keyGlobalRMS)
            XCTAssertEqual(result.features.chordFrameDecisions, whole.chordFrameDecisions)
            XCTAssertEqual(result.features.sectionEnergySignal, whole.sectionEnergySignal)
            XCTAssertEqual(result.features.sampleRate, whole.sampleRate)
            XCTAssertEqual(result.features.durationSeconds, whole.durationSeconds)
            XCTAssertTrue(result.features.diagnostics.exactSinglePreparedTraversal)
            XCTAssertEqual(
                result.features.diagnostics.preparedSampleComputations,
                result.features.diagnostics.preparedSampleCount
            )
            XCTAssertLessThanOrEqual(result.diagnostics.maximumSourceChunkSamples, chunkSize)
            XCTAssertFalse(result.diagnostics.wholeSourcePCMMaterializedByChunkedPath)
            XCTAssertTrue(result.diagnostics.contiguousCompleteSource)
        }
    }

    func testSingleSampleChunksPreserveResamplingAcrossBoundaries() async throws {
        var samples = (0..<4_097).map { Float(sin(Double($0) * 0.017)) }
        samples[2] = .nan
        samples[4_096] = 32
        let whole = try AnalysisSinglePassPreparedFeatureExtractor.extract(
            reader: AnalysisPreparedSampleReader(
                signal: AnalysisSignal(sampleRate: 44_100, monoSamples: samples)
            )
        )
        let chunked = try await AnalysisChunkedPreparedFeatureExtractor.extract(
            signal: w30ChunkedSignal(samples: samples, sampleRate: 44_100, chunkSize: 1)
        )
        XCTAssertEqual(chunked.features.tempoOnset, whole.tempoOnset)
        XCTAssertEqual(chunked.features.keyWindows, whole.keyWindows)
        XCTAssertEqual(chunked.features.chordFrameDecisions, whole.chordFrameDecisions)
        XCTAssertEqual(chunked.features.sectionEnergySignal, whole.sectionEnergySignal)
        XCTAssertEqual(chunked.diagnostics.sanitizedSourceSampleCount, 2)
    }

    func testGapOverlapAndOutOfOrderChunksFailClosed() async {
        for badStart in [101, 99, 500] {
            let source = AnalysisChunkedSignal(
                descriptor: .init(sampleRate: 44_100, sampleCount: 200),
                source: W30ScriptedChunkPuller(chunks: [
                    .init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 100)),
                    .init(startSampleIndex: Int64(badStart), monoSamples: Array(repeating: 0, count: 100))
                ])
            )
            do {
                _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(signal: source)
                XCTFail("Malformed chunk ordering must fail")
            } catch let error as AnalysisChunkedInputError {
                XCTAssertEqual(error, .nonContiguousChunk(expected: 100, actual: Int64(badStart)))
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTruncatedOverrunAndEmptyChunksFailClosed() async {
        do {
            _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: AnalysisChunkedSignal(
                    descriptor: .init(sampleRate: 44_100, sampleCount: 200),
                    source: W30ScriptedChunkPuller(chunks: [
                        .init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 100))
                    ])
                )
            )
            XCTFail("Truncated source must fail")
        } catch let error as AnalysisChunkedInputError {
            XCTAssertEqual(error, .sourceSampleCountMismatch(expected: 200, actual: 100))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: AnalysisChunkedSignal(
                    descriptor: .init(sampleRate: 44_100, sampleCount: 100),
                    source: W30ScriptedChunkPuller(chunks: [
                        .init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 101))
                    ])
                )
            )
            XCTFail("Overrun source must fail")
        } catch let error as AnalysisChunkedInputError {
            XCTAssertEqual(error, .chunkExceedsDeclaredSampleCount(declared: 100, actualEnd: 101))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: AnalysisChunkedSignal(
                    descriptor: .init(sampleRate: 44_100, sampleCount: 1),
                    source: W30ScriptedChunkPuller(chunks: [
                        .init(startSampleIndex: 0, monoSamples: [])
                    ])
                )
            )
            XCTFail("Empty chunk must fail")
        } catch let error as AnalysisChunkedInputError {
            XCTAssertEqual(error, .emptyChunk(startSampleIndex: 0))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOneHourAndTwentyFourHourBudgetAvoidWholeSourceRetention() {
        let oneHour = AnalysisChunkedInputBudget.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 3_600,
            maximumChunkSamples: 32_768
        )
        XCTAssertEqual(oneHour.declaredWholeSourcePCMBytes, 635_040_000)
        XCTAssertEqual(oneHour.maximumChunkPCMBytes, 131_072)
        XCTAssertEqual(oneHour.estimatedChunkedAnalysisWorkingSetBytes, 10_766_976)
        XCTAssertGreaterThan(oneHour.sourceToMaximumChunkReductionRatio, 4_800)
        XCTAssertFalse(oneHour.wholeSourcePCMMaterializedByChunkedPath)

        let day = AnalysisChunkedInputBudget.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 86_400,
            maximumChunkSamples: 32_768
        )
        XCTAssertEqual(day.declaredWholeSourcePCMBytes, 15_240_960_000)
        XCTAssertEqual(day.maximumChunkPCMBytes, 131_072)
        XCTAssertEqual(day.estimatedChunkedAnalysisWorkingSetBytes, 197_563_776)
        XCTAssertGreaterThan(day.sourceToMaximumChunkReductionRatio, 116_000)
    }

    func testChunkedPipelineCanBeCancelledWhileWaitingForNextChunk() async {
        let source = AnalysisChunkedSignal(
            descriptor: .init(sampleRate: 44_100, sampleCount: 44_100),
            source: W30SlowChunkPuller()
        )
        let task = Task {
            try await AnalysisChunkedSinglePassPreparedPipeline.analyze(signal: source)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled analysis must not publish")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor W30ArrayChunkPuller: AnalysisPCMChunkPulling {
    private let samples: [Float]
    private let chunkSize: Int
    private var nextStart = 0

    init(samples: [Float], chunkSize: Int) {
        self.samples = samples
        self.chunkSize = chunkSize
    }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try Task.checkCancellation()
        guard nextStart < samples.count else { return nil }
        let start = nextStart
        let end = min(samples.count, start + chunkSize)
        nextStart = end
        return .init(
            startSampleIndex: Int64(start),
            monoSamples: Array(samples[start..<end])
        )
    }
}

private actor W30ScriptedChunkPuller: AnalysisPCMChunkPulling {
    private let chunks: [AnalysisPCMChunk]
    private var index = 0

    init(chunks: [AnalysisPCMChunk]) {
        self.chunks = chunks
    }

    func nextChunk() async throws -> AnalysisPCMChunk? {
        try Task.checkCancellation()
        guard index < chunks.count else { return nil }
        defer { index += 1 }
        return chunks[index]
    }
}

private actor W30SlowChunkPuller: AnalysisPCMChunkPulling {
    func nextChunk() async throws -> AnalysisPCMChunk? {
        try await Task.sleep(nanoseconds: 50_000_000)
        try Task.checkCancellation()
        return .init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 1_024))
    }
}

private func w30ChunkedSignal(
    samples: [Float],
    sampleRate: Double,
    chunkSize: Int
) -> AnalysisChunkedSignal {
    .init(
        descriptor: .init(
            sampleRate: sampleRate,
            sampleCount: Int64(samples.count)
        ),
        source: W30ArrayChunkPuller(samples: samples, chunkSize: chunkSize)
    )
}

private func w30Fixture(seconds: Double, sampleRate: Double) -> [Float] {
    let count = Int((seconds * sampleRate).rounded())
    let clickSpacing = max(1, Int((0.5 * sampleRate).rounded()))
    var output = Array(repeating: Float(0), count: count)
    let frequencies = [261.625565, 329.627557, 391.995436]
    for index in output.indices {
        var value = 0.0
        for frequency in frequencies {
            value += 0.05 * sin(2 * Double.pi * frequency * Double(index) / sampleRate)
        }
        if index % clickSpacing < 24 {
            value += 0.7 * (1 - Double(index % clickSpacing) / 24)
        }
        output[index] = Float(value)
    }
    return output
}
