import XCTest

final class SplatSkyGeometryRejectionTests: XCTestCase {
    func testGeometrySkyPredicateRejectsBlueSkyButPreservesBrightNeutralCeiling() {
        let blueSky = SplatSeedSample(red: 78, green: 145, blue: 222)
        let brightNeutralCeiling = SplatSeedSample(red: 224, green: 226, blue: 228)

        XCTAssertTrue(
            SplatSkySeeder.isHighConfidenceSky(blueSky, sceneLuma: 0.35),
            "Blue top-connected sky should remain eligible for near-geometry suppression"
        )
        XCTAssertFalse(
            SplatSkySeeder.isHighConfidenceSky(brightNeutralCeiling, sceneLuma: 0.30),
            "Bright neutral indoor ceilings must not be erased by the overcast-sky heuristic"
        )
    }
}
