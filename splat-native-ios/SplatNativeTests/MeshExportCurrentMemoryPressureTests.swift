import XCTest

final class MeshExportCurrentMemoryPressureTests: XCTestCase {
    private let mib: UInt64 = 1_048_576

    func testCurrentMemoryPressureCanRejectConversionAllowedByPhysicalBudget() {
        let estimate = MeshExportMemoryPolicy.estimate(
            sourceBytes: 1 * mib,
            sourceExtension: "obj",
            format: .glb,
            physicalMemoryBytes: 4 * 1_024 * mib
        )
        XCTAssertLessThan(estimate.estimatedPeakBytes, estimate.budgetBytes)

        let constrained = MeshExportMemoryPolicy.applyingAvailableMemoryLimit(
            128 * mib,
            to: estimate
        )
        XCTAssertEqual(constrained.budgetBytes, 96 * mib)
        XCTAssertGreaterThan(constrained.estimatedPeakBytes, constrained.budgetBytes)
    }

    func testCurrentMemoryHeadroomNeverRaisesStaticBudget() {
        let estimate = MeshExportMemoryPolicy.estimate(
            sourceBytes: 1 * mib,
            sourceExtension: "obj",
            format: .obj,
            physicalMemoryBytes: 4 * 1_024 * mib
        )
        let constrained = MeshExportMemoryPolicy.applyingAvailableMemoryLimit(
            UInt64.max,
            to: estimate
        )
        XCTAssertEqual(constrained.budgetBytes, estimate.budgetBytes)
    }
}
