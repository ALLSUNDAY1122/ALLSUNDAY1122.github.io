import Foundation

private let aw42BlockedCapability = PlaybackRepeatedLoopSeamCapabilityInput(
    exactFutureSampleTimeSchedulingImplemented: false,
    revocationMechanism: .none,
    staleEventRevocationOrIsolationProven: false,
    seekInvalidationConnected: false,
    tempoInvalidationConnected: false,
    lifecycleInvalidationConnected: false,
    revocationPathAudiblySafe: false,
    selectedIntegrationExecutionPresent: false,
    physicalDeviceAudibilityValidationPresent: false
)

@main
struct L3AW42RepeatedLoopSeamSafetyStress {
    static func main() {
        let iterations = 1_000_000
        var gate = PlaybackRepeatedLoopSeamSafetyGate(capability: aw42BlockedCapability)
        var blocked = 0
        for _ in 0..<iterations {
            do {
                _ = try gate.requestAuthorization()
                preconditionFailure("blocked capability emitted authorization")
            } catch PlaybackRepeatedLoopSeamSafetyGateError.capabilityBlocked {
                blocked += 1
            } catch {
                preconditionFailure("unexpected error \(error)")
            }
        }
        let snapshot = gate.snapshot
        precondition(blocked == iterations)
        precondition(snapshot.authorizationAttempts == UInt64(iterations))
        precondition(snapshot.blockedAttempts == UInt64(iterations))
        precondition(snapshot.authorizationsIssued == 0)
        precondition(snapshot.generation == 0)
        precondition(!snapshot.counterOverflowed)
        precondition(!snapshot.gatePoisoned)
        print(
            "L3-AW42 stress PASS attempts=\(snapshot.authorizationAttempts) "
                + "blocked=\(snapshot.blockedAttempts) issued=\(snapshot.authorizationsIssued)"
        )
    }
}
