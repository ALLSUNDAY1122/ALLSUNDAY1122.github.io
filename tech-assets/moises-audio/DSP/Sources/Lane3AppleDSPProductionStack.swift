import Foundation

public enum Lane3AppleDSPProductionCompositionError: Error, Equatable, Sendable {
    case telemetryWrapperMissing
    case transactionalConformanceMissing
    case tempoTransitionConformanceMissing
    case pitchTransitionConformanceMissing
    case backendNodeIdentityNotShared
    case directBackendAccessExposed
    case invalidParityClaim
}

public struct Lane3AppleDSPProductionCompositionReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let telemetryWrapped: Bool
    public let transactionalConformance: Bool
    public let tempoTransitionConformance: Bool
    public let pitchTransitionConformance: Bool
    public let backendNodeIdentityShared: Bool
    public let directBackendAccessExposed: Bool
    public let parityPromotionAllowed: Bool

    public init(
        telemetryWrapped: Bool,
        transactionalConformance: Bool,
        tempoTransitionConformance: Bool,
        pitchTransitionConformance: Bool,
        backendNodeIdentityShared: Bool,
        directBackendAccessExposed: Bool,
        parityPromotionAllowed: Bool = false
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW29_APPLE_DSP_PRODUCTION_COMPOSITION_NON_PARITY"
        self.telemetryWrapped = telemetryWrapped
        self.transactionalConformance = transactionalConformance
        self.tempoTransitionConformance = tempoTransitionConformance
        self.pitchTransitionConformance = pitchTransitionConformance
        self.backendNodeIdentityShared = backendNodeIdentityShared
        self.directBackendAccessExposed = directBackendAccessExposed
        self.parityPromotionAllowed = parityPromotionAllowed
    }
}

public enum Lane3AppleDSPProductionCompositionValidator {
    @discardableResult
    public static func validate(
        _ receipt: Lane3AppleDSPProductionCompositionReceipt
    ) throws -> Lane3AppleDSPProductionCompositionReceipt {
        guard receipt.schemaVersion == 1,
              receipt.evidenceScope == "LANE3_AW29_APPLE_DSP_PRODUCTION_COMPOSITION_NON_PARITY" else {
            throw Lane3AppleDSPProductionCompositionError.invalidParityClaim
        }
        guard receipt.telemetryWrapped else {
            throw Lane3AppleDSPProductionCompositionError.telemetryWrapperMissing
        }
        guard receipt.transactionalConformance else {
            throw Lane3AppleDSPProductionCompositionError.transactionalConformanceMissing
        }
        guard receipt.tempoTransitionConformance else {
            throw Lane3AppleDSPProductionCompositionError.tempoTransitionConformanceMissing
        }
        guard receipt.pitchTransitionConformance else {
            throw Lane3AppleDSPProductionCompositionError.pitchTransitionConformanceMissing
        }
        guard receipt.backendNodeIdentityShared else {
            throw Lane3AppleDSPProductionCompositionError.backendNodeIdentityNotShared
        }
        guard !receipt.directBackendAccessExposed else {
            throw Lane3AppleDSPProductionCompositionError.directBackendAccessExposed
        }
        guard !receipt.parityPromotionAllowed else {
            throw Lane3AppleDSPProductionCompositionError.invalidParityClaim
        }
        return receipt
    }
}

#if canImport(AVFAudio)
import AVFAudio

/// Selected Apple construction path for the production time/pitch stack.
/// The App/HQ layer receives only the graph node and project-scoped controller; the raw backend is
/// deliberately not exposed, preventing a caller from bypassing AW22 telemetry or AW25/AW28
/// transition semantics. Generic compile guards fail the Apple build if any required conformance is
/// omitted from the selected source surface.
public struct Lane3AppleDSPProductionStack: @unchecked Sendable {
    public let node: AVAudioUnitTimePitch
    public let controller: PracticeDSPProductionController
    public let compositionReceipt: Lane3AppleDSPProductionCompositionReceipt

    public static func make(
        projectID: ProjectID,
        collector: Lane3DSPRuntimeTelemetryCollector,
        node: AVAudioUnitTimePitch = AVAudioUnitTimePitch(),
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        overlap: Float = 8.0,
        initialState: PracticeDSPState = PracticeDSPState(),
        tempoTransitionPolicy: PracticeDSPTempoTransitionPolicy = .provisionalAppleInteractive,
        tempoTransitionSleeper: any PracticeDSPTempoTransitionSleeping = PracticeDSPSystemTempoTransitionSleeper(),
        pitchTransitionPolicy: PracticeDSPPitchTransitionPolicy = .provisionalAppleInteractive,
        pitchTransitionSleeper: any PracticeDSPPitchTransitionSleeping = PracticeDSPSystemPitchTransitionSleeper(),
        telemetryTimeSource: any Lane3DSPRuntimeTelemetryTimeSource = Lane3DSPSystemTelemetryTimeSource()
    ) throws -> Lane3AppleDSPProductionStack {
        requireAppleBackendConformance(AppleTimePitchBackend.self)
        requireTelemetryBackendConformance(Lane3DSPTelemetryTransactionalBackend.self)
        _ = AppleSampleAccurateClickExecutor.self

        let appleBackend = AppleTimePitchBackend(
            node: node,
            capabilities: capabilities,
            overlap: overlap
        )
        let telemetryBackend = Lane3DSPTelemetryTransactionalBackend(
            backend: appleBackend,
            collector: collector,
            timeSource: telemetryTimeSource
        )
        let receipt = Lane3AppleDSPProductionCompositionReceipt(
            telemetryWrapped: true,
            transactionalConformance: true,
            tempoTransitionConformance: true,
            pitchTransitionConformance: true,
            backendNodeIdentityShared: appleBackend.node === node,
            directBackendAccessExposed: false,
            parityPromotionAllowed: false
        )
        try Lane3AppleDSPProductionCompositionValidator.validate(receipt)

        let controller = try PracticeDSPProductionController(
            projectID: projectID,
            backend: telemetryBackend,
            capabilities: capabilities,
            initialState: initialState,
            tempoTransitionPolicy: tempoTransitionPolicy,
            tempoTransitionSleeper: tempoTransitionSleeper,
            pitchTransitionPolicy: pitchTransitionPolicy,
            pitchTransitionSleeper: pitchTransitionSleeper
        )
        return Lane3AppleDSPProductionStack(
            node: node,
            controller: controller,
            compositionReceipt: receipt
        )
    }

    private static func requireAppleBackendConformance<T>(_ type: T.Type)
    where T: PracticeDSPTransactionalBackendApplying,
          T: PracticeDSPTempoTransitionBackendApplying,
          T: PracticeDSPPitchTransitionBackendApplying {}

    private static func requireTelemetryBackendConformance<T>(_ type: T.Type)
    where T: PracticeDSPTransactionalBackendApplying,
          T: PracticeDSPTempoTransitionBackendApplying,
          T: PracticeDSPPitchTransitionBackendApplying {}
}
#endif
