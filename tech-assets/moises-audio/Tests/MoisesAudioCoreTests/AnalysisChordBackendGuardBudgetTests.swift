import XCTest
@testable import MoisesAudioCore

final class AnalysisChordBackendGuardBudgetTests: XCTestCase {
    func testOneHourGuardOverheadIsBoundedWithoutReducingChordCadence() {
        let budget = AnalysisChordBackendGuardBudgetEstimator.estimate(
            durationSeconds: 3_600,
            sourceSampleRate: 44_100
        )
        XCTAssertEqual(budget.chordFrameCount, 14_400)
        XCTAssertEqual(budget.verificationFrameLimit, 8)
        XCTAssertEqual(budget.verificationFramesUpperBound, 8)
        XCTAssertEqual(budget.chordWindowSamples, 5_600)
        XCTAssertEqual(budget.chordSpectralBinCount, 48)
        XCTAssertEqual(budget.baselineVectorizedWindowElementVisits, 80_640_000)
        XCTAssertEqual(budget.maximumExtraReferenceWindowElementVisits, 2_150_400)
        XCTAssertEqual(budget.totalGoertzelRecurrenceUpdates, 3_870_720_000)
        XCTAssertEqual(budget.maximumExtraVerificationRecurrenceUpdates, 2_150_400)
        XCTAssertEqual(
            budget.verificationRecurrenceOverheadFraction,
            8.0 / 14_400.0,
            accuracy: 1e-15
        )
    }

    func testShortInputNeverVerifiesMoreFramesThanExist() {
        let budget = AnalysisChordBackendGuardBudgetEstimator.estimate(
            durationSeconds: 1.0,
            sourceSampleRate: 8_000
        )
        XCTAssertLessThanOrEqual(budget.verificationFramesUpperBound, budget.chordFrameCount)
        XCTAssertLessThanOrEqual(budget.verificationFramesUpperBound, 8)
    }

    func testZeroDurationHasZeroGuardWork() {
        let budget = AnalysisChordBackendGuardBudgetEstimator.estimate(
            durationSeconds: 0,
            sourceSampleRate: 44_100
        )
        XCTAssertEqual(budget.chordFrameCount, 0)
        XCTAssertEqual(budget.verificationFramesUpperBound, 0)
        XCTAssertEqual(budget.maximumExtraVerificationRecurrenceUpdates, 0)
        XCTAssertEqual(budget.verificationRecurrenceOverheadFraction, 0)
    }
}
