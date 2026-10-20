import Foundation
import XCTest

final class MeshFrameWriteFenceTests: XCTestCase {
    func testStaleGenerationNeverRunsWriteClosure() {
        let fence = MeshFrameWriteFence()
        let old = fence.rotate()
        let current = fence.rotate()
        var count = 0
        let rejected = fence.performIfCurrent(old) {
            count += 1
            return true
        }
        XCTAssertNil(rejected)
        XCTAssertEqual(count, 0)
        let accepted = fence.performIfCurrent(current) {
            count += 1
            return true
        }
        XCTAssertEqual(accepted, true)
        XCTAssertEqual(count, 1)
    }

    func testResetWaitsForActiveWriterThenBlocksStaleWrites() {
        let fence = MeshFrameWriteFence()
        let previous = fence.rotate()
        let writerEntered = DispatchSemaphore(value: 0)
        let writerMayFinish = DispatchSemaphore(value: 0)
        let resetFinished = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "mesh-fence-tests", attributes: .concurrent)
        let guardLock = NSLock()
        var writeCount = 0
        queue.async {
            _ = fence.performIfCurrent(previous) {
                writerEntered.signal()
                guard writerMayFinish.wait(timeout: .now() + 3) == .success else { return false }
                guardLock.lock()
                writeCount += 1
                guardLock.unlock()
                return true
            }
        }
        XCTAssertEqual(writerEntered.wait(timeout: .now() + 3), .success)
        queue.async {
            _ = fence.rotate()
            resetFinished.signal()
        }
        XCTAssertEqual(resetFinished.wait(timeout: .now() + 0.05), .timedOut)
        writerMayFinish.signal()
        XCTAssertEqual(resetFinished.wait(timeout: .now() + 3), .success)
        let rejected = fence.performIfCurrent(previous) {
            guardLock.lock()
            writeCount += 1
            guardLock.unlock()
            return true
        }
        XCTAssertNil(rejected)
        guardLock.lock()
        let count = writeCount
        guardLock.unlock()
        XCTAssertEqual(count, 1)
    }
}
