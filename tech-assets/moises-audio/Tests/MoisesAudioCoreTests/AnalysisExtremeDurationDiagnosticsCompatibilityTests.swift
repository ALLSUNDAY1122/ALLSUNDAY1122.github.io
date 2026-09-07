import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisExtremeDurationDiagnosticsCompatibilityTests: XCTestCase {
    func testPreW31DiagnosticsJSONDecodesWithSafeDefaults() throws {
        let legacyJSON = #"{"preparedSampleCount":10,"preparedSampleRequests":10,"preparedSampleComputations":10,"preparedBlockLoads":0,"tempoOnsetCount":4,"keyWindowCount":1,"keyWindowSampleCount":10,"chordFrameDecisionCount":2,"sectionEnergyFrameCount":3,"maximumTempoRingSamples":368,"maximumChordRingSamples":5600,"estimatedRetainedFeatureBytes":256,"exactSinglePreparedTraversal":true}"#
        let decoded = try JSONDecoder().decode(
            AnalysisSinglePassPreparedFeatureDiagnostics.self,
            from: Data(legacyJSON.utf8)
        )
        XCTAssertFalse(decoded.extremeDurationCompressionApplied)
        XCTAssertEqual(decoded.tempoFrameStride, 1)
        XCTAssertEqual(decoded.chordFrameStride, 1)
        XCTAssertEqual(decoded.naturalSectionEnergyFrameCount, 0)
        XCTAssertEqual(decoded.sectionEnergyFrameStrideEquivalent, 1)
        XCTAssertTrue(decoded.tempoResolutionSafe)
        XCTAssertTrue(decoded.chordWindowRetentionSafe)
        XCTAssertTrue(decoded.sectionResolutionSafe)
    }

    func testInvalidNonpositiveDiagnosticStridesNormalizeFailSafe() {
        let value = AnalysisSinglePassPreparedFeatureDiagnostics(
            preparedSampleCount: 10,
            preparedSampleRequests: 10,
            preparedSampleComputations: 10,
            preparedBlockLoads: 0,
            tempoOnsetCount: 0,
            keyWindowCount: 0,
            keyWindowSampleCount: 0,
            chordFrameDecisionCount: 0,
            sectionEnergyFrameCount: 0,
            maximumTempoRingSamples: 0,
            maximumChordRingSamples: 0,
            estimatedRetainedFeatureBytes: 0,
            exactSinglePreparedTraversal: true,
            extremeDurationCompressionApplied: true,
            tempoFrameStride: 0,
            chordFrameStride: -3,
            naturalSectionEnergyFrameCount: -1,
            sectionEnergyFrameStrideEquivalent: 0
        )
        XCTAssertEqual(value.tempoFrameStride, 1)
        XCTAssertEqual(value.chordFrameStride, 1)
        XCTAssertEqual(value.naturalSectionEnergyFrameCount, 0)
        XCTAssertEqual(value.sectionEnergyFrameStrideEquivalent, 1)
    }
}
