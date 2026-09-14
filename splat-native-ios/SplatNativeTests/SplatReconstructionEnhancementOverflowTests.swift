import XCTest

final class SplatReconstructionEnhancementOverflowTests: XCTestCase {
    func testEnhancementTargetClampsHugePersistedIterationWithoutOverflow() {
        XCTAssertEqual(
            SplatReconstructionPolicy.enhancementTarget(from: Int.max),
            SplatReconstructionPolicy.trainingHorizon
        )
        XCTAssertEqual(
            SplatReconstructionPolicy.enhancementTarget(from: Int.max - 1),
            SplatReconstructionPolicy.trainingHorizon
        )
    }

    func testEnhancementTargetPreservesNormalProgression() {
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 7_000), 12_000)
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 29_000), 30_000)
    }
}
