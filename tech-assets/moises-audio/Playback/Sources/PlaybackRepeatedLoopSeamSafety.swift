import Foundation

public enum PlaybackFutureGainAutomationRevocationMechanism: String, Codable, Sendable {
    case none
    case renderResetOnly
    case gainStageReplacement
    case perEventCancellation
    case generationIsolatedQueue
}

public struct PlaybackRepeatedLoopSeamCapabilityInput: Equatable, Codable, Sendable {
    public let exactFutureSampleTimeSchedulingImplemented: Bool
    public let revocationMechanism: PlaybackFutureGainAutomationRevocationMechanism
    public let staleEventRevocationOrIsolationProven: Bool
    public let seekInvalidationConnected: Bool
    public let tempoInvalidationConnected: Bool
    public let lifecycleInvalidationConnected: Bool
    public let revocationPathAudiblySafe: Bool
    public let selectedIntegrationExecutionPresent: Bool
    public let physicalDeviceAudibilityValidationPresent: Bool

    public init(
        exactFutureSampleTimeSchedulingImplemented: Bool,
        revocationMechanism: PlaybackFutureGainAutomationRevocationMechanism,
        staleEventRevocationOrIsolationProven: Bool,
        seekInvalidationConnected: Bool,
        tempoInvalidationConnected: Bool,
        lifecycleInvalidationConnected: Bool,
        revocationPathAudiblySafe: Bool,
        selectedIntegrationExecutionPresent: Bool,
        physicalDeviceAudibilityValidationPresent: Bool
    ) {
        self.exactFutureSampleTimeSchedulingImplemented = exactFutureSampleTimeSchedulingImplemented
        self.revocationMechanism = revocationMechanism
        self.staleEventRevocationOrIsolationProven = staleEventRevocationOrIsolationProven
        self.seekInvalidationConnected = seekInvalidationConnected
        self.tempoInvalidationConnected = tempoInvalidationConnected
        self.lifecycleInvalidationConnected = lifecycleInvalidationConnected
        self.revocationPathAudiblySafe = revocationPathAudiblySafe
        self.selectedIntegrationExecutionPresent = selectedIntegrationExecutionPresent
        self.physicalDeviceAudibilityValidationPresent = physicalDeviceAudibilityValidationPresent
    }
}

public enum PlaybackRepeatedLoopSeamSafetyIssueKind: String, Codable, Sendable, CaseIterable {
    case exactFutureSchedulingNotImplemented
    case noRevocableOrGenerationIsolatedAutomation
    case staleEventRevocationOrIsolationUnproven
    case seekInvalidationUnproven
    case tempoInvalidationUnproven
    case lifecycleInvalidationUnproven
    case revocationPathAudibilityUnproven
    case selectedIntegrationExecutionMissing
    case physicalDeviceAudibilityValidationMissing
}

public struct PlaybackRepeatedLoopSeamSafetyReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let issues: [PlaybackRepeatedLoopSeamSafetyIssueKind]
    public let structurallySafeForDeviceTrial: Bool
    public let automaticSchedulingProductionReady: Bool
    public let futureGainAutomationSchedulingAllowed: Bool
    public let parityPromotionAllowed: Bool

    public init(
        issues: [PlaybackRepeatedLoopSeamSafetyIssueKind],
        structurallySafeForDeviceTrial: Bool,
        automaticSchedulingProductionReady: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW42_REPEATED_LOOP_SEAM_SAFETY_NON_PARITY"
        self.issues = issues
        self.structurallySafeForDeviceTrial = structurallySafeForDeviceTrial
        self.automaticSchedulingProductionReady = automaticSchedulingProductionReady
        self.futureGainAutomationSchedulingAllowed = automaticSchedulingProductionReady
        self.parityPromotionAllowed = false
    }
}

public enum PlaybackRepeatedLoopSeamSafetyEvaluator {
    public static func evaluate(
        _ input: PlaybackRepeatedLoopSeamCapabilityInput
    ) -> PlaybackRepeatedLoopSeamSafetyReport {
        var structuralIssues: [PlaybackRepeatedLoopSeamSafetyIssueKind] = []

        if !input.exactFutureSampleTimeSchedulingImplemented {
            structuralIssues.append(.exactFutureSchedulingNotImplemented)
        }

        switch input.revocationMechanism {
        case .none:
            structuralIssues.append(.noRevocableOrGenerationIsolatedAutomation)
        case .renderResetOnly, .gainStageReplacement, .perEventCancellation, .generationIsolatedQueue:
            break
        }

        if !input.staleEventRevocationOrIsolationProven {
            structuralIssues.append(.staleEventRevocationOrIsolationUnproven)
        }
        if !input.seekInvalidationConnected {
            structuralIssues.append(.seekInvalidationUnproven)
        }
        if !input.tempoInvalidationConnected {
            structuralIssues.append(.tempoInvalidationUnproven)
        }
        if !input.lifecycleInvalidationConnected {
            structuralIssues.append(.lifecycleInvalidationUnproven)
        }
        if !input.revocationPathAudiblySafe {
            structuralIssues.append(.revocationPathAudibilityUnproven)
        }

        let structurallySafe = structuralIssues.isEmpty
        var issues = structuralIssues
        if !input.selectedIntegrationExecutionPresent {
            issues.append(.selectedIntegrationExecutionMissing)
        }
        if !input.physicalDeviceAudibilityValidationPresent {
            issues.append(.physicalDeviceAudibilityValidationMissing)
        }

        let productionReady = issues.isEmpty
        return PlaybackRepeatedLoopSeamSafetyReport(
            issues: issues,
            structurallySafeForDeviceTrial: structurallySafe,
            automaticSchedulingProductionReady: productionReady
        )
    }
}

public struct PlaybackRepeatedLoopSeamAuthorization: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let generation: UInt64
    public let parityPromotionAllowed: Bool

    public init(generation: UInt64) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW42_REPEATED_LOOP_SEAM_AUTHORIZATION_NON_PARITY"
        self.generation = generation
        self.parityPromotionAllowed = false
    }
}

public enum PlaybackRepeatedLoopSeamSafetyGateError: Error, Equatable, Sendable {
    case capabilityBlocked([PlaybackRepeatedLoopSeamSafetyIssueKind])
    case generationOverflow
    case gatePoisoned
}

public struct PlaybackRepeatedLoopSeamSafetyGateSnapshot: Equatable, Codable, Sendable {
    public let generation: UInt64
    public let authorizationAttempts: UInt64
    public let authorizationsIssued: UInt64
    public let blockedAttempts: UInt64
    public let invalidations: UInt64
    public let counterOverflowed: Bool
    public let gatePoisoned: Bool
    public let productionReady: Bool
    public let parityPromotionAllowed: Bool
}

public struct PlaybackRepeatedLoopSeamSafetyGate: Sendable {
    private let report: PlaybackRepeatedLoopSeamSafetyReport
    private var generation: UInt64
    private var authorizationAttempts: UInt64 = 0
    private var authorizationsIssued: UInt64 = 0
    private var blockedAttempts: UInt64 = 0
    private var invalidations: UInt64 = 0
    private var counterOverflowed = false
    private var gatePoisoned = false

    public init(
        capability: PlaybackRepeatedLoopSeamCapabilityInput,
        initialGeneration: UInt64 = 0
    ) {
        self.report = PlaybackRepeatedLoopSeamSafetyEvaluator.evaluate(capability)
        self.generation = initialGeneration
    }

    public var capabilityReport: PlaybackRepeatedLoopSeamSafetyReport { report }

    public mutating func requestAuthorization() throws -> PlaybackRepeatedLoopSeamAuthorization {
        let attempts = Self.saturatingIncrement(authorizationAttempts)
        authorizationAttempts = attempts.value
        counterOverflowed = counterOverflowed || attempts.overflowed
        guard !gatePoisoned else { throw PlaybackRepeatedLoopSeamSafetyGateError.gatePoisoned }
        guard report.automaticSchedulingProductionReady else {
            let blocked = Self.saturatingIncrement(blockedAttempts)
            blockedAttempts = blocked.value
            counterOverflowed = counterOverflowed || blocked.overflowed
            throw PlaybackRepeatedLoopSeamSafetyGateError.capabilityBlocked(report.issues)
        }
        let issued = Self.saturatingIncrement(authorizationsIssued)
        authorizationsIssued = issued.value
        counterOverflowed = counterOverflowed || issued.overflowed
        return PlaybackRepeatedLoopSeamAuthorization(generation: generation)
    }

    @discardableResult
    public mutating func invalidateGeneration() throws -> UInt64 {
        guard !gatePoisoned else { throw PlaybackRepeatedLoopSeamSafetyGateError.gatePoisoned }
        let next = generation.addingReportingOverflow(1)
        guard !next.overflow else {
            gatePoisoned = true
            throw PlaybackRepeatedLoopSeamSafetyGateError.generationOverflow
        }
        generation = next.partialValue
        let invalidated = Self.saturatingIncrement(invalidations)
        invalidations = invalidated.value
        counterOverflowed = counterOverflowed || invalidated.overflowed
        return generation
    }

    public func authorizationIsCurrent(_ authorization: PlaybackRepeatedLoopSeamAuthorization) -> Bool {
        !gatePoisoned && report.automaticSchedulingProductionReady && authorization.generation == generation
    }

    public var snapshot: PlaybackRepeatedLoopSeamSafetyGateSnapshot {
        PlaybackRepeatedLoopSeamSafetyGateSnapshot(
            generation: generation,
            authorizationAttempts: authorizationAttempts,
            authorizationsIssued: authorizationsIssued,
            blockedAttempts: blockedAttempts,
            invalidations: invalidations,
            counterOverflowed: counterOverflowed,
            gatePoisoned: gatePoisoned,
            productionReady: report.automaticSchedulingProductionReady,
            parityPromotionAllowed: false
        )
    }

    private static func saturatingIncrement(_ value: UInt64) -> (value: UInt64, overflowed: Bool) {
        let next = value.addingReportingOverflow(1)
        return next.overflow ? (UInt64.max, true) : (next.partialValue, false)
    }
}
