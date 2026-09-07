import Foundation
import XCTest

private actor MutationGateProbe {
    var active = 0
    var peak = 0
    func enter() { active += 1; peak = max(peak, active) }
    func leave() { active -= 1 }
    func peakValue() -> Int { peak }
}

final class LibraryMutationGateTests: XCTestCase {
    func testConcurrentCallersNeverOverlapCriticalSection() async {
        let gate = Lane2LibraryMutationGate()
        let probe = MutationGateProbe()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await gate.lock()
                    await probe.enter()
                    try? await Task.sleep(for: .milliseconds(1))
                    await probe.leave()
                    await gate.unlock()
                }
            }
        }
        let peak = await probe.peakValue()
        XCTAssertEqual(peak, 1)
    }
}
