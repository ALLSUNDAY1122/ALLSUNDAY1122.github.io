import Foundation

@main
struct ProductFlowStateTests {
    static func main() throws {
        let image = ProductInputAsset(kind: .image, localURL: URL(fileURLWithPath: "/tmp/page-1.jpg"), displayName: "page-1.jpg")
        let video = ProductInputAsset(kind: .video, localURL: URL(fileURLWithPath: "/tmp/book.mov"), displayName: "book.mov")
        var passed = 0

        func check(_ name: String, _ condition: @autoclosure () -> Bool) throws {
            guard condition() else { throw TestError.failed(name) }
            print("PASS \(name)")
            passed += 1
        }

        var selection = ProductFlowState()
        ProductFlowReducer.reduce(state: &selection, action: .replaceInput([image, image, video]))
        try check("selection ready and URL dedupe", selection.step == .ready && selection.inputAssets.count == 2)

        var emptyStart = ProductFlowState()
        ProductFlowReducer.reduce(state: &emptyStart, action: .startProcessing)
        try check("empty start fails closed", emptyStart.step == .failed && emptyStart.failure?.code == .importFailed)
        ProductFlowReducer.reduce(state: &emptyStart, action: .retry)
        try check("failed start retries to selection", emptyStart.step == .selectingInput)

        var review = ProductFlowState()
        ProductFlowReducer.reduce(state: &review, action: .replaceInput([video]))
        ProductFlowReducer.reduce(state: &review, action: .startProcessing)
        ProductFlowReducer.reduce(state: &review, action: .processingFinished(bookPackageURL: URL(fileURLWithPath: "/tmp/package"), reviewRequiredCount: 2))
        try check("review precedes export", review.step == .review)
        ProductFlowReducer.reduce(state: &review, action: .reviewResolved(remaining: 0))
        try check("resolved review advances to export", review.step == .exporting)

        var permission = ProductFlowState()
        ProductFlowReducer.reduce(state: &permission, action: .replaceInput([image]))
        ProductFlowReducer.reduce(state: &permission, action: .cameraPermissionChanged(.denied))
        try check("camera denial preserves imported input", permission.step == .ready && permission.inputAssets == [image])

        var cancel = ProductFlowState()
        ProductFlowReducer.reduce(state: &cancel, action: .replaceInput([video]))
        ProductFlowReducer.reduce(state: &cancel, action: .startProcessing)
        ProductFlowReducer.reduce(state: &cancel, action: .cancel)
        ProductFlowReducer.reduce(state: &cancel, action: .retry)
        try check("cancel retry preserves input", cancel.step == .ready && cancel.inputAssets == [video])

        print("RESULT passed=\(passed) failed=0")
    }

    enum TestError: Error { case failed(String) }
}
