import XCTest

final class SplatSkySeederSafetyTests: XCTestCase {
    func testFiniteIdentityCameraProducesFiniteSkyPoint() throws {
        let point = try XCTUnwrap(
            SplatSkySeeder.worldPoint(
                normalizedX: 0.5,
                normalizedY: 0.1,
                frame: frame(),
                distance: 20
            )
        )
        XCTAssertTrue(point.x.isFinite)
        XCTAssertTrue(point.y.isFinite)
        XCTAssertTrue(point.z.isFinite)
    }

    func testNonFiniteIntrinsicsAreRejected() {
        XCTAssertNil(
            SplatSkySeeder.worldPoint(
                normalizedX: 0.5,
                normalizedY: 0.1,
                frame: frame(flX: .infinity),
                distance: 20
            )
        )
    }

    func testNonFiniteTransformIsRejected() {
        var matrix = identityMatrix
        matrix[0][1] = .nan
        XCTAssertNil(
            SplatSkySeeder.worldPoint(
                normalizedX: 0.5,
                normalizedY: 0.1,
                frame: frame(transform: matrix),
                distance: 20
            )
        )
    }

    func testNonFiniteDistanceIsRejected() {
        XCTAssertNil(
            SplatSkySeeder.worldPoint(
                normalizedX: 0.5,
                normalizedY: 0.1,
                frame: frame(),
                distance: .infinity
            )
        )
    }

    private var identityMatrix: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    }

    private func frame(
        flX: Float = 500,
        transform: [[Float]]? = nil
    ) -> SplatSeedFrame {
        SplatSeedFrame(
            filePath: "frame.jpg",
            transformMatrix: transform ?? identityMatrix,
            flX: flX,
            flY: 500,
            cx: 320,
            cy: 240,
            w: 640,
            h: 480
        )
    }
}
