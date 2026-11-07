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

    func testNormalizedImageCenterUsesPixelCenterConvention() throws {
        let centeredFrame = SplatSeedFrame(
            filePath: "frame.jpg",
            transformMatrix: identityMatrix,
            flX: 500,
            flY: 500,
            cx: 319.5,
            cy: 239.5,
            w: 640,
            h: 480
        )
        let point = try XCTUnwrap(
            SplatSkySeeder.worldPoint(
                normalizedX: 0.5,
                normalizedY: 0.5,
                frame: centeredFrame,
                distance: 20
            )
        )

        XCTAssertEqual(point.x, 0, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0, accuracy: 0.0001)
        XCTAssertEqual(point.z, -20, accuracy: 0.0001)
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
