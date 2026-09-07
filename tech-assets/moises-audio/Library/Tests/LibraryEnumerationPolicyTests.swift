import Foundation
import XCTest

final class LibraryEnumerationPolicyTests: XCTestCase {
    func testBatchSizeClampsToSafeBounds() {
        XCTAssertEqual(LibraryEnumerationPolicy(batchSize: 0).batchSize, 16)
        XCTAssertEqual(LibraryEnumerationPolicy(batchSize: 7).batchSize, 16)
        XCTAssertEqual(LibraryEnumerationPolicy(batchSize: 128).batchSize, 128)
        XCTAssertEqual(LibraryEnumerationPolicy(batchSize: 9_999).batchSize, 1024)
    }

    func testRangesCoverEveryIndexExactlyOnce() {
        let policy = LibraryEnumerationPolicy(batchSize: 17)
        let ranges = policy.ranges(forCount: 257)
        XCTAssertEqual(ranges.count, 16)
        XCTAssertEqual(ranges.first, 0..<17)
        XCTAssertEqual(ranges.last, 255..<257)
        XCTAssertEqual(ranges.flatMap(Array.init), Array(0..<257))
        XCTAssertTrue(ranges.allSatisfy { $0.count <= 17 })
    }

    func testEmptyAndSingleElementEnumeration() {
        let policy = LibraryEnumerationPolicy(batchSize: 128)
        XCTAssertTrue(policy.ranges(forCount: 0).isEmpty)
        XCTAssertEqual(policy.ranges(forCount: 1), [0..<1])
        XCTAssertEqual(policy.batchCount(forCount: 0), 0)
        XCTAssertEqual(policy.batchCount(forCount: 1), 1)
    }

    func testEstimatedFetchOperationReductionIsBounded() {
        let policy = LibraryEnumerationPolicy(batchSize: 128)
        XCTAssertEqual(policy.estimatedProjectFetchOperations(projectCount: 10_000), 396)
        XCTAssertEqual(policy.estimatedSetlistFetchOperations(setlistCount: 10_000), 80)
    }
}
