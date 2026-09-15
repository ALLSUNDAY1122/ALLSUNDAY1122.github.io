import XCTest

final class SplatSkySeederColorSamplingTests: XCTestCase {
    func testBilinearSampleBlendsFourNeighboringSkyPixels() {
        let bytes: [UInt8] = [
            255, 0, 0, 255,      0, 255, 0, 255,
            0, 0, 255, 255,      0, 0, 0, 255,
        ]

        let sample = SplatSkySeeder.bilinearSample(
            bytes: bytes,
            width: 2,
            height: 2,
            normalizedX: 0.5,
            normalizedY: 0.5
        )

        XCTAssertEqual(sample.red, 64)
        XCTAssertEqual(sample.green, 64)
        XCTAssertEqual(sample.blue, 64)
    }

    func testBilinearSamplePreservesExactPixelCentersAndClampsEdges() {
        let bytes: [UInt8] = [
            12, 34, 56, 255,     78, 90, 123, 255,
            145, 167, 189, 255,  210, 220, 230, 255,
        ]

        let topLeft = SplatSkySeeder.bilinearSample(
            bytes: bytes,
            width: 2,
            height: 2,
            normalizedX: 0,
            normalizedY: 0
        )
        let bottomRight = SplatSkySeeder.bilinearSample(
            bytes: bytes,
            width: 2,
            height: 2,
            normalizedX: 2,
            normalizedY: 2
        )

        XCTAssertEqual(topLeft.red, 12)
        XCTAssertEqual(topLeft.green, 34)
        XCTAssertEqual(topLeft.blue, 56)
        XCTAssertEqual(bottomRight.red, 210)
        XCTAssertEqual(bottomRight.green, 220)
        XCTAssertEqual(bottomRight.blue, 230)
    }

    func testBilinearSampleFailsClosedForMalformedRaster() {
        let sample = SplatSkySeeder.bilinearSample(
            bytes: [1, 2, 3, 4],
            width: 2,
            height: 2,
            normalizedX: 0.5,
            normalizedY: 0.5
        )

        XCTAssertEqual(sample.red, SplatSeedColorizer.fallback.red)
        XCTAssertEqual(sample.green, SplatSeedColorizer.fallback.green)
        XCTAssertEqual(sample.blue, SplatSeedColorizer.fallback.blue)
    }
}