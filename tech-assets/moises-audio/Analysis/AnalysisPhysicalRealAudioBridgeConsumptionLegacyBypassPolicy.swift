import Foundation

public enum AnalysisPhysicalRealAudioBridgeConsumptionLegacyAPI: String, Codable, Equatable, Sendable {
    case concurrentObserveAppendCAS = "W51_CONCURRENT_OBSERVE_APPEND_CAS"
    case concurrentAppend = "W51_CONCURRENT_APPEND"
    case concurrentConsumedInventory = "W51_CONCURRENT_CONSUMED_INVENTORY"
    case concurrentExpectation = "W51_CONCURRENT_EXPECTATION"
    case secureCheckpointCreate = "W50_SECURE_CHECKPOINT_CREATE"
    case secureCheckpointVerify = "W50_SECURE_CHECKPOINT_VERIFY"
    case quiescentObserveSnapshot = "W52_QUIESCENT_OBSERVE_SNAPSHOT"
    case quiescentCheckpointCreate = "W52_QUIESCENT_CHECKPOINT_CREATE"
    case quiescentCheckpointVerify = "W52_QUIESCENT_CHECKPOINT_VERIFY"
    case quiescentCustodyBundle = "W52_QUIESCENT_CUSTODY_BUNDLE"
    case iosDurabilityMakeTicket = "W53_IOS_DURABILITY_MAKE_TICKET"
    case iosDurabilityPrepare = "W53_IOS_DURABILITY_PREPARE"
    case iosDurabilityReopen = "W53_IOS_DURABILITY_REOPEN"
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLegacyBuildMode: String, Codable, Equatable, Sendable {
    case compatibilityDebug = "COMPATIBILITY_DEBUG"
    case production = "PRODUCTION"
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassError: Error, Equatable, Sendable {
    case productionLegacyAPIRejected(AnalysisPhysicalRealAudioBridgeConsumptionLegacyAPI)
}

public enum AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassPolicy {
    public static let limitations = [
        "NON_PARITY: W56 contains legacy custody API bypasses after W55 normalization; it does not promote any Analysis PARITY row.",
        "Legacy W51/W52/W53 entrypoints remain source-compatible for Debug migration tests but are not production custody APIs.",
        "Release builds fail closed before a legacy API can return a value that omits the W55 normalization receipt/certificate. Production callers must migrate to the W55 normalized entrypoints.",
        "The compile-configuration guard is a local API-safety control, not an entitlement, signature, Apple attestation or authorization boundary against a modified binary."
    ]

    public static var currentBuildMode: AnalysisPhysicalRealAudioBridgeConsumptionLegacyBuildMode {
        #if DEBUG
        return .compatibilityDebug
        #else
        return .production
        #endif
    }

    public static var productionLegacyAPIsAreBlocked: Bool {
        decision(for: currentBuildMode) == .reject
    }

    public enum Decision: String, Codable, Equatable, Sendable {
        case allowCompatibilityRoute = "ALLOW_COMPATIBILITY_ROUTE"
        case reject = "REJECT_PRODUCTION_LEGACY_API"
    }

    public static func decision(
        for buildMode: AnalysisPhysicalRealAudioBridgeConsumptionLegacyBuildMode
    ) -> Decision {
        switch buildMode {
        case .compatibilityDebug:
            return .allowCompatibilityRoute
        case .production:
            return .reject
        }
    }

    static func requireCompatibilityRoute(
        _ api: AnalysisPhysicalRealAudioBridgeConsumptionLegacyAPI
    ) throws {
        guard decision(for: currentBuildMode) == .allowCompatibilityRoute else {
            throw AnalysisPhysicalRealAudioBridgeConsumptionLegacyBypassError.productionLegacyAPIRejected(api)
        }
    }
}
