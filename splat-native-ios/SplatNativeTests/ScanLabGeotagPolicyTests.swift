import XCTest
@testable import SplatNative

final class ScanLabGeotagPolicyTests: XCTestCase {
    private let tokyo = ScanLabLocation(latitude: 35.681236, longitude: 139.767125, label: "Tokyo")

    func testPrivateAlwaysStripsLocation() {
        XCTAssertNil(ScanLabGeotagPolicy.normalized(visibility: .private, location: tokyo, label: "Tokyo"))
    }

    func testUnlistedAlwaysStripsLocation() {
        XCTAssertNil(ScanLabGeotagPolicy.normalized(visibility: .unlisted, location: tokyo, label: "Tokyo"))
    }

    func testPublicRequiresExplicitLocation() {
        XCTAssertNil(ScanLabGeotagPolicy.normalized(visibility: .public, location: nil, label: nil))
    }

    func testRejectsInvalidCoordinates() {
        XCTAssertNil(ScanLabGeotagPolicy.normalized(visibility: .public, location: .init(latitude: 91, longitude: 139, label: nil), label: nil))
        XCTAssertNil(ScanLabGeotagPolicy.normalized(visibility: .public, location: .init(latitude: 35, longitude: 181, label: nil), label: nil))
    }

    func testPublicLocationTrimsAndBoundsLabel() {
        let longLabel = "  " + String(repeating: "a", count: 100) + "  "
        let normalized = ScanLabGeotagPolicy.normalized(visibility: .public, location: tokyo, label: longLabel)
        XCTAssertEqual(normalized?.latitude, tokyo.latitude)
        XCTAssertEqual(normalized?.longitude, tokyo.longitude)
        XCTAssertEqual(normalized?.label?.count, 80)
    }

    func testPublicGateRequiresLocationAndAllPrivacyConfirmations() {
        XCTAssertTrue(ScanLabGeotagPolicy.canPublishPublic(location: tokyo, publicPlaceConfirmed: true, privacyConfirmed: true, rightsConfirmed: true))
        XCTAssertFalse(ScanLabGeotagPolicy.canPublishPublic(location: nil, publicPlaceConfirmed: true, privacyConfirmed: true, rightsConfirmed: true))
        XCTAssertFalse(ScanLabGeotagPolicy.canPublishPublic(location: tokyo, publicPlaceConfirmed: false, privacyConfirmed: true, rightsConfirmed: true))
        XCTAssertFalse(ScanLabGeotagPolicy.canPublishPublic(location: tokyo, publicPlaceConfirmed: true, privacyConfirmed: false, rightsConfirmed: true))
        XCTAssertFalse(ScanLabGeotagPolicy.canPublishPublic(location: tokyo, publicPlaceConfirmed: true, privacyConfirmed: true, rightsConfirmed: false))
    }
}
