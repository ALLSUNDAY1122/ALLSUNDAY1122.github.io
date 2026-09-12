import XCTest

final class SplatViewerMemoryPolicyTests: XCTestCase {
    func testSmallSH3SceneFitsTypicalDeviceBudget() {
        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 250_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal
        ))
    }

    func testLargeSH3SceneFallsBackBeforeExceedingBudget() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 2_000_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal
        ))
    }

    func testInvalidPointCountNeverSelectsCanonicalAsset() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 0,
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal
        ))
    }

    func testSeriousThermalPressureReducesViewerBudgetByQuarter() {
        let nominal = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal
        )
        let serious = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .serious
        )

        XCTAssertEqual(serious, nominal / 4 * 3)
    }

    func testCriticalThermalPressureFallsBackForSceneAllowedAtNominalTemperature() {
        let pointCount = 900_000
        let physicalMemory = UInt64(4 * 1_024 * 1_024 * 1_024)

        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .critical
        ))
    }
}
