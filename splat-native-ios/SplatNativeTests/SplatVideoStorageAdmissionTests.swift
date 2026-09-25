import XCTest

final class SplatVideoStorageAdmissionTests: XCTestCase {
    func testVideoFreeSpaceEstimateDoesNotChargeExistingSceneBytesAgain() {
        let configuration = SplatExportAdmission.Kind.video(
            width: 1920,
            height: 1080,
            framesPerSecond: 30,
            duration: 8
        )

        let smallScene = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 8 * 1_024 * 1_024,
            canonicalAssetBytes: 96 * 1_024 * 1_024,
            kind: configuration
        )
        let largeScene = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 512 * 1_024 * 1_024,
            canonicalAssetBytes: 1_024 * 1_024 * 1_024,
            kind: configuration
        )

        XCTAssertEqual(largeScene, smallScene)
    }

    func testVideoFreeSpaceEstimateStillKeepsOutputAndSafetyReserve() {
        let required = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 2 * 1_024 * 1_024 * 1_024,
            canonicalAssetBytes: 3 * 1_024 * 1_024 * 1_024,
            kind: .video(width: 1920, height: 1080, framesPerSecond: 30, duration: 12)
        )

        let expectedVideoBytes = Int64(
            (Double(1920 * 1080 * 30) * 0.12 * 12 / 8).rounded(.up)
        )
        let safetyReserveBytes: Int64 = 128 * 1_024 * 1_024
        XCTAssertEqual(required, expectedVideoBytes + safetyReserveBytes)
    }
}