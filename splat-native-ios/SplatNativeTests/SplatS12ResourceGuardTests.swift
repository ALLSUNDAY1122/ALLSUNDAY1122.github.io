import XCTest

final class SplatS12ResourceGuardTests: XCTestCase {
    func testGaussianBudgetIsDensificationAdmissionNotTerminalPause() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()

        XCTAssertEqual(
            guardrail.limits.densificationBudgetCount,
            guardrail.limits.maxSplatCount
        )

        let atBudget = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount,
            residentMemoryBytes: 400_000_000,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .nominal
        )
        XCTAssertNil(atBudget.reason)

        let resumedAboveBudget = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount + 5_000,
            residentMemoryBytes: 420_000_000,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .nominal
        )
        XCTAssertNil(resumedAboveBudget.reason)
    }

    func testDynamicMemoryGateRemainsTerminalAboveGaussianBudget() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()

        let evaluation = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount + 5_000,
            residentMemoryBytes: guardrail.limits.residentMemoryBudgetBytes,
            availableMemoryBytes: 1_000_000_000,
            thermalState: .nominal
        )

        XCTAssertEqual(evaluation.reason, .residentMemoryBudget)
    }
}
