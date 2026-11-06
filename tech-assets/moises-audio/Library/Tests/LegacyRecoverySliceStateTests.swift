import Foundation
import XCTest

final class Lane2LegacyRecoverySliceStateTests: XCTestCase {
    func testBudgetClampsAndSlices() {
        XCTAssertEqual(Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 1).projectsPerLaunch, 8)
        XCTAssertEqual(Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 999).projectsPerLaunch, 256)
        let budget = Lane2LegacyRecoverySliceBudget(projectsPerLaunch: 64)
        XCTAssertEqual(budget.selectedCount(available: 100), 64)
        XCTAssertEqual(budget.selectedCount(available: 12), 12)
        XCTAssertTrue(budget.hasMore(availableWithSentinel: 65))
        XCTAssertFalse(budget.hasMore(availableWithSentinel: 64))
        XCTAssertEqual(budget.launchCount(forProjectCount: 1_000), 16)
        XCTAssertEqual(budget.logicalFetchUpperBoundPerLaunch, 3)
    }

    func testActiveMarkerIsDurableAndIdempotent() throws {
        try withRoot { root in
            let state = Lane2LegacyRecoverySliceState(rootURL: root)
            XCTAssertFalse(state.isActive)
            try state.activate()
            try state.activate()
            XCTAssertTrue(Lane2LegacyRecoverySliceState(rootURL: root).isActive)
            try state.finish()
            try state.finish()
            XCTAssertFalse(state.isActive)
        }
    }

    func testCrashAfterActivationLeavesResumableState() throws {
        try withRoot { root in
            try Lane2LegacyRecoverySliceState(rootURL: root).activate()
            let relaunched = Lane2LegacyRecoverySliceState(rootURL: root)
            XCTAssertTrue(relaunched.isActive)
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW24-SliceStateTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
