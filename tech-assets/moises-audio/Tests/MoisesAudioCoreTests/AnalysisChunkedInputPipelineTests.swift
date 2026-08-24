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
            XCTAssertLessThanOrEqual(result.inputDiagnostics.maximumSourceChunkSamples, chunkSize)
            XCTAssertFalse(result.inputDiagnostics.wholeSourcePCMMaterializedByChunkedPath)
            XCTAssertTrue(result.inputDiagnostics.contiguousCompleteSource)
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
        XCTAssertEqual(chunked.inputDiagnostics.sanitizedSourceSampleCount, 2)
    }

    func testGapOverlapAndOutOfOrderChunksFailClosed() async {
        for badStart in [101, 99, 500] {
            let stream = AsyncThrowingStream<AnalysisPCMChunk, Error> { continuation in
                continuation.yield(.init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 100)))
                continuation.yield(.init(startSampleIndex: Int64(badStart), monoSamples: Array(repeating: 0, count: 100)))
                continuation.finish()
            }
            let source = AnalysisChunkedSignal(
                descriptor: .init(sampleRate: 44_100, sampleCount: 200),
                chunks: stream
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
                    chunks: AsyncThrowingStream { continuation in
                        continuation.yield(.init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 100)))
                        continuation.finish()
                    }
                )
            )
            XCTFail("Truncated stream must fail")
        } catch let error as AnalysisChunkedInputError {
            XCTAssertEqual(error, .sourceSampleCountMismatch(expected: 200, actual: 100))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: AnalysisChunkedSignal(
                    descriptor: .init(sampleRate: 44_100, sampleCount: 100),
                    chunks: AsyncThrowingStream { continuation in
                        continuation.yield(.init(startSampleIndex: 0, monoSamples: Array(repeating: 0, count: 101)))
                        continuation.finish()
                    }
                )
            )
            XCTFail("Overrun stream must fail")
        } catch let error as AnalysisChunkedInputError {
            XCTAssertEqual(error, .chunkExceedsDeclaredSampleCount(declared: 100, actualEnd: 101))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await AnalysisChunkedPreparedFeatureExtractor.extract(
                signal: AnalysisChunkedSignal(
                    descriptor: .init(sampleRate: 44_100, sampleCount: 1),
                    chunks: AsyncThrowingStream { continuation in
                        continuation.yield(.init(startSampleIndex: 0, monoSamples: []))
                        continuation.finish()
                    }
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

    func testChunkedPipelineCanBeCancelledBeforePublication() async {
        let samples = w30Fixture(seconds: 20, sampleRate: 44_100)
        let task = Task {
            try await AnalysisChunkedSinglePassPreparedPipeline.analyze(
                signal: w30ChunkedSignal(samples: samples, sampleRate: 44_100, chunkSize: 64)
            )
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

private func w30ChunkedSignal(
    samples: [Float],
    sampleRate: Double,
    chunkSize: Int
) -> AnalysisChunkedSignal {
    let descriptor = AnalysisChunkedSignalDescriptor(
        sampleRate: sampleRate,
        sampleCount: Int64(samples.count)
    )
    let stream = AsyncThrowingStream<AnalysisPCMChunk, Error> { continuation in
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunkSize)
            continuation.yield(
                .init(
                    startSampleIndex: Int64(start),
                    monoSamples: Array(samples[start..<end])
                )
            )
            start = end
        }
        continuation.finish()
    }
    return .init(descriptor: descriptor, chunks: stream)
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
