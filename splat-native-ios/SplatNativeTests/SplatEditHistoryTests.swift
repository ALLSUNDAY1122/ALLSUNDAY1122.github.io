import XCTest

final class SplatEditHistoryTests: XCTestCase {
    func testCommitUndoRedoRoundTripPreservesNormalizedSettings() {
        let baseline = SplatEditSettings()
        let cropped = SplatEditSettings(cropXMin: 0.2, cropXMax: 0.8)
        let adjusted = SplatEditSettings(exposureEV: 0.7, contrast: 1.2, cropXMin: 0.2, cropXMax: 0.8)
        var history = SplatEditHistory(current: baseline)

        history.commit(cropped)
        history.commit(adjusted)
        XCTAssertEqual(history.current, adjusted.normalized())
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)

        XCTAssertEqual(history.undo(), cropped.normalized())
        XCTAssertEqual(history.undo(), baseline.normalized())
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)

        XCTAssertEqual(history.redo(), cropped.normalized())
        XCTAssertEqual(history.redo(), adjusted.normalized())
        XCTAssertFalse(history.canRedo)
    }

    func testNewEditAfterUndoInvalidatesRedoBranch() {
        var history = SplatEditHistory()
        let first = SplatEditSettings(exposureEV: 0.5)
        let second = SplatEditSettings(exposureEV: 1.0)
        let alternate = SplatEditSettings(contrast: 1.3)

        history.commit(first)
        history.commit(second)
        XCTAssertEqual(history.undo(), first.normalized())
        XCTAssertTrue(history.canRedo)

        history.commit(alternate)
        XCTAssertEqual(history.current, alternate.normalized())
        XCTAssertFalse(history.canRedo)
    }

    func testDuplicateCommitDoesNotCreatePhantomUndoStep() {
        let settings = SplatEditSettings(exposureEV: 0.4, contrast: 1.1)
        var history = SplatEditHistory(current: settings)
        history.commit(settings)

        XCTAssertFalse(history.canUndo)
        XCTAssertNil(history.undo())
    }

    func testImmediateResetCanUndoBackToUnDebouncedLiveEdit() {
        let baseline = SplatEditSettings()
        let liveEdit = SplatEditSettings(exposureEV: 0.8, contrast: 1.25, cropXMin: 0.15, cropXMax: 0.85)
        var history = SplatEditHistory(current: baseline)

        // SplatResultView captures the live slider/crop state synchronously before reset-all applies
        // defaults. This models a reset pressed inside the 300 ms edit-history debounce window.
        history.commit(liveEdit)
        history.commit(.default)

        XCTAssertEqual(history.current, SplatEditSettings.default)
        XCTAssertEqual(history.undo(), liveEdit.normalized())
        XCTAssertEqual(history.redo(), SplatEditSettings.default)
    }

    func testHistoryDepthIsBounded() {
        var history = SplatEditHistory(maximumDepth: 3)
        for step in 1...8 {
            history.commit(SplatEditSettings(exposureEV: Double(step) * 0.1))
        }

        XCTAssertNotNil(history.undo())
        XCTAssertNotNil(history.undo())
        XCTAssertNotNil(history.undo())
        XCTAssertNil(history.undo())
    }

    func testResetChangesBaselineAndClearsBothDirections() {
        var history = SplatEditHistory()
        history.commit(SplatEditSettings(exposureEV: 0.4))
        _ = history.undo()
        XCTAssertTrue(history.canRedo)

        let persisted = SplatEditSettings(contrast: 1.25, cropYMin: 0.1, cropYMax: 0.9)
        history.reset(to: persisted)
        XCTAssertEqual(history.current, persisted.normalized())
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }
}