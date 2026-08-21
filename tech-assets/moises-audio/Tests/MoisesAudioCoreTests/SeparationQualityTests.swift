import XCTest
@testable import MoisesAudioCore

final class SeparationQualityTests: XCTestCase {
    func testSiSDRPerfectEstimateReturnsCappedValue() throws {
        let reference: [Float] = [0.5, -0.25, 0.75, -1.0]
        let result = try XCTUnwrap(SeparationQuality.siSDR(reference: reference, estimate: reference))
        XCTAssertEqual(result, 120.0, accuracy: 1e-9)
    }

    func testSiSDRIsScaleInvariantForExactScaledSignal() throws {
        let reference: [Float] = [0.5, -0.25, 0.75, -1.0]
        let estimate = reference.map { $0 * 2 }
        let result = try XCTUnwrap(SeparationQuality.siSDR(reference: reference, estimate: estimate))
        XCTAssertEqual(result, 120.0, accuracy: 1e-9)
    }

    func testSiSDRRejectsMismatchedLengths() {
        XCTAssertNil(SeparationQuality.siSDR(reference: [1, 2], estimate: [1]))
    }

    func testSiSDRRejectsSilentReference() {
        XCTAssertNil(SeparationQuality.siSDR(reference: [0, 0, 0], estimate: [0.1, 0.2, 0.3]))
    }

    func testReconstructionErrorIsZeroForExactStemSum() throws {
        let mixture = PCMBuffer(sampleRate: 44_100, channels: 1, samples: [0.5, -0.25, 0.75, -1.0])
        let stemA = PCMBuffer(sampleRate: 44_100, channels: 1, samples: [0.2, -0.1, 0.3, -0.4])
        let stemB = PCMBuffer(sampleRate: 44_100, channels: 1, samples: [0.3, -0.15, 0.45, -0.6])
        let result = try XCTUnwrap(SeparationQuality.reconstructionError(mixture: mixture, stems: [stemA, stemB]))
        XCTAssertEqual(result, 0.0, accuracy: 1e-6)
    }

    func testReconstructionErrorMeasuresKnownResidual() throws {
        let mixture = PCMBuffer(sampleRate: 48_000, channels: 1, samples: [1, 1])
        let stem = PCMBuffer(sampleRate: 48_000, channels: 1, samples: [0.5, 0.5])
        let result = try XCTUnwrap(SeparationQuality.reconstructionError(mixture: mixture, stems: [stem]))
        XCTAssertEqual(result, 0.5, accuracy: 1e-9)
    }

    func testReconstructionErrorRejectsEmptyStemList() {
        let mixture = PCMBuffer(sampleRate: 44_100, channels: 1, samples: [0.5, -0.5])
        XCTAssertNil(SeparationQuality.reconstructionError(mixture: mixture, stems: []))
    }

    func testReconstructionErrorRejectsIncompatibleStemFormat() {
        let mixture = PCMBuffer(sampleRate: 44_100, channels: 1, samples: [0.5, -0.5])
        let wrongRate = PCMBuffer(sampleRate: 48_000, channels: 1, samples: [0.5, -0.5])
        XCTAssertNil(SeparationQuality.reconstructionError(mixture: mixture, stems: [wrongRate]))
    }
}
