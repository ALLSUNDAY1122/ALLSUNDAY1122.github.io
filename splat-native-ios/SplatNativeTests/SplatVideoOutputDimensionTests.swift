import CoreGraphics
import XCTest

final class SplatVideoOutputDimensionTests: XCTestCase {
    func testNormalPixelDimensionsRoundAsBefore() {
        XCTAssertEqual(SplatVideoOutputValidator.encodedPixelDimension(1_919.6), 1_920)
        XCTAssertEqual(SplatVideoOutputValidator.encodedPixelDimension(-1_079.6), 1_080)
    }

    func testInvalidPixelDimensionsFailClosed() {
        XCTAssertNil(SplatVideoOutputValidator.encodedPixelDimension(0))
        XCTAssertNil(SplatVideoOutputValidator.encodedPixelDimension(.nan))
        XCTAssertNil(SplatVideoOutputValidator.encodedPixelDimension(.infinity))
        XCTAssertNil(SplatVideoOutputValidator.encodedPixelDimension(CGFloat.greatestFiniteMagnitude))
    }
}
