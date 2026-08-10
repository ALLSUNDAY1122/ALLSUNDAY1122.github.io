import XCTest
@testable import LearningSprintCore

final class CompletionLedgerTests: XCTestCase {
    func testCompletionCountsAreSeparatedByRoute() {
        var state = LearningState(contentVersion: "v1")
        state.recordCompletion(for: .subject("通関業法"))
        state.recordCompletion(for: .subject("通関業法"))
        state.recordCompletion(for: .mock("第59回|通関業法"))
        XCTAssertEqual(state.completionCount(for: .subject("通関業法")), 2)
        XCTAssertEqual(state.completionCount(for: .mock("第59回|通関業法")), 1)
        XCTAssertEqual(state.completionCount(for: .subject("関税法等")), 0)
    }
}
