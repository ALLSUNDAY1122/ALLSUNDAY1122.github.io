import XCTest

final class ScanLabVisibilityPresentationTests: XCTestCase {
    func testPublishedVisibilityStatesStayDistinct() {
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "public", status: "published", moderationStatus: "approved"),
            "Map・Discoverで公開中"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "unlisted", status: "published", moderationStatus: "approved"),
            "限定リンク有効"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "private", status: "published", moderationStatus: "approved"),
            "非公開クラウド保存済み"
        )
    }

    func testVisibilityChangeOnlyForPublishedApprovedRows() {
        XCTAssertTrue(
            ScanLabOwnerVisibilityPresentation.canChangeVisibility(status: "published", moderationStatus: "approved")
        )
        XCTAssertFalse(
            ScanLabOwnerVisibilityPresentation.canChangeVisibility(status: "published", moderationStatus: "pending")
        )
        XCTAssertFalse(
            ScanLabOwnerVisibilityPresentation.canChangeVisibility(status: "published", moderationStatus: "rejected")
        )
        XCTAssertFalse(
            ScanLabOwnerVisibilityPresentation.canChangeVisibility(status: "hidden", moderationStatus: "approved")
        )
    }

    func testOnlySharedVisibilityOffersStopAction() {
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.unpublishActionTitle(visibility: "public", status: "published"),
            "公開を停止"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.unpublishActionTitle(visibility: "unlisted", status: "published"),
            "限定リンクを無効化"
        )
        XCTAssertNil(
            ScanLabOwnerVisibilityPresentation.unpublishActionTitle(visibility: "private", status: "published")
        )
        XCTAssertNil(
            ScanLabOwnerVisibilityPresentation.unpublishActionTitle(visibility: "public", status: "hidden")
        )
    }

    func testPendingAndHiddenCopyDoesNotCollapseVisibility() {
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "public", status: "published", moderationStatus: "pending"),
            "公開確認中"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "unlisted", status: "published", moderationStatus: "pending"),
            "共有確認中"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "private", status: "draft", moderationStatus: "pending"),
            "クラウド保存処理中"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "public", status: "hidden", moderationStatus: "approved"),
            "公開停止済み"
        )
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "unlisted", status: "hidden", moderationStatus: "approved"),
            "限定リンク無効化済み"
        )
    }

    func testUnknownVisibilityFailsClosedAsPrivatePresentation() {
        XCTAssertEqual(ScanLabOwnerVisibilityPresentation.visibilityText("unexpected"), "非公開")
        XCTAssertEqual(
            ScanLabOwnerVisibilityPresentation.statusText(visibility: "unexpected", status: "published", moderationStatus: "approved"),
            "非公開クラウド保存済み"
        )
        XCTAssertNil(
            ScanLabOwnerVisibilityPresentation.unpublishActionTitle(visibility: "unexpected", status: "published")
        )
    }

    func testDeleteMessageMatchesVisibility() {
        XCTAssertTrue(ScanLabOwnerVisibilityPresentation.deleteMessage("public").contains("共有リンク"))
        XCTAssertTrue(ScanLabOwnerVisibilityPresentation.deleteMessage("unlisted").contains("共有リンク"))
        XCTAssertTrue(ScanLabOwnerVisibilityPresentation.deleteMessage("private").contains("非公開"))
    }
}
