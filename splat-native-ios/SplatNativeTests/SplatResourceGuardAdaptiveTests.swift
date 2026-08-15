import XCTest

final class SplatResourceGuardAdaptiveTests: XCTestCase {
    func testAvailableMemoryReserveScalesAndStaysBounded() {
        let gib: UInt64 = 1_073_741_824
        let mib: UInt64 = 1_048_576

        let low = SplatResourceLimits.conservative(physicalMemoryBytes: 3 * gib)
        let high = SplatResourceLimits.conservative(physicalMemoryBytes: 12 * gib)

        XCTAssertGreaterThanOrEqual(low.minimumAvailableMemoryReserveBytes, 256 * mib)
        XCTAssertLessThanOrEqual(high.minimumAvailableMemoryReserveBytes, 512 * mib)
        XCTAssertGreaterThan(high.minimumAvailableMemoryReserveBytes, low.minimumAvailableMemoryReserveBytes)
    }

    func testLowAvailableMemoryPausesBeforeResidentBudgetIsReached() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()

        let safe = guardrail.evaluate(
            splatCount: 100_000,
            residentMemoryBytes: 500_000_000,
            availableMemoryBytes: guardrail.limits.minimumAvailableMemoryReserveBytes + 1,
            thermalState: .nominal
        )
        XCTAssertNil(safe.reason)

        let pressure = guardrail.evaluate(
            splatCount: 110_000,
            residentMemoryBytes: 520_000_000,
            availableMemoryBytes: guardrail.limits.minimumAvailableMemoryReserveBytes,
            thermalState: .nominal
        )
        XCTAssertEqual(pressure.reason, .availableMemoryReserve)
        XCTAssertEqual(
            pressure.minimumAvailableMemoryBytes,
            guardrail.limits.minimumAvailableMemoryReserveBytes
        )
    }

    func testSeriousAndCriticalThermalStatesPauseImmediately() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()

        let serious = guardrail.evaluate(
            splatCount: 50_000,
            residentMemoryBytes: 300_000_000,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .serious
        )
        XCTAssertEqual(serious.reason, .thermalPressure)

        let critical = guardrail.evaluate(
            splatCount: 50_000,
            residentMemoryBytes: 300_000_000,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .critical
        )
        XCTAssertEqual(critical.reason, .thermalPressure)
    }

    func testFairThermalStateDoesNotPauseByItself() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()

        let evaluation = guardrail.evaluate(
            splatCount: 50_000,
            residentMemoryBytes: 300_000_000,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .fair
        )
        XCTAssertNil(evaluation.reason)
    }

    func testMemoryWarningStillHasHighestPriority() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()
        guardrail.noteMemoryWarning()

        let evaluation = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount,
            residentMemoryBytes: guardrail.limits.residentMemoryBudgetBytes,
            availableMemoryBytes: 1,
            thermalState: .critical
        )
        XCTAssertEqual(evaluation.reason, .memoryWarning)
    }
}
