import CoreGraphics
import XCTest

final class MeshFrameJPEGEncoderQualityTests: XCTestCase {
    func testNormalCompressionQualityIsUnchanged() {
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(0.91), 0.91, accuracy: 0.0001)
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(-1), 0, accuracy: 0.0001)
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(2), 1, accuracy: 0.0001)
    }

    func testNonFiniteCompressionQualityFallsBack() {
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(.nan), 0.91, accuracy: 0.0001)
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(.infinity), 0.91, accuracy: 0.0001)
        XCTAssertEqual(MeshFrameJPEGEncoder.normalizedCompressionQuality(-.infinity), 0.91, accuracy: 0.0001)
    }
}
