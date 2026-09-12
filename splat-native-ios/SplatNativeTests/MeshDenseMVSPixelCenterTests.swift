import XCTest

final class MeshDenseMVSPixelCenterTests: XCTestCase {
    func testThumbnailPrincipalPointPreservesPixelCenterConvention() throws {
        XCTAssertEqual(
            try XCTUnwrap(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(959.5, scale: 0.1)),
            95.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(37, scale: 1)),
            37,
            accuracy: 0.0001
        )
    }

    func testThumbnailPrincipalPointRejectsInvalidScaleOrCoordinate() {
        XCTAssertNil(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(.nan, scale: 0.1))
        XCTAssertNil(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(100, scale: .infinity))
        XCTAssertNil(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(100, scale: 0))
        XCTAssertNil(MeshDenseMVSGeometry.scaledPrincipalPointCoordinate(100, scale: -1))
    }
}
