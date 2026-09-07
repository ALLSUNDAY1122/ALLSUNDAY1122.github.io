import Foundation

public enum Lane3CancellationRaceProbeOutcome: Equatable, Sendable {
    case executed(callerCancellationObservedAfterDispatch: Bool)
    case supersededBeforeToken
    case cancelledBeforeDispatch
    case rejectedBeforeToken
    case failedAfterDispatch(callerCancellationObservedAfterDispatch: Bool)
}

public struct Lane3CancellationRaceProbeSnapshot: Equatable, Sendable {
    public let pendingOperationCount: Int
    public let executionInFlight: Bool
    public let admittingTicketCount: Int
    public let cancelledBeforeEnqueueTicketCount: Int
    public let lateRetiredCancellationIgnored: UInt64
    public let cancellationCounterOverflowed: Bool
    public let admissionInvariantHolds: Bool

    public init(
        pendingOperationCount: Int,
        executionInFlight: Bool,
        admittingTicketCount: Int,
        cancelledBeforeEnqueueTicketCount: Int,
        lateRetiredCancellationIgnored: UInt64,
        cancellationCounterOverflowed: Bool,
        admissionInvariantHolds: Bool
    ) {
        self.pendingOperationCount = pendingOperationCount
        self.executionInFlight = executionInFlight
        self.admittingTicketCount = admittingTicketCount
        self.cancelledBeforeEnqueueTicketCount = cancelledBeforeEnqueueTicketCount
        self.lateRetiredCancellationIgnored = lateRetiredCancellationIgnored
        self.cancellationCounterOverflowed = cancellationCounterOverflowed
        self.admissionInvariantHolds = admissionInvariantHolds
    }

    public var isQuiescent: Bool {
        pendingOperationCount == 0
            && !executionInFlight
            && admittingTicketCount == 0
            && cancelledBeforeEnqueueTicketCount == 0
    }
}

public protocol Lane3CancellationRaceProbeDriving: Sendable {
    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome
    func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot
}

public struct Lane3CancellationRaceProbePolicy: Equatable, Sendable {
    public let iterations: Int
    public let batchSize: Int
    public let postOperationSettlementYields: Int
    public let quiescencePollLimit: Int

    public init(
        iterations: Int = 10_000,
        batchSize: Int = 64,
        postOperationSettlementYields: Int = 8,
        quiescencePollLimit: Int = 10_000
    ) {
        precondition(iterations >= 1 && iterations <= 1_000_000)
        precondition(batchSize >= 1 && batchSize <= 4_096)
        precondition(postOperationSettlementYields >= 0 && postOperationSettlementYields <= 10_000)
        precondition(quiescencePollLimit >= 1 && quiescencePollLimit <= 1_000_000)
        self.iterations = iterations
        self.batchSize = batchSize
        self.postOperationSettlementYields = postOperationSettlementYields
        self.quiescencePollLimit = quiescencePollLimit
    }
}

public struct Lane3CancellationRaceProbeReport: Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let iterations: Int
    public let cancellationRequests: Int
    public let executed: Int
    public let supersededBeforeToken: Int
    public let cancelledBeforeDispatch: Int
    public let rejectedBeforeToken: Int
    public let failedAfterDispatch: Int
    public let cancellationObservedAfterDispatch: Int
    public let lateRetiredCancellationDelta: UInt64
    public let maximumAdmittingTicketCount: Int
    public let maximumCancelledBeforeEnqueueTicketCount: Int
    public let finalSnapshot: Lane3CancellationRaceProbeSnapshot
    public let settlementYieldsPerformed: Int
    public let quiescencePolls: Int
    public let counterRegressionDetected: Bool
    public let accountingComplete: Bool
    public let boundednessPass: Bool
    public let parityPromotionAllowed: Bool

    public init(
        iterations: Int,
        cancellationRequests: Int,
        executed: Int,
        supersededBeforeToken: Int,
        cancelledBeforeDispatch: Int,
        rejectedBeforeToken: Int,
        failedAfterDispatch: Int,
        cancellationObservedAfterDispatch: Int,
        lateRetiredCancellationDelta: UInt64,
        maximumAdmittingTicketCount: Int,
        maximumCancelledBeforeEnqueueTicketCount: Int,
        finalSnapshot: Lane3CancellationRaceProbeSnapshot,
        settlementYieldsPerformed: Int,
        quiescencePolls: Int,
        counterRegressionDetected: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW37_ACTUAL_AUTHORITY_CANCELLATION_RACE_NON_PARITY"
        self.iterations = iterations
        self.cancellationRequests = cancellationRequests
        self.executed = executed
        self.supersededBeforeToken = supersededBeforeToken
        self.cancelledBeforeDispatch = cancelledBeforeDispatch
        self.rejectedBeforeToken = rejectedBeforeToken
        self.failedAfterDispatch = failedAfterDispatch
        self.cancellationObservedAfterDispatch = cancellationObservedAfterDispatch
        self.lateRetiredCancellationDelta = lateRetiredCancellationDelta
        self.maximumAdmittingTicketCount = maximumAdmittingTicketCount
        self.maximumCancelledBeforeEnqueueTicketCount = maximumCancelledBeforeEnqueueTicketCount
        self.finalSnapshot = finalSnapshot
        self.settlementYieldsPerformed = settlementYieldsPerformed
        self.quiescencePolls = quiescencePolls
        self.counterRegressionDetected = counterRegressionDetected
        self.accountingComplete = executed + supersededBeforeToken + cancelledBeforeDispatch + rejectedBeforeToken + failedAfterDispatch == iterations
        self.boundednessPass = self.accountingComplete
            && finalSnapshot.isQuiescent
            && finalSnapshot.admissionInvariantHolds
            && !finalSnapshot.cancellationCounterOverflowed
            && !counterRegressionDetected
        self.parityPromotionAllowed = false
    }
}

public enum Lane3CancellationRaceProbe {
    public static func run(
        driver: any Lane3CancellationRaceProbeDriving,
        policy: Lane3CancellationRaceProbePolicy = Lane3CancellationRaceProbePolicy()
    ) async -> Lane3CancellationRaceProbeReport {
        let initial = await driver.cancellationRaceProbeSnapshot()
        var executed = 0
        var superseded = 0
        var cancelled = 0
        var rejected = 0
        var failed = 0
        var cancellationAfterDispatch = 0
        var cancellationRequests = 0
        var maxAdmitting = initial.admittingTicketCount
        var maxCancelledMarkers = initial.cancelledBeforeEnqueueTicketCount

        var base = 0
        while base < policy.iterations {
            let upper = min(policy.iterations, base + policy.batchSize)
            var tasks: [(index: Int, task: Task<Lane3CancellationRaceProbeOutcome, Never>)] = []
            tasks.reserveCapacity(upper - base)

            for index in base..<upper {
                let task = Task {
                    await driver.submitProbeOperation(index: index)
                }
                tasks.append((index, task))
                if index % 4 == 0 {
                    cancellationRequests += 1
                    task.cancel()
                }
            }

            await Task.yield()
            for entry in tasks where entry.index % 4 == 1 {
                cancellationRequests += 1
                entry.task.cancel()
            }

            await Task.yield()
            for entry in tasks where entry.index % 4 == 2 {
                cancellationRequests += 1
                entry.task.cancel()
            }

            for entry in tasks {
                switch await entry.task.value {
                case .executed(let observed):
                    executed += 1
                    if observed { cancellationAfterDispatch += 1 }
                case .supersededBeforeToken:
                    superseded += 1
                case .cancelledBeforeDispatch:
                    cancelled += 1
                case .rejectedBeforeToken:
                    rejected += 1
                case .failedAfterDispatch(let observed):
                    failed += 1
                    if observed { cancellationAfterDispatch += 1 }
                }
            }

            let snapshot = await driver.cancellationRaceProbeSnapshot()
            maxAdmitting = max(maxAdmitting, snapshot.admittingTicketCount)
            maxCancelledMarkers = max(maxCancelledMarkers, snapshot.cancelledBeforeEnqueueTicketCount)
            base = upper
        }

        // Cancellation handlers return to Lane3UnifiedProductionTransportAuthority through a child
        // Task. Give those already-created delivery Tasks deterministic scheduler opportunities before
        // reading the terminal telemetry counter; otherwise a quiescent transport snapshot could race
        // a telemetry-only late-retired cancellation that is still queued outside the actor.
        for _ in 0..<policy.postOperationSettlementYields {
            await Task.yield()
        }

        var final = await driver.cancellationRaceProbeSnapshot()
        var polls = 0
        while !final.isQuiescent && polls < policy.quiescencePollLimit {
            polls += 1
            await Task.yield()
            final = await driver.cancellationRaceProbeSnapshot()
            maxAdmitting = max(maxAdmitting, final.admittingTicketCount)
            maxCancelledMarkers = max(maxCancelledMarkers, final.cancelledBeforeEnqueueTicketCount)
        }

        let counterRegression = final.lateRetiredCancellationIgnored < initial.lateRetiredCancellationIgnored
        let lateDelta = counterRegression
            ? 0
            : final.lateRetiredCancellationIgnored - initial.lateRetiredCancellationIgnored

        return Lane3CancellationRaceProbeReport(
            iterations: policy.iterations,
            cancellationRequests: cancellationRequests,
            executed: executed,
            supersededBeforeToken: superseded,
            cancelledBeforeDispatch: cancelled,
            rejectedBeforeToken: rejected,
            failedAfterDispatch: failed,
            cancellationObservedAfterDispatch: cancellationAfterDispatch,
            lateRetiredCancellationDelta: lateDelta,
            maximumAdmittingTicketCount: maxAdmitting,
            maximumCancelledBeforeEnqueueTicketCount: maxCancelledMarkers,
            finalSnapshot: final,
            settlementYieldsPerformed: policy.postOperationSettlementYields,
            quiescencePolls: polls,
            counterRegressionDetected: counterRegression
        )
    }
}
