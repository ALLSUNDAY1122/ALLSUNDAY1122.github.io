import Foundation
import XCTest

final class ScanLabProfilePolicyTests: XCTestCase {
    func testMapsUniqueViolationToHandleUnavailable() { XCTAssertTrue(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "23505")) }
    func testDoesNotMapOtherDatabaseOrAuthorizationErrors() {
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "23503"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "42501"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: "PGRST116"))
        XCTAssertFalse(ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: nil))
    }
    func testHandleUnavailableMessageIsStableAndUserFacing() {
        XCTAssertEqual(ScanLabProfileUpdateError.handleUnavailable.errorDescription, "このユーザーIDは使用されています。別のIDを入力してください。")
    }
    func testNormalizesHandleAndBio() {
        XCTAssertEqual(ScanLabProfilePolicy.normalizedHandle("  User_123  "), "user_123")
        XCTAssertNil(ScanLabProfilePolicy.normalizedBio("  \n "))
        XCTAssertEqual(ScanLabProfilePolicy.normalizedBio("  hello  "), "hello")
    }
    func testRejectsInvalidHandle() {
        XCTAssertFalse(ScanLabProfilePolicy.validate(handle: "ab", displayName: "Name", bio: "", avatarURL: ""))
        XCTAssertFalse(ScanLabProfilePolicy.validate(handle: "bad-handle", displayName: "Name", bio: "", avatarURL: ""))
        XCTAssertFalse(ScanLabProfilePolicy.validate(handle: "bad space", displayName: "Name", bio: "", avatarURL: ""))
    }
    func testAcceptsNormalizedUppercaseInput() { XCTAssertTrue(ScanLabProfilePolicy.validate(handle: " User_123 ", displayName: " Name ", bio: "bio", avatarURL: "")) }
    func testBioLimit() {
        XCTAssertTrue(ScanLabProfilePolicy.validate(handle: "user_123", displayName: "Name", bio: String(repeating: "a", count: 160), avatarURL: ""))
        XCTAssertFalse(ScanLabProfilePolicy.validate(handle: "user_123", displayName: "Name", bio: String(repeating: "a", count: 161), avatarURL: ""))
    }
    func testAvatarRequiresHTTPS() {
        XCTAssertFalse(ScanLabProfilePolicy.validate(handle: "user_123", displayName: "Name", bio: "", avatarURL: "http://example.com/a.jpg"))
        XCTAssertTrue(ScanLabProfilePolicy.validate(handle: "user_123", displayName: "Name", bio: "", avatarURL: "https://example.com/a.jpg"))
        XCTAssertTrue(ScanLabProfilePolicy.validate(handle: "user_123", displayName: "Name", bio: "", avatarURL: "HTTPS://example.com/a.jpg"))
    }
}
