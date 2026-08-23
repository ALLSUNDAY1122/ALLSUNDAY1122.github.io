import Foundation
import XCTest

final class IOStoragePreflightTests: XCTestCase {
    func testExactCapacityPassesAndOneByteShortFails() throws {
        let store = IOFileStore(rootURL: FileManager.default.temporaryDirectory)
        XCTAssertNoThrow(try store.preflight(requiredBytes: 100, reserveBytes: 50, availableBytes: 150))

        XCTAssertThrowsError(try store.preflight(requiredBytes: 100, reserveBytes: 51, availableBytes: 150)) { error in
            XCTAssertEqual(
                error as? IOFileStore.StoreError,
                .insufficientStorage(requiredBytes: 151, availableBytes: 150)
            )
        }
    }

    func testOverflowFailsClosed() {
        let budget = IOStorageBudget(requiredBytes: Int64.max, reserveBytes: 1, availableBytes: Int64.max)
        XCTAssertEqual(budget.totalRequiredBytes, Int64.max)
        XCTAssertTrue(budget.overflowed)
        XCTAssertFalse(budget.hasCapacity)
        XCTAssertThrowsError(try IOStoragePreflightPolicy.validate(budget))
    }

    func testNegativeBudgetIsRejected() {
        XCTAssertThrowsError(
            try IOStoragePreflightPolicy.validate(
                IOStorageBudget(requiredBytes: -1, reserveBytes: 0, availableBytes: 100)
            )
        ) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .fileOperationFailed(code: "STORAGE_BUDGET_INVALID"))
        }
    }
}
