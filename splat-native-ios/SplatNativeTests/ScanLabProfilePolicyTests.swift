import Foundation
import XCTest

final class ScanLabProfilePolicyTests: XCTestCase {
    func testMapsUniqueViolationToHandleUnavailable() {
        XCTAssertTrue(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "23505"))
    }

    func testDoesNotMapOtherDatabaseOrAuthorizationErrors() {
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "23503"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "42501"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "PGRST116"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: nil))
    }

    func testHandleUnavailableMessageIsStableAndUserFacing() {
        XCTAssertEqual(
            ScanLabProfileUpdateError.handleUnavailable.errorDescription,
            "このユーザーIDは使用されています。別のIDを入力してください。"
        )
    }
}
