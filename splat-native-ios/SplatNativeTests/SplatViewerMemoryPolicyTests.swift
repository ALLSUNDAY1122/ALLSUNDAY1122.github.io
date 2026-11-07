import XCTest

final class SplatViewerMemoryPolicyTests: XCTestCase {
    private let ampleAvailableMemory = UInt64(4 * 1_024 * 1_024 * 1_024)

    func testSmallSH3SceneFitsTypicalDeviceBudget() {
        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 250_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testLargeSH3SceneFallsBackBeforeExceedingBudget() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 2_000_000,
            physicalMemoryBytes: 4 * 1_024 * 1_024 * 1_024,
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testInvalidPointCountNeverSelectsCanonicalAsset() {
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 0,
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024,
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testTinyReportedPhysicalMemoryNeverInflatesToQualityFloor() {
        let physicalMemory = UInt64(64 * 1_024 * 1_024)
        XCTAssertEqual(SplatViewerMemoryPolicy.budgetBytes(
            physicalMemoryBytes: physicalMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ), physicalMemory / 2)
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: 250_000,
            physicalMemoryBytes: physicalMemory,
            availableMemoryBytes: ampleAvailableMemory,
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
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            availableMemoryBytes: ampleAvailableMemory,
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
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: true
        ))
    }

    func testCurrentMemoryPressureFallsBackEvenWhenPhysicalBudgetAllowsSH3() {
        let pointCount = 250_000
        let physicalMemory = UInt64(4 * 1_024 * 1_024 * 1_024)
        let lowAvailableMemory = UInt64(128 * 1_024 * 1_024)

        XCTAssertTrue(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            availableMemoryBytes: ampleAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
        XCTAssertFalse(SplatViewerMemoryPolicy.canUseCanonicalSH3(
            pointCount: pointCount,
            physicalMemoryBytes: physicalMemory,
            availableMemoryBytes: lowAvailableMemory,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ))
    }

    func testAvailableMemorySafetyBudgetKeepsQuarterAsHeadroom() {
        let available = UInt64(400 * 1_024 * 1_024)
        XCTAssertEqual(SplatViewerMemoryPolicy.effectiveBudgetBytes(
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024,
            availableMemoryBytes: available,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        ), available / 4 * 3)
    }
}
