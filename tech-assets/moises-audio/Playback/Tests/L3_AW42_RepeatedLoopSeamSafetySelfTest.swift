import Foundation

private func fullyProvenCapability() -> PlaybackRepeatedLoopSeamCapabilityInput {
    .init(
        exactFutureSampleTimeSchedulingImplemented: true,
        revocationMechanism: .perEventCancellation,
        staleEventRevocationOrIsolationProven: true,
        seekInvalidationConnected: true,
        tempoInvalidationConnected: true,
        lifecycleInvalidationConnected: true,
        revocationPathAudiblySafe: true,
        selectedIntegrationExecutionPresent: true,
        physicalDeviceAudibilityValidationPresent: true
    )
}

@main
struct L3AW42RepeatedLoopSeamSafetySelfTest {
    static func main() throws {
        let currentReport = Lane3SelectedAppleRepeatedLoopSeamSafety.report
        precondition(!currentReport.structurallySafeForDeviceTrial)
        precondition(!currentReport.automaticSchedulingProductionReady)
        precondition(!currentReport.futureGainAutomationSchedulingAllowed)
        precondition(currentReport.issues.contains(.exactFutureSchedulingNotImplemented))
        precondition(currentReport.issues.contains(.noRevocableOrGenerationIsolatedAutomation))
        precondition(currentReport.issues.contains(.physicalDeviceAudibilityValidationMissing))

        var currentGate = PlaybackRepeatedLoopSeamSafetyGate(
            capability: Lane3SelectedAppleRepeatedLoopSeamSafety.capability
        )
        do {
            _ = try currentGate.requestAuthorization()
            preconditionFailure("current selected-like capability must fail closed")
        } catch PlaybackRepeatedLoopSeamSafetyGateError.capabilityBlocked(let issues) {
            precondition(!issues.isEmpty)
        }
        precondition(currentGate.snapshot.authorizationAttempts == 1)
        precondition(currentGate.snapshot.blockedAttempts == 1)
        precondition(currentGate.snapshot.authorizationsIssued == 0)

        var safeGate = PlaybackRepeatedLoopSeamSafetyGate(capability: fullyProvenCapability())
        let first = try safeGate.requestAuthorization()
        precondition(safeGate.authorizationIsCurrent(first))
        _ = try safeGate.invalidateGeneration()
        precondition(!safeGate.authorizationIsCurrent(first))
        let second = try safeGate.requestAuthorization()
        precondition(second.generation == 1)
        precondition(safeGate.authorizationIsCurrent(second))

        let resetOnly = PlaybackRepeatedLoopSeamCapabilityInput(
            exactFutureSampleTimeSchedulingImplemented: true,
            revocationMechanism: .renderResetOnly,
            staleEventRevocationOrIsolationProven: false,
            seekInvalidationConnected: true,
            tempoInvalidationConnected: true,
            lifecycleInvalidationConnected: true,
            revocationPathAudiblySafe: false,
            selectedIntegrationExecutionPresent: true,
            physicalDeviceAudibilityValidationPresent: true
        )
        let resetReport = PlaybackRepeatedLoopSeamSafetyEvaluator.evaluate(resetOnly)
        precondition(!resetReport.structurallySafeForDeviceTrial)
        precondition(resetReport.issues.contains(.staleEventRevocationOrIsolationUnproven))
        precondition(resetReport.issues.contains(.revocationPathAudibilityUnproven))

        var overflowGate = PlaybackRepeatedLoopSeamSafetyGate(
            capability: fullyProvenCapability(),
            initialGeneration: UInt64.max
        )
        do {
            _ = try overflowGate.invalidateGeneration()
            preconditionFailure("generation overflow must poison")
        } catch PlaybackRepeatedLoopSeamSafetyGateError.generationOverflow {
        }
        precondition(overflowGate.snapshot.gatePoisoned)
        do {
            _ = try overflowGate.requestAuthorization()
            preconditionFailure("poisoned gate must reject")
        } catch PlaybackRepeatedLoopSeamSafetyGateError.gatePoisoned {
        }

        print(
            "L3-AW42 safety gate PASS blocked=\(currentGate.snapshot.blockedAttempts) "
                + "safeGen=\(safeGate.snapshot.generation)"
        )
    }
}
