import XCTest
@testable import MoisesAudioCore

final class AnalysisCancellationTests: XCTestCase {
    private struct StaticSignalLoader: AnalysisSignalLoading {
        let signal: AnalysisSignal
        func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal {
            signal
        }
    }

    func testPreCancelledPreparationThrowsCancellation() async {
        let signal = AnalysisSignal(
            sampleRate: 44_100,
            monoSamples: Array(repeating: 0.1, count: 44_100 * 30)
        )
        let task = Task<Int, Error> {
            try AnalysisWorkingSetPolicy.prepareCancellable(signal: signal).signal.monoSamples.count
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancelled preparation must not return a prepared signal")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testTempoCancellationIsObservedDuringLongLoop() async {
        let signal = Self.pulseSignal(seconds: 600)
        let latency = await Self.measureCancellationLatency {
            _ = try BoundedTempoBeatAnalyzer.analyzeCancellable(signal: signal)
        }
        XCTAssertNotNil(latency)
        XCTAssertLessThan(latency ?? .infinity, 0.25)
    }

    func testChordCancellationIsObservedDuringLongLoop() async {
        let signal = AnalysisSignal(
            sampleRate: 8_000,
            monoSamples: Array(repeating: 0.2, count: 8_000 * 300)
        )
        let latency = await Self.measureCancellationLatency {
            _ = try BoundedChordTimelineAnalyzer.analyzeCancellable(signal: signal)
        }
        XCTAssertNotNil(latency)
        XCTAssertLessThan(latency ?? .infinity, 0.25)
    }

    func testPreCancelledKeyAnalysisThrowsCancellation() async {
        let signal = AnalysisSignal(
            sampleRate: 8_000,
            monoSamples: Array(repeating: 0.1, count: 8_000 * 30)
        )
        let task = Task<Void, Error> {
            _ = try BoundedMusicalKeyAnalyzer.analyzeCancellable(signal: signal)
        }
        task.cancel()
        do {
            try await task.value
            XCTFail("cancelled key analysis must not return")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testNonCancelledTempoCompatibilityAPIMatchesCancellableAPI() throws {
        let signal = Self.pulseSignal(seconds: 20)
        let compatibility = BoundedTempoBeatAnalyzer.analyze(signal: signal)
        let cancellable = try BoundedTempoBeatAnalyzer.analyzeCancellable(signal: signal)
        XCTAssertEqual(compatibility, cancellable)
    }

    func testProjectAnalyzerCancellationNeverPublishesPartialSnapshot() async {
        let signal = Self.pulseSignal(seconds: 600)
        let loader = StaticSignalLoader(signal: signal)
        let analyzer = ProjectOwnedMusicAnalyzer(loader: loader)
        let asset = LocalAudioAsset(
            id: AssetID(),
            relativePath: "fixture.wav",
            mediaKind: .audio,
            durationSeconds: signal.durationSeconds
        )
        let projectID = ProjectID()

        let task = Task<AnalysisSnapshot, Error> {
            try await analyzer.analyze(projectID: projectID, asset: asset)
        }
        try? await Task.sleep(nanoseconds: 2_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("cancelled combined analysis must not publish a partial snapshot")
        } catch is CancellationError {
            // expected: no snapshot value crossed the frozen contract boundary.
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    private static func measureCancellationLatency(
        operation: @escaping @Sendable () throws -> Void
    ) async -> Double? {
        let task = Task<Void, Error> { try operation() }
        try? await Task.sleep(nanoseconds: 2_000_000)
        let cancelAt = ProcessInfo.processInfo.systemUptime
        task.cancel()
        do {
            try await task.value
            return nil
        } catch is CancellationError {
            return ProcessInfo.processInfo.systemUptime - cancelAt
        } catch {
            return nil
        }
    }

    private static func pulseSignal(seconds: Int, sampleRate: Int = 8_000, bpm: Double = 120) -> AnalysisSignal {
        let count = seconds * sampleRate
        var samples = Array(repeating: Float(0), count: count)
        let spacing = max(1, Int(Double(sampleRate) * 60 / bpm))
        for start in stride(from: 0, to: count, by: spacing) {
            let end = min(count, start + 64)
            guard start < end else { continue }
            for index in start..<end {
                samples[index] = Float(1 - Double(index - start) / 64)
            }
        }
        return AnalysisSignal(sampleRate: Double(sampleRate), monoSamples: samples)
    }
}
