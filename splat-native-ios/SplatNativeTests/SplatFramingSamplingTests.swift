import XCTest

final class SplatFramingSamplingTests: XCTestCase {
    func testLargeSceneSamplingUsesFullBoundedBudgetAcrossStrideBoundary() {
        let justOverBoundary = SplatCameraGeometry.framingSampleIndices(pointCount: 6_001)
        XCTAssertEqual(justOverBoundary.count, 6_000)
        XCTAssertEqual(justOverBoundary.first, 0)
        XCTAssertEqual(justOverBoundary.last, 6_000)

        let nextStrideBoundary = SplatCameraGeometry.framingSampleIndices(pointCount: 12_001)
        XCTAssertEqual(nextStrideBoundary.count, 6_000)
        XCTAssertEqual(nextStrideBoundary.first, 0)
        XCTAssertEqual(nextStrideBoundary.last, 12_000)
    }

    func testFramingSampleIndicesAreStrictlyIncreasingAndBounded() {
        for pointCount in [6_001, 7_777, 11_999, 12_001, 50_003] {
            let indices = SplatCameraGeometry.framingSampleIndices(pointCount: pointCount)
            XCTAssertLessThanOrEqual(indices.count, 6_000)
            XCTAssertEqual(indices.first, 0)
            XCTAssertEqual(indices.last, pointCount - 1)
            XCTAssertTrue(zip(indices, indices.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
        }
    }

    func testCustomViewerBudgetsRemainBoundedAcrossOldFloorStrideWindows() {
        let cropIndices = SplatCameraGeometry.framingSampleIndices(
            pointCount: 15_999,
            targetSampleCount: 8_000
        )
        XCTAssertEqual(cropIndices.count, 8_000)
        XCTAssertEqual(cropIndices.first, 0)
        XCTAssertEqual(cropIndices.last, 15_998)

        let pickIndices = SplatCameraGeometry.framingSampleIndices(
            pointCount: 29_999,
            targetSampleCount: 15_000
        )
        XCTAssertEqual(pickIndices.count, 15_000)
        XCTAssertEqual(pickIndices.first, 0)
        XCTAssertEqual(pickIndices.last, 29_998)
    }

    func testSmallScenesStillUseEveryPoint() {
        XCTAssertEqual(
            SplatCameraGeometry.framingSampleIndices(pointCount: 5),
            [0, 1, 2, 3, 4]
        )
        XCTAssertTrue(SplatCameraGeometry.framingSampleIndices(pointCount: 0).isEmpty)
    }
}
