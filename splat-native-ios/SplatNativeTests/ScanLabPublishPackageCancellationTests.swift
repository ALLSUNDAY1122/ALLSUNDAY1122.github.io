import XCTest

final class ScanLabPublishPackageCancellationTests: XCTestCase {
    func testBuildPreservesCancellationInsteadOfMappingItToPackageFailure() async throws {
        let task = Task<ScanLabPublishPackage, Error> {
            while !Task.isCancelled {
                await Task.yield()
            }
            return try ScanLabPublishPackageBuilder.build(
                from: URL(fileURLWithPath: "/definitely-not-a-publish-source.spz")
            )
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected. Cancellation must not be rewritten as invalidSource/packageWriteFailed.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
