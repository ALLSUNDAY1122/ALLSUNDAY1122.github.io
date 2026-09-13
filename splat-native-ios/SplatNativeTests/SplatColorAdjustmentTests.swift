import Foundation
import SplatIO
import XCTest
import simd

final class SplatColorAdjustmentTests: XCTestCase {
    func testSH3AffineEditScalesDirectionalCoefficientsAndOffsetsOnlyDC() {
        let original: [SIMD3<Float>] = [
            SIMD3<Float>(0.10, -0.05, 0.20),
            SIMD3<Float>(0.03, -0.04, 0.05),
            SIMD3<Float>(-0.02, 0.06, 0.01),
        ]
        let color = SplatPoint.Color.sphericalHarmonicFloat(original)
        let base = color.asSRGBFloat
        let exposureEV = 1.0
        let contrast = 1.25
        let gain = Float(pow(2.0, exposureEV) * contrast)
        let bias = Float(0.5 * (1 - contrast))
        let midpoint = SIMD3<Float>(repeating: 0.5)
        let result = SplatColorAdjustment.apply(color, exposureEV: exposureEV, contrast: contrast)
        guard case .sphericalHarmonicFloat(let coefficients) = result else {
            return XCTFail("Expected SH color")
        }
        let expectedDC = (base * gain + SIMD3<Float>(repeating: bias) - midpoint)
            * SplatPoint.Color.INV_SH_C0
        assertApproximatelyEqual(coefficients[0], expectedDC)
        assertApproximatelyEqual(coefficients[1], original[1] * gain)
        assertApproximatelyEqual(coefficients[2], original[2] * gain)
    }

    func testSHAdjustmentDoesNotPrematurelyClampDC() {
        let original = [SIMD3<Float>(0.35, 0.30, 0.25), SIMD3<Float>(0.08, 0.02, -0.04)]
        let color = SplatPoint.Color.sphericalHarmonicFloat(original)
        let result = SplatColorAdjustment.apply(color, exposureEV: 2.0, contrast: 1.4)
        guard case .sphericalHarmonicFloat(let coefficients) = result else {
            return XCTFail("Expected SH color")
        }
        XCTAssertGreaterThan(coefficients[0].x, original[0].x)
        assertApproximatelyEqual(coefficients[1], original[1] * Float(pow(2.0, 2.0) * 1.4))
    }

    func testSRGBEditStillClampsToDisplayRange() {
        let color = SplatPoint.Color.sRGBUInt8(SIMD3<UInt8>(240, 128, 8))
        let result = SplatColorAdjustment.apply(color, exposureEV: 2.0, contrast: 1.5)
        guard case .sRGBUInt8(let bytes) = result else {
            return XCTFail("Expected sRGB color")
        }
        XCTAssertEqual(bytes.x, 255)
        XCTAssertEqual(bytes.y, 255)
        XCTAssertLessThanOrEqual(bytes.z, 255)
    }

    private func assertApproximatelyEqual(
        _ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>, accuracy: Float = 0.00001,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.z, rhs.z, accuracy: accuracy, file: file, line: line)
    }
}
