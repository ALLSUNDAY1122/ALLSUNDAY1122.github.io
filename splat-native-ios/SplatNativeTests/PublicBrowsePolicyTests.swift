import XCTest
@testable import SplatNative

final class PublicBrowsePolicyTests: XCTestCase {
    private let authorA = ScanLabAuthor(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, handle: "alice", displayName: "Alice")
    private let authorB = ScanLabAuthor(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, handle: "bob", displayName: "Bob")

    func testProfileShowsOnlyPublicBrowsableScansFromSelectedAuthor() {
        let scans = [
            makeScan(id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", visibility: "public", author: authorA, publishedAt: "2026-08-17T02:00:00Z"),
            makeScan(id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", visibility: "unlisted", author: authorA, publishedAt: "2026-08-17T03:00:00Z"),
            makeScan(id: "cccccccc-cccc-cccc-cccc-cccccccccccc", visibility: "public", author: authorB, publishedAt: "2026-08-17T04:00:00Z"),
            makeScan(id: "dddddddd-dddd-dddd-dddd-dddddddddddd", visibility: "public", author: authorA, publishedAt: "2026-08-17T05:00:00Z")
        ]
        let result = PublicBrowsePolicy.scans(for: authorA.id, in: scans)
        XCTAssertEqual(result.map(\.id), [UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!, UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!])
    }

    func testBrowseRejectsMissingAuthorOrModelURL() {
        XCTAssertFalse(PublicBrowsePolicy.isBrowsable(makeScan(id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", visibility: "public", author: nil)))
        XCTAssertFalse(PublicBrowsePolicy.isBrowsable(makeScan(id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", visibility: "private", author: authorA)))
    }

    private func makeScan(id: String, visibility: String, author: ScanLabAuthor?, publishedAt: String? = nil) -> ScanLabPublicScan {
        ScanLabPublicScan(
            id: UUID(uuidString: id)!, title: "Scan", caption: "", visibility: visibility,
            publishedAt: publishedAt, location: nil, author: author, likeCount: 0,
            modelUrl: author == nil ? nil : URL(string: "https://example.com/model.spz"), previewUrl: nil
        )
    }
}
