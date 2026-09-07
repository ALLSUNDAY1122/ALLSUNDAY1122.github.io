import Foundation

public protocol Lane3LeaseStampedContinuityCorrelating: Sendable {
    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation
}

extension Lane3SelectedInteractiveContinuityInstrumentationAdapter: Lane3LeaseStampedContinuityCorrelating {}

public struct Lane3InteractiveContinuityV2AudibleMarker: Equatable, Codable, Sendable {
    public let uptimeNanoseconds: UInt64
    public let source: String

    public init(uptimeNanoseconds: UInt64, source: String) {
        self.uptimeNanoseconds = uptimeNanoseconds
        self.source = source
    }
}

public enum Lane3InteractiveContinuityV2StagedCaptureIssueKind: String, Codable, Sendable {
    case duplicateSampleID
    case pendingCapacityExceeded
    case unknownSampleIDForStampedOutcome
    case unknownSampleIDForAudibleMarker
    case conflictingDuplicateStampedOutcome
    case conflictingDuplicateAudibleMarker
    case audibleMarkerForNonExecutedOutcome
    case expiredBeforeStampedOutcome
    case expiredBeforeAudibleMarker
    case unexpectedNonExecutedCorrelation
    case retiredIdentityWindowTruncated
}

public struct Lane3InteractiveContinuityV2StagedCaptureIssue: Equatable, Codable, Sendable {
    public let sampleID: UInt64?
    public let kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind
    public let detail: String

    public init(
        sampleID: UInt64?,
        kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind,
        detail: String
    ) {
        self.sampleID = sampleID
        self.kind = kind
        self.detail = detail
    }
}

public enum Lane3InteractiveContinuityV2StagedCaptureDisposition: Equatable, Sendable {
    case accepted
    case idempotentDuplicateIgnored
    case finalizedExecuted
    case finalizedNonExecuted
    case rejected
}

public struct Lane3InteractiveContinuityV2StagedCaptureSnapshot: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let pendingCount: Int
    public let finalizingCount: Int
    public let retiredIdentityCount: Int
    public let retiredIdentityDrops: UInt64
    public let finalizedExecutedCount: UInt64
    public let finalizedNonExecutedCount: UInt64
    public let expiredCount: UInt64
    public let idempotentDuplicateCallbackCount: UInt64
    public let issueCount: UInt64
    public let issueDetailDrops: UInt64
    public let parityPromotionAllowed: Bool

    public init(
        pendingCount: Int,
        finalizingCount: Int,
        retiredIdentityCount: Int,
        retiredIdentityDrops: UInt64,
        finalizedExecutedCount: UInt64,
        finalizedNonExecutedCount: UInt64,
        expiredCount: UInt64,
        idempotentDuplicateCallbackCount: UInt64,
        issueCount: UInt64,
        issueDetailDrops: UInt64
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW41_STAGED_PHYSICAL_CAPTURE_NON_PARITY"
        self.pendingCount = pendingCount
        self.finalizingCount = finalizingCount
        self.retiredIdentityCount = retiredIdentityCount
        self.retiredIdentityDrops = retiredIdentityDrops
        self.finalizedExecutedCount = finalizedExecutedCount
        self.finalizedNonExecutedCount = finalizedNonExecutedCount
        self.expiredCount = expiredCount
        self.idempotentDuplicateCallbackCount = idempotentDuplicateCallbackCount
        self.issueCount = issueCount
        self.issueDetailDrops = issueDetailDrops
        self.parityPromotionAllowed = false
    }
}

public struct Lane3InteractiveContinuityV2StagedPhysicalSessionReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let capture: Lane3InteractiveContinuityV2StagedCaptureSnapshot
    public let physicalSession: Lane3InteractiveContinuityV2PhysicalSessionReport
    public let captureCoordinatorComplete: Bool
    public let physicalSessionComplete: Bool
    public let differentialListeningBundleComplete: Bool
    public let parityPromotionAllowed: Bool

    public init(
        capture: Lane3InteractiveContinuityV2StagedCaptureSnapshot,
        physicalSession: Lane3InteractiveContinuityV2PhysicalSessionReport
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW41_STAGED_PHYSICAL_SESSION_NON_PARITY"
        self.capture = capture
        self.physicalSession = physicalSession
        self.captureCoordinatorComplete = capture.pendingCount == 0
            && capture.finalizingCount == 0
            && capture.retiredIdentityDrops == 0
            && capture.issueCount == 0
        self.physicalSessionComplete = captureCoordinatorComplete
            && physicalSession.physicalSessionComplete
        self.differentialListeningBundleComplete = physicalSessionComplete
            && physicalSession.differentialListeningBundleComplete
        self.parityPromotionAllowed = false
    }
}

public actor Lane3InteractiveContinuityV2StagedCaptureCoordinator {
    private struct PendingCapture: Sendable {
        let firstIntentUptimeNanoseconds: UInt64
        let requestedTarget: Lane3InteractiveContinuityMeasuredTarget
        var stampedOutcome: Lane3SelectedTransportGenerationStampedOutcome?
        var audibleMarker: Lane3InteractiveContinuityV2AudibleMarker?
    }

    private struct FinalizingCapture: Sendable {
        let stampedOutcome: Lane3SelectedTransportGenerationStampedOutcome
        let audibleMarker: Lane3InteractiveContinuityV2AudibleMarker
    }

    private struct FinalizationWork: Sendable {
        let sampleID: UInt64
        let firstIntentUptimeNanoseconds: UInt64
        let requestedTarget: Lane3InteractiveContinuityMeasuredTarget
        let stampedOutcome: Lane3SelectedTransportGenerationStampedOutcome
        let audibleMarker: Lane3InteractiveContinuityV2AudibleMarker
    }

    private enum RetiredCaptureKind: Sendable {
        case executed
        case nonExecuted
        case expired
    }

    private struct RetiredCapture: Sendable {
        let stampedOutcome: Lane3SelectedTransportGenerationStampedOutcome?
        let audibleMarker: Lane3InteractiveContinuityV2AudibleMarker?
        let kind: RetiredCaptureKind
    }

    private let correlator: any Lane3LeaseStampedContinuityCorrelating
    private let pendingCapacity: Int
    private let issueDetailCapacity: Int
    private let retiredIdentityCapacity: Int

    private var pending: [UInt64: PendingCapture] = [:]
    private var finalizing: [UInt64: FinalizingCapture] = [:]
    private var physicalSessionBuffer: Lane3InteractiveContinuityV2PhysicalSessionBuffer

    private var retiredCaptures: [UInt64: RetiredCapture] = [:]
    private var retiredRing: [UInt64?]
    private var retiredRingCount = 0
    private var retiredRingNextOverwrite = 0
    private var retiredIdentityDrops: UInt64 = 0

    private var issues: [Lane3InteractiveContinuityV2StagedCaptureIssue] = []
    private var issueCount: UInt64 = 0
    private var issueDetailDrops: UInt64 = 0
    private var finalizedExecutedCount: UInt64 = 0
    private var finalizedNonExecutedCount: UInt64 = 0
    private var expiredCount: UInt64 = 0
    private var idempotentDuplicateCallbackCount: UInt64 = 0

    public init(
        correlator: any Lane3LeaseStampedContinuityCorrelating,
        sessionCapacity: Int = 4_096,
        pendingCapacity: Int = 4_096,
        issueDetailCapacity: Int = 1_024,
        retiredIdentityCapacity: Int = 4_096
    ) {
        self.correlator = correlator
        self.physicalSessionBuffer = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: sessionCapacity)
        self.pendingCapacity = min(max(pendingCapacity, 16), 65_536)
        self.issueDetailCapacity = min(max(issueDetailCapacity, 16), 4_096)
        self.retiredIdentityCapacity = min(max(retiredIdentityCapacity, 16), 65_536)
        self.retiredRing = Array(repeating: nil, count: self.retiredIdentityCapacity)
    }

    @discardableResult
    public func beginSample(
        sampleID: UInt64,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget
    ) -> Lane3InteractiveContinuityV2StagedCaptureDisposition {
        if pending[sampleID] != nil || finalizing[sampleID] != nil || retiredCaptures[sampleID] != nil {
            recordIssue(
                sampleID: sampleID,
                kind: .duplicateSampleID,
                detail: "sampleID already exists in pending, finalizing, or retained retired identity window"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        guard pending.count < pendingCapacity else {
            recordIssue(
                sampleID: sampleID,
                kind: .pendingCapacityExceeded,
                detail: "pending staged-capture capacity exceeded"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        pending[sampleID] = PendingCapture(
            firstIntentUptimeNanoseconds: firstIntentUptimeNanoseconds,
            requestedTarget: requestedTarget,
            stampedOutcome: nil,
            audibleMarker: nil
        )
        return .accepted
    }

    @discardableResult
    public func recordStampedOutcome(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome
    ) async -> Lane3InteractiveContinuityV2StagedCaptureDisposition {
        if let active = finalizing[sampleID] {
            if active.stampedOutcome == stamped {
                idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                return .idempotentDuplicateIgnored
            }
            recordIssue(
                sampleID: sampleID,
                kind: .conflictingDuplicateStampedOutcome,
                detail: "conflicting stamped outcome arrived while sample finalization was in flight"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        guard var capture = pending[sampleID] else {
            if let retired = retiredCaptures[sampleID],
               retired.kind != .expired,
               retired.stampedOutcome == stamped {
                idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                return .idempotentDuplicateIgnored
            }
            let kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind = retiredCaptures[sampleID] == nil
                ? .unknownSampleIDForStampedOutcome
                : .conflictingDuplicateStampedOutcome
            recordIssue(
                sampleID: sampleID,
                kind: kind,
                detail: "stamped outcome arrived without an active staged sample or conflicts with its retained retired callback"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        if let existing = capture.stampedOutcome {
            if existing == stamped {
                idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                return .idempotentDuplicateIgnored
            }
            recordIssue(
                sampleID: sampleID,
                kind: .conflictingDuplicateStampedOutcome,
                detail: "active staged sample received two different stamped outcomes"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }

        if !Self.isExecuted(stamped) {
            pending.removeValue(forKey: sampleID)
            if capture.audibleMarker != nil {
                recordIssue(
                    sampleID: sampleID,
                    kind: .audibleMarkerForNonExecutedOutcome,
                    detail: "audible marker was recorded for an outcome that never executed transport"
                )
                physicalSessionBuffer.noteUnusableInstrumentationResult()
            }
            physicalSessionBuffer.append(
                leaseStampedCorrelation: .nonExecuted(
                    slotGeneration: stamped.slotGeneration,
                    outcome: stamped.outcome
                )
            )
            finalizedNonExecutedCount = Self.saturatingIncrement(finalizedNonExecutedCount)
            retire(
                sampleID,
                stampedOutcome: stamped,
                audibleMarker: capture.audibleMarker,
                kind: .nonExecuted
            )
            return .finalizedNonExecuted
        }

        capture.stampedOutcome = stamped
        pending[sampleID] = capture
        guard let work = takeFinalizationWorkIfReady(sampleID: sampleID) else {
            return .accepted
        }
        await finish(work)
        return .finalizedExecuted
    }

    @discardableResult
    public func recordAudibleMarker(
        sampleID: UInt64,
        marker: Lane3InteractiveContinuityV2AudibleMarker
    ) async -> Lane3InteractiveContinuityV2StagedCaptureDisposition {
        if let active = finalizing[sampleID] {
            if active.audibleMarker == marker {
                idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                return .idempotentDuplicateIgnored
            }
            recordIssue(
                sampleID: sampleID,
                kind: .conflictingDuplicateAudibleMarker,
                detail: "conflicting audible marker arrived while sample finalization was in flight"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        guard var capture = pending[sampleID] else {
            if let retired = retiredCaptures[sampleID] {
                if retired.kind == .executed, retired.audibleMarker == marker {
                    idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                    return .idempotentDuplicateIgnored
                }
                let kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind = retired.kind == .nonExecuted
                    ? .audibleMarkerForNonExecutedOutcome
                    : .conflictingDuplicateAudibleMarker
                recordIssue(
                    sampleID: sampleID,
                    kind: kind,
                    detail: "audible marker arrived after retirement and is not an exact idempotent executed callback"
                )
                physicalSessionBuffer.noteUnusableInstrumentationResult()
                return .rejected
            }
            recordIssue(
                sampleID: sampleID,
                kind: .unknownSampleIDForAudibleMarker,
                detail: "audible marker arrived without an active staged sample"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        if let existing = capture.audibleMarker {
            if existing == marker {
                idempotentDuplicateCallbackCount = Self.saturatingIncrement(idempotentDuplicateCallbackCount)
                return .idempotentDuplicateIgnored
            }
            recordIssue(
                sampleID: sampleID,
                kind: .conflictingDuplicateAudibleMarker,
                detail: "active staged sample received two different audible markers"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            return .rejected
        }
        capture.audibleMarker = marker
        pending[sampleID] = capture
        guard let work = takeFinalizationWorkIfReady(sampleID: sampleID) else {
            return .accepted
        }
        await finish(work)
        return .finalizedExecuted
    }

    /// Explicit expiry keeps the coordinator timer-free. The iOS/HQ host supplies a monotonic cutoff
    /// in the same uptime clock domain used for first-intent capture. Expired samples are never silently
    /// discarded; every expiry poisons physical-session completeness through AW40's unusable counter.
    @discardableResult
    public func expirePending(
        firstIntentBeforeUptimeNanoseconds cutoff: UInt64
    ) -> Int {
        let expiredIDs = pending.compactMap { sampleID, capture in
            capture.firstIntentUptimeNanoseconds < cutoff ? sampleID : nil
        }
        for sampleID in expiredIDs {
            guard let capture = pending.removeValue(forKey: sampleID) else { continue }
            let kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind
            let detail: String
            if capture.stampedOutcome == nil {
                kind = .expiredBeforeStampedOutcome
                detail = "sample expired before an AW39 stamped transport outcome arrived"
            } else {
                kind = .expiredBeforeAudibleMarker
                detail = "executed sample expired before an external audible marker arrived"
            }
            recordIssue(sampleID: sampleID, kind: kind, detail: detail)
            physicalSessionBuffer.noteUnusableInstrumentationResult()
            expiredCount = Self.saturatingIncrement(expiredCount)
            retire(
                sampleID,
                stampedOutcome: capture.stampedOutcome,
                audibleMarker: capture.audibleMarker,
                kind: .expired
            )
        }
        return expiredIDs.count
    }

    public func snapshot() -> Lane3InteractiveContinuityV2StagedCaptureSnapshot {
        Lane3InteractiveContinuityV2StagedCaptureSnapshot(
            pendingCount: pending.count,
            finalizingCount: finalizing.count,
            retiredIdentityCount: retiredCaptures.count,
            retiredIdentityDrops: retiredIdentityDrops,
            finalizedExecutedCount: finalizedExecutedCount,
            finalizedNonExecutedCount: finalizedNonExecutedCount,
            expiredCount: expiredCount,
            idempotentDuplicateCallbackCount: idempotentDuplicateCallbackCount,
            issueCount: issueCount,
            issueDetailDrops: issueDetailDrops
        )
    }

    public func retainedIssues() -> [Lane3InteractiveContinuityV2StagedCaptureIssue] {
        issues
    }

    public func report(
        context: Lane3InteractiveContinuityV2PhysicalSessionContext
    ) -> Lane3InteractiveContinuityV2StagedPhysicalSessionReport {
        let capture = snapshot()
        let physical = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: context,
            buffer: physicalSessionBuffer
        )
        return .init(capture: capture, physicalSession: physical)
    }

    private func takeFinalizationWorkIfReady(sampleID: UInt64) -> FinalizationWork? {
        guard let capture = pending[sampleID],
              let stamped = capture.stampedOutcome,
              let audible = capture.audibleMarker,
              Self.isExecuted(stamped) else {
            return nil
        }
        pending.removeValue(forKey: sampleID)
        finalizing[sampleID] = FinalizingCapture(
            stampedOutcome: stamped,
            audibleMarker: audible
        )
        return FinalizationWork(
            sampleID: sampleID,
            firstIntentUptimeNanoseconds: capture.firstIntentUptimeNanoseconds,
            requestedTarget: capture.requestedTarget,
            stampedOutcome: stamped,
            audibleMarker: audible
        )
    }

    private func finish(_ work: FinalizationWork) async {
        let correlation = await correlator.correlateLeaseStamped(
            sampleID: work.sampleID,
            stamped: work.stampedOutcome,
            firstIntentUptimeNanoseconds: work.firstIntentUptimeNanoseconds,
            requestedTarget: work.requestedTarget,
            audibleResultUptimeNanoseconds: work.audibleMarker.uptimeNanoseconds,
            audibleTimestampSource: work.audibleMarker.source
        )
        switch correlation {
        case .instrumented:
            _ = physicalSessionBuffer.append(leaseStampedCorrelation: correlation)
            finalizedExecutedCount = Self.saturatingIncrement(finalizedExecutedCount)
        case .nonExecuted:
            recordIssue(
                sampleID: work.sampleID,
                kind: .unexpectedNonExecutedCorrelation,
                detail: "an AW39 executed stamped outcome unexpectedly correlated as non-executed"
            )
            physicalSessionBuffer.noteUnusableInstrumentationResult()
        }
        finalizing.removeValue(forKey: work.sampleID)
        retire(
            work.sampleID,
            stampedOutcome: work.stampedOutcome,
            audibleMarker: work.audibleMarker,
            kind: .executed
        )
    }

    private func retire(
        _ sampleID: UInt64,
        stampedOutcome: Lane3SelectedTransportGenerationStampedOutcome?,
        audibleMarker: Lane3InteractiveContinuityV2AudibleMarker?,
        kind: RetiredCaptureKind
    ) {
        let retired = RetiredCapture(
            stampedOutcome: stampedOutcome,
            audibleMarker: audibleMarker,
            kind: kind
        )
        if retiredRingCount < retiredIdentityCapacity {
            retiredRing[retiredRingCount] = sampleID
            retiredRingCount += 1
            retiredCaptures[sampleID] = retired
            if retiredRingCount == retiredIdentityCapacity {
                retiredRingNextOverwrite = 0
            }
            return
        }
        if let previous = retiredRing[retiredRingNextOverwrite] {
            retiredCaptures.removeValue(forKey: previous)
        }
        retiredRing[retiredRingNextOverwrite] = sampleID
        retiredCaptures[sampleID] = retired
        retiredRingNextOverwrite += 1
        if retiredRingNextOverwrite == retiredIdentityCapacity {
            retiredRingNextOverwrite = 0
        }
        retiredIdentityDrops = Self.saturatingIncrement(retiredIdentityDrops)
        if retiredIdentityDrops == 1 {
            recordIssue(
                sampleID: nil,
                kind: .retiredIdentityWindowTruncated,
                detail: "retired sample identity window wrapped; older duplicate IDs can no longer be detected"
            )
        }
    }

    private func recordIssue(
        sampleID: UInt64?,
        kind: Lane3InteractiveContinuityV2StagedCaptureIssueKind,
        detail: String
    ) {
        issueCount = Self.saturatingIncrement(issueCount)
        if issues.count < issueDetailCapacity {
            issues.append(.init(sampleID: sampleID, kind: kind, detail: detail))
        } else {
            issueDetailDrops = Self.saturatingIncrement(issueDetailDrops)
        }
    }

    private static func isExecuted(
        _ stamped: Lane3SelectedTransportGenerationStampedOutcome
    ) -> Bool {
        if case .transport(.executed) = stamped.outcome { return true }
        return false
    }

    private static func saturatingIncrement(_ value: UInt64) -> UInt64 {
        let next = value.addingReportingOverflow(1)
        return next.overflow ? UInt64.max : next.partialValue
    }
}
