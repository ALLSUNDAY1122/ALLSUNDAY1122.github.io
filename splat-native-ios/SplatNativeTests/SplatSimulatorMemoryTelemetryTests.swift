import XCTest

final class SplatSimulatorMemoryTelemetryTests: XCTestCase {
#if targetEnvironment(simulator)
    func testSimulatorDoesNotUseMacHostAvailableMemoryForDevicePolicies() {
        XCTAssertEqual(MeshExportMemoryPolicy.currentAvailableMemoryBytes(), 0)
        XCTAssertEqual(SplatViewerMemoryPolicy.currentAvailableMemoryBytes(), 0)
        XCTAssertEqual(SplatVideoMemoryPolicy.currentAvailableMemoryBytes(), 0)
    }
#endif
}
