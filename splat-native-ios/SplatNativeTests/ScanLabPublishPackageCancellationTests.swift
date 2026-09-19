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
        await assertCancellation(task)
    }

    func testBuildAsyncPreservesAlreadyCancelledParent() async throws {
        let task = Task<ScanLabPublishPackage, Error> {
            while !Task.isCancelled {
                await Task.yield()
            }
            return try await ScanLabPublishPackageBuilder.buildAsync(
                from: URL(fileURLWithPath: "/definitely-not-a-publish-source.spz")
            )
        }

        task.cancel()
        await assertCancellation(task)
    }

    private func assertCancellation(_ task: Task<ScanLabPublishPackage, Error>) async {
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
