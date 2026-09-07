import Foundation

@main
struct L3AW29AppleProductionCompositionSelfTest {
    static func main() throws {
        let valid = Lane3AppleDSPProductionCompositionReceipt(
            telemetryWrapped: true,
            transactionalConformance: true,
            tempoTransitionConformance: true,
            pitchTransitionConformance: true,
            backendNodeIdentityShared: true,
            directBackendAccessExposed: false
        )
        let validated = try Lane3AppleDSPProductionCompositionValidator.validate(valid)
        precondition(validated == valid)

        let negatives: [(Lane3AppleDSPProductionCompositionReceipt, Lane3AppleDSPProductionCompositionError)] = [
            (.init(telemetryWrapped: false, transactionalConformance: true, tempoTransitionConformance: true, pitchTransitionConformance: true, backendNodeIdentityShared: true, directBackendAccessExposed: false), .telemetryWrapperMissing),
            (.init(telemetryWrapped: true, transactionalConformance: false, tempoTransitionConformance: true, pitchTransitionConformance: true, backendNodeIdentityShared: true, directBackendAccessExposed: false), .transactionalConformanceMissing),
            (.init(telemetryWrapped: true, transactionalConformance: true, tempoTransitionConformance: false, pitchTransitionConformance: true, backendNodeIdentityShared: true, directBackendAccessExposed: false), .tempoTransitionConformanceMissing),
            (.init(telemetryWrapped: true, transactionalConformance: true, tempoTransitionConformance: true, pitchTransitionConformance: false, backendNodeIdentityShared: true, directBackendAccessExposed: false), .pitchTransitionConformanceMissing),
            (.init(telemetryWrapped: true, transactionalConformance: true, tempoTransitionConformance: true, pitchTransitionConformance: true, backendNodeIdentityShared: false, directBackendAccessExposed: false), .backendNodeIdentityNotShared),
            (.init(telemetryWrapped: true, transactionalConformance: true, tempoTransitionConformance: true, pitchTransitionConformance: true, backendNodeIdentityShared: true, directBackendAccessExposed: true), .directBackendAccessExposed),
            (.init(telemetryWrapped: true, transactionalConformance: true, tempoTransitionConformance: true, pitchTransitionConformance: true, backendNodeIdentityShared: true, directBackendAccessExposed: false, parityPromotionAllowed: true), .invalidParityClaim)
        ]

        for (receipt, expected) in negatives {
            do {
                _ = try Lane3AppleDSPProductionCompositionValidator.validate(receipt)
                preconditionFailure("expected composition rejection: \(expected)")
            } catch let error as Lane3AppleDSPProductionCompositionError {
                precondition(error == expected)
            }
        }

        print("L3-AW29 Apple production composition PASS negatives=\(negatives.count)")
    }
}
