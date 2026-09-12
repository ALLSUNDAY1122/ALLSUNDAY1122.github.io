import XCTest

final class SplatViewerMemoryPolicyTests: XCTestCase {
    func testSmallSH3SceneFitsTypicalDeviceBudget() {
        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 250_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testLargeSH3SceneFallsBackBeforeExceedingBudget() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 2_000_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testInvalidPointCountNeverSelectsCanonicalAsset() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 0,
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testSeriousThermalPressureReducesViewerBudgetByQuarter() {
        let nominal = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        )
        let serious = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            thermalState: .serious,
            isLowPowerModeEnabled: false
        )

        XCTAssertEqual(serious, nominal / 4 * 3)
    }

    func testCriticalThermalPressureFallsBackForSceneAllowedAtNominalTemperature() {
        let pointCount = 900_000
        let physicalMemory = UInt64(4 * 1_024 * 1_024 * 1_024)

        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .critical,
            isLowPowerModeEnabled: false
        ))
    }

    func testLowPowerModeReducesViewerBudgetWithoutChangingNormalMode() {
        let physicalMemory = UInt64(4 * 1_024 * 1_024 * 1_024)
        let normal = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        )
        let lowPower = SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: true
        )

        XCTAssertEqual(lowPower, normal / 4 * 3)
    }

    func testLowPowerModeFallsBackForBorderlineSH3Scene() {
        let pointCount = 1_000_000
        let physicalMemory = UInt64(4 * 1_024 * 1_024 * 1_024)

        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: true
        ))
    }
}
