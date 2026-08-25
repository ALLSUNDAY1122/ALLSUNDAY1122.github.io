import Foundation

public enum Lane3InteractiveContinuityV2OperationShape: String, Codable, Sendable, CaseIterable {
    case seek
    case loopEnabled
    case loopDisabled
}

public struct Lane3InteractiveContinuityV2PhysicalSessionContext: Equatable, Codable, Sendable {
    public let sessionIdentifier: String
    public let physicalIPhone: Bool
    public let hardwareIdentifier: String
    public let osVersion: String
    public let appBuildIdentifier: String
    public let sampleRate: Double
    public let uptimeClockDomain: String
    public let audioFixtureIdentifier: String
    public let rightsClearedRealAudio: Bool
    public let currentMoisesDifferentialObserved: Bool
    public let humanListeningObserved: Bool

    public init(
        sessionIdentifier: String,
        physicalIPhone: Bool,
        hardwareIdentifier: String,
        osVersion: String,
        appBuildIdentifier: String,
        sampleRate: Double,
        uptimeClockDomain: String,
        audioFixtureIdentifier: String,
        rightsClearedRealAudio: Bool,
        currentMoisesDifferentialObserved: Bool,
        humanListeningObserved: Bool
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.physicalIPhone = physicalIPhone
        self.hardwareIdentifier = hardwareIdentifier
        self.osVersion = osVersion
        self.appBuildIdentifier = appBuildIdentifier
        self.sampleRate = sampleRate
        self.uptimeClockDomain = uptimeClockDomain
        self.audioFixtureIdentifier = audioFixtureIdentifier
        self.rightsClearedRealAudio = rightsClearedRealAudio
        self.currentMoisesDifferentialObserved = currentMoisesDifferentialObserved
        self.humanListeningObserved = humanListeningObserved
    }
}

public struct Lane3InteractiveContinuityV2SessionSample: Equatable, Codable, Sendable {
    public let sampleID: UInt64
    public let shape: Lane3InteractiveContinuityV2OperationShape
    public let firstIntentUptimeNanoseconds: UInt64
    public let tokenIssuedUptimeNanoseconds: UInt64
    public let backendCompletedUptimeNanoseconds: UInt64
    public let audibleResultUptimeNanoseconds: UInt64?
    public let audibleTimestampSource: String?
    public let callerCancellationObservedAfterDispatch: Bool
    public let instrumentationValidForV2: Bool
    public let generationStable: Bool
    public let timingOrderValid: Bool
    public let targetMatched: Bool
    public let externalAudibleMarkerValid: Bool

    public init(
        sampleID: UInt64,
        shape: Lane3InteractiveContinuityV2OperationShape,
        firstIntentUptimeNanoseconds: UInt64,
        tokenIssuedUptimeNanoseconds: UInt64,
        backendCompletedUptimeNanoseconds: UInt64,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?,
        callerCancellationObservedAfterDispatch: Bool,
        instrumentationValidForV2: Bool,
        generationStable: Bool,
        timingOrderValid: Bool,
        targetMatched: Bool,
        externalAudibleMarkerValid: Bool
    ) {
        self.sampleID = sampleID
        self.shape = shape
        self.firstIntentUptimeNanoseconds = firstIntentUptimeNanoseconds
        self.tokenIssuedUptimeNanoseconds = tokenIssuedUptimeNanoseconds
        self.backendCompletedUptimeNanoseconds = backendCompletedUptimeNanoseconds
        self.audibleResultUptimeNanoseconds = audibleResultUptimeNanoseconds
        self.audibleTimestampSource = audibleTimestampSource
        self.callerCancellationObservedAfterDispatch = callerCancellationObservedAfterDispatch
        self.instrumentationValidForV2 = instrumentationValidForV2
        self.generationStable = generationStable
        self.timingOrderValid = timingOrderValid
        self.targetMatched = targetMatched
        self.externalAudibleMarkerValid = externalAudibleMarkerValid
    }
}

public struct Lane3InteractiveContinuityV2Percentiles: Equatable, Codable, Sendable {
    public let count: Int
    public let p50Nanoseconds: UInt64?
    public let p95Nanoseconds: UInt64?
    public let p99Nanoseconds: UInt64?
    public let maximumNanoseconds: UInt64?

    public init(valuesNanoseconds: [UInt64]) {
        let sorted = valuesNanoseconds.sorted()
        self.count = sorted.count
        self.p50Nanoseconds = Self.nearestRank(0.50, sorted: sorted)
        self.p95Nanoseconds = Self.nearestRank(0.95, sorted: sorted)
        self.p99Nanoseconds = Self.nearestRank(0.99, sorted: sorted)
        self.maximumNanoseconds = sorted.last
    }

    private static func nearestRank(_ percentile: Double, sorted: [UInt64]) -> UInt64? {
        guard !sorted.isEmpty else { return nil }
        let rank = max(1, Int(ceil(percentile * Double(sorted.count))))
        return sorted[min(sorted.count - 1, rank - 1)]
    }
}

public struct Lane3InteractiveContinuityV2LatencySummary: Equatable, Codable, Sendable {
    public let sampleCount: Int
    public let firstIntentToToken: Lane3InteractiveContinuityV2Percentiles
    public let tokenToBackendCompletion: Lane3InteractiveContinuityV2Percentiles
    public let firstIntentToBackendCompletion: Lane3InteractiveContinuityV2Percentiles
    public let firstIntentToAudibleResult: Lane3InteractiveContinuityV2Percentiles
    public let tokenToAudibleResult: Lane3InteractiveContinuityV2Percentiles

    fileprivate init(samples: [Lane3InteractiveContinuityV2SessionSample]) {
        var intentToToken: [UInt64] = []
        var tokenToBackend: [UInt64] = []
        var intentToBackend: [UInt64] = []
        var intentToAudible: [UInt64] = []
        var tokenToAudible: [UInt64] = []
        intentToToken.reserveCapacity(samples.count)
        tokenToBackend.reserveCapacity(samples.count)
        intentToBackend.reserveCapacity(samples.count)
        intentToAudible.reserveCapacity(samples.count)
        tokenToAudible.reserveCapacity(samples.count)

        for sample in samples where sample.timingOrderValid {
            if sample.tokenIssuedUptimeNanoseconds >= sample.firstIntentUptimeNanoseconds {
                intentToToken.append(
                    sample.tokenIssuedUptimeNanoseconds - sample.firstIntentUptimeNanoseconds
                )
            }
            if sample.backendCompletedUptimeNanoseconds >= sample.tokenIssuedUptimeNanoseconds {
                tokenToBackend.append(
                    sample.backendCompletedUptimeNanoseconds - sample.tokenIssuedUptimeNanoseconds
                )
            }
            if sample.backendCompletedUptimeNanoseconds >= sample.firstIntentUptimeNanoseconds {
                intentToBackend.append(
                    sample.backendCompletedUptimeNanoseconds - sample.firstIntentUptimeNanoseconds
                )
            }
            if let audible = sample.audibleResultUptimeNanoseconds,
               sample.externalAudibleMarkerValid,
               audible >= sample.firstIntentUptimeNanoseconds {
                intentToAudible.append(audible - sample.firstIntentUptimeNanoseconds)
                if audible >= sample.tokenIssuedUptimeNanoseconds {
                    tokenToAudible.append(audible - sample.tokenIssuedUptimeNanoseconds)
                }
            }
        }

        self.sampleCount = samples.count
        self.firstIntentToToken = .init(valuesNanoseconds: intentToToken)
        self.tokenToBackendCompletion = .init(valuesNanoseconds: tokenToBackend)
        self.firstIntentToBackendCompletion = .init(valuesNanoseconds: intentToBackend)
        self.firstIntentToAudibleResult = .init(valuesNanoseconds: intentToAudible)
        self.tokenToAudibleResult = .init(valuesNanoseconds: tokenToAudible)
    }
}

public enum Lane3InteractiveContinuityV2SessionIssueKind: String, Codable, Sendable {
    case invalidDeviceContext
    case notPhysicalIPhone
    case rightsClearedRealAudioMissing
    case capacityDropsPresent
    case unusableInstrumentationResultsPresent
    case duplicateSampleID
    case invalidInstrumentation
    case generationUnstable
    case timingInvalid
    case targetMismatch
    case missingExternalAudibleMarker
    case missingSeekCoverage
    case missingEnabledLoopCoverage
    case missingLoopDisabledCoverage
    case currentMoisesDifferentialMissing
    case humanListeningMissing
}

public struct Lane3InteractiveContinuityV2SessionIssue: Equatable, Codable, Sendable {
    public let sampleID: UInt64?
    public let kind: Lane3InteractiveContinuityV2SessionIssueKind
    public let detail: String

    public init(
        sampleID: UInt64?,
        kind: Lane3InteractiveContinuityV2SessionIssueKind,
        detail: String
    ) {
        self.sampleID = sampleID
        self.kind = kind
        self.detail = detail
    }
}

public struct Lane3InteractiveContinuityV2PhysicalSessionReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let retainedSampleCount: Int
    public let capacityDrops: UInt64
    public let nonExecutedObservationCount: UInt64
    public let unusableInstrumentationResultCount: UInt64
    public let seekSampleCount: Int
    public let enabledLoopSampleCount: Int
    public let loopDisabledSampleCount: Int
    public let callerCancellationAfterDispatchCount: Int
    public let invalidInstrumentationSampleCount: Int
    public let generationUnstableSampleCount: Int
    public let timingInvalidSampleCount: Int
    public let targetMismatchSampleCount: Int
    public let missingExternalAudibleMarkerCount: Int
    public let fullyValidPhysicalSampleCount: Int
    public let duplicateSampleIDCount: Int
    public let overallLatency: Lane3InteractiveContinuityV2LatencySummary
    public let seekLatency: Lane3InteractiveContinuityV2LatencySummary
    public let enabledLoopLatency: Lane3InteractiveContinuityV2LatencySummary
    public let loopDisabledLatency: Lane3InteractiveContinuityV2LatencySummary
    public let issues: [Lane3InteractiveContinuityV2SessionIssue]
    public let issueDetailDrops: UInt64
    public let physicalSessionComplete: Bool
    public let differentialListeningBundleComplete: Bool
    public let parityPromotionAllowed: Bool

    public init(
        retainedSampleCount: Int,
        capacityDrops: UInt64,
        nonExecutedObservationCount: UInt64,
        unusableInstrumentationResultCount: UInt64,
        seekSampleCount: Int,
        enabledLoopSampleCount: Int,
        loopDisabledSampleCount: Int,
        callerCancellationAfterDispatchCount: Int,
        invalidInstrumentationSampleCount: Int,
        generationUnstableSampleCount: Int,
        timingInvalidSampleCount: Int,
        targetMismatchSampleCount: Int,
        missingExternalAudibleMarkerCount: Int,
        fullyValidPhysicalSampleCount: Int,
        duplicateSampleIDCount: Int,
        overallLatency: Lane3InteractiveContinuityV2LatencySummary,
        seekLatency: Lane3InteractiveContinuityV2LatencySummary,
        enabledLoopLatency: Lane3InteractiveContinuityV2LatencySummary,
        loopDisabledLatency: Lane3InteractiveContinuityV2LatencySummary,
        issues: [Lane3InteractiveContinuityV2SessionIssue],
        issueDetailDrops: UInt64,
        physicalSessionComplete: Bool,
        differentialListeningBundleComplete: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW40_V2_PHYSICAL_SESSION_NON_PARITY"
        self.retainedSampleCount = retainedSampleCount
        self.capacityDrops = capacityDrops
        self.nonExecutedObservationCount = nonExecutedObservationCount
        self.unusableInstrumentationResultCount = unusableInstrumentationResultCount
        self.seekSampleCount = seekSampleCount
        self.enabledLoopSampleCount = enabledLoopSampleCount
        self.loopDisabledSampleCount = loopDisabledSampleCount
        self.callerCancellationAfterDispatchCount = callerCancellationAfterDispatchCount
        self.invalidInstrumentationSampleCount = invalidInstrumentationSampleCount
        self.generationUnstableSampleCount = generationUnstableSampleCount
        self.timingInvalidSampleCount = timingInvalidSampleCount
        self.targetMismatchSampleCount = targetMismatchSampleCount
        self.missingExternalAudibleMarkerCount = missingExternalAudibleMarkerCount
        self.fullyValidPhysicalSampleCount = fullyValidPhysicalSampleCount
        self.duplicateSampleIDCount = duplicateSampleIDCount
        self.overallLatency = overallLatency
        self.seekLatency = seekLatency
        self.enabledLoopLatency = enabledLoopLatency
        self.loopDisabledLatency = loopDisabledLatency
        self.issues = issues
        self.issueDetailDrops = issueDetailDrops
        self.physicalSessionComplete = physicalSessionComplete
        self.differentialListeningBundleComplete = differentialListeningBundleComplete
        self.parityPromotionAllowed = false
    }
}

public struct Lane3InteractiveContinuityV2PhysicalSessionBuffer: Sendable {
    public let capacity: Int
    public private(set) var capacityDrops: UInt64 = 0
    public private(set) var nonExecutedObservationCount: UInt64 = 0
    public private(set) var unusableInstrumentationResultCount: UInt64 = 0

    private var storage: [Lane3InteractiveContinuityV2SessionSample?]
    private var count: Int = 0
    private var nextOverwriteIndex: Int = 0

    public init(capacity: Int = 4_096) {
        let normalized = min(max(capacity, 16), 65_536)
        self.capacity = normalized
        self.storage = Array(repeating: nil, count: normalized)
    }

    public var retainedCount: Int { count }

    public mutating func append(_ sample: Lane3InteractiveContinuityV2SessionSample) {
        if count < capacity {
            storage[count] = sample
            count += 1
            if count == capacity { nextOverwriteIndex = 0 }
            return
        }

        storage[nextOverwriteIndex] = sample
        nextOverwriteIndex += 1
        if nextOverwriteIndex == capacity { nextOverwriteIndex = 0 }
        capacityDrops = Self.saturatingIncrement(capacityDrops)
    }

    public mutating func noteNonExecutedObservation() {
        nonExecutedObservationCount = Self.saturatingIncrement(nonExecutedObservationCount)
    }

    public mutating func noteUnusableInstrumentationResult() {
        unusableInstrumentationResultCount = Self.saturatingIncrement(unusableInstrumentationResultCount)
    }

    public func orderedSamples() -> [Lane3InteractiveContinuityV2SessionSample] {
        guard count > 0 else { return [] }
        if count < capacity {
            return storage[0..<count].compactMap { $0 }
        }
        var result: [Lane3InteractiveContinuityV2SessionSample] = []
        result.reserveCapacity(capacity)
        for index in nextOverwriteIndex..<capacity {
            if let sample = storage[index] { result.append(sample) }
        }
        if nextOverwriteIndex > 0 {
            for index in 0..<nextOverwriteIndex {
                if let sample = storage[index] { result.append(sample) }
            }
        }
        return result
    }

    private static func saturatingIncrement(_ value: UInt64) -> UInt64 {
        let next = value.addingReportingOverflow(1)
        return next.overflow ? UInt64.max : next.partialValue
    }
}

public enum Lane3InteractiveContinuityV2PhysicalSessionAnalyzer {
    public static func analyze(
        context: Lane3InteractiveContinuityV2PhysicalSessionContext,
        buffer: Lane3InteractiveContinuityV2PhysicalSessionBuffer,
        issueDetailCapacity: Int = 1_024
    ) -> Lane3InteractiveContinuityV2PhysicalSessionReport {
        let samples = buffer.orderedSamples()
        let normalizedIssueCapacity = min(max(issueDetailCapacity, 16), 4_096)
        var issues: [Lane3InteractiveContinuityV2SessionIssue] = []
        issues.reserveCapacity(min(normalizedIssueCapacity, samples.count + 16))
        var issueDetailDrops: UInt64 = 0

        func appendIssue(_ issue: Lane3InteractiveContinuityV2SessionIssue) {
            if issues.count < normalizedIssueCapacity {
                issues.append(issue)
            } else {
                let next = issueDetailDrops.addingReportingOverflow(1)
                issueDetailDrops = next.overflow ? UInt64.max : next.partialValue
            }
        }

        let contextStringsValid = !context.sessionIdentifier.isEmpty
            && !context.hardwareIdentifier.isEmpty
            && !context.osVersion.isEmpty
            && !context.appBuildIdentifier.isEmpty
            && !context.uptimeClockDomain.isEmpty
            && !context.audioFixtureIdentifier.isEmpty
        let sampleRateValid = context.sampleRate.isFinite && context.sampleRate > 0
        let deviceContextValid = contextStringsValid && sampleRateValid

        if !deviceContextValid {
            appendIssue(.init(
                sampleID: nil,
                kind: .invalidDeviceContext,
                detail: "session/device/build/clock/audio fixture metadata and positive finite sample rate are required"
            ))
        }
        if !context.physicalIPhone {
            appendIssue(.init(
                sampleID: nil,
                kind: .notPhysicalIPhone,
                detail: "physical iPhone execution is required"
            ))
        }
        if !context.rightsClearedRealAudio {
            appendIssue(.init(
                sampleID: nil,
                kind: .rightsClearedRealAudioMissing,
                detail: "rights-cleared real audio is required"
            ))
        }
        if buffer.capacityDrops > 0 {
            appendIssue(.init(
                sampleID: nil,
                kind: .capacityDropsPresent,
                detail: "bounded recorder dropped \(buffer.capacityDrops) oldest samples"
            ))
        }
        if buffer.unusableInstrumentationResultCount > 0 {
            appendIssue(.init(
                sampleID: nil,
                kind: .unusableInstrumentationResultsPresent,
                detail: "\(buffer.unusableInstrumentationResultCount) instrumentation results lacked a usable v2 observation"
            ))
        }

        var seenIDs: Set<UInt64> = []
        seenIDs.reserveCapacity(samples.count)
        var duplicateCount = 0
        var seekSamples: [Lane3InteractiveContinuityV2SessionSample] = []
        var enabledLoopSamples: [Lane3InteractiveContinuityV2SessionSample] = []
        var loopDisabledSamples: [Lane3InteractiveContinuityV2SessionSample] = []
        seekSamples.reserveCapacity(samples.count / 3 + 1)
        enabledLoopSamples.reserveCapacity(samples.count / 3 + 1)
        loopDisabledSamples.reserveCapacity(samples.count / 3 + 1)

        var cancellationAfterDispatchCount = 0
        var invalidInstrumentationCount = 0
        var generationUnstableCount = 0
        var timingInvalidCount = 0
        var targetMismatchCount = 0
        var missingAudibleCount = 0
        var fullyValidCount = 0

        for sample in samples {
            if !seenIDs.insert(sample.sampleID).inserted {
                duplicateCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .duplicateSampleID,
                    detail: "sampleID is duplicated within the retained session window"
                ))
            }

            switch sample.shape {
            case .seek: seekSamples.append(sample)
            case .loopEnabled: enabledLoopSamples.append(sample)
            case .loopDisabled: loopDisabledSamples.append(sample)
            }

            if sample.callerCancellationObservedAfterDispatch {
                cancellationAfterDispatchCount += 1
            }
            if !sample.instrumentationValidForV2 {
                invalidInstrumentationCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .invalidInstrumentation,
                    detail: "AW38 instrumentation has a v2-blocking issue"
                ))
            }
            if !sample.generationStable {
                generationUnstableCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .generationUnstable,
                    detail: "executed sample crosses selected reconstruction generation"
                ))
            }

            let timestampOrderValid = sample.tokenIssuedUptimeNanoseconds >= sample.firstIntentUptimeNanoseconds
                && sample.backendCompletedUptimeNanoseconds >= sample.tokenIssuedUptimeNanoseconds
                && (sample.audibleResultUptimeNanoseconds == nil
                    || sample.audibleResultUptimeNanoseconds! >= sample.tokenIssuedUptimeNanoseconds)
            if !sample.timingOrderValid || !timestampOrderValid {
                timingInvalidCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .timingInvalid,
                    detail: "intent/token/backend/audible timing order is invalid"
                ))
            }
            if !sample.targetMatched {
                targetMismatchCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .targetMismatch,
                    detail: "requested and backend-applied v2 targets do not match"
                ))
            }

            let audibleComplete = sample.externalAudibleMarkerValid
                && sample.audibleResultUptimeNanoseconds != nil
                && !(sample.audibleTimestampSource ?? "").isEmpty
            if !audibleComplete {
                missingAudibleCount += 1
                appendIssue(.init(
                    sampleID: sample.sampleID,
                    kind: .missingExternalAudibleMarker,
                    detail: "independently observed audible timestamp and non-empty source are required"
                ))
            }

            if sample.instrumentationValidForV2
                && sample.generationStable
                && sample.timingOrderValid
                && timestampOrderValid
                && sample.targetMatched
                && audibleComplete {
                fullyValidCount += 1
            }
        }

        if seekSamples.isEmpty {
            appendIssue(.init(sampleID: nil, kind: .missingSeekCoverage, detail: "seek coverage is required"))
        }
        if enabledLoopSamples.isEmpty {
            appendIssue(.init(sampleID: nil, kind: .missingEnabledLoopCoverage, detail: "enabled-loop coverage is required"))
        }
        if loopDisabledSamples.isEmpty {
            appendIssue(.init(sampleID: nil, kind: .missingLoopDisabledCoverage, detail: "loop-disable coverage is required"))
        }
        if !context.currentMoisesDifferentialObserved {
            appendIssue(.init(
                sampleID: nil,
                kind: .currentMoisesDifferentialMissing,
                detail: "current-Moises differential observation remains required"
            ))
        }
        if !context.humanListeningObserved {
            appendIssue(.init(
                sampleID: nil,
                kind: .humanListeningMissing,
                detail: "human listening observation remains required"
            ))
        }

        let shapeCoverageComplete = !seekSamples.isEmpty
            && !enabledLoopSamples.isEmpty
            && !loopDisabledSamples.isEmpty
        let physicalComplete = deviceContextValid
            && context.physicalIPhone
            && context.rightsClearedRealAudio
            && !samples.isEmpty
            && buffer.capacityDrops == 0
            && buffer.unusableInstrumentationResultCount == 0
            && duplicateCount == 0
            && invalidInstrumentationCount == 0
            && generationUnstableCount == 0
            && timingInvalidCount == 0
            && targetMismatchCount == 0
            && missingAudibleCount == 0
            && fullyValidCount == samples.count
            && shapeCoverageComplete

        let differentialComplete = physicalComplete
            && context.currentMoisesDifferentialObserved
            && context.humanListeningObserved

        return Lane3InteractiveContinuityV2PhysicalSessionReport(
            retainedSampleCount: samples.count,
            capacityDrops: buffer.capacityDrops,
            nonExecutedObservationCount: buffer.nonExecutedObservationCount,
            unusableInstrumentationResultCount: buffer.unusableInstrumentationResultCount,
            seekSampleCount: seekSamples.count,
            enabledLoopSampleCount: enabledLoopSamples.count,
            loopDisabledSampleCount: loopDisabledSamples.count,
            callerCancellationAfterDispatchCount: cancellationAfterDispatchCount,
            invalidInstrumentationSampleCount: invalidInstrumentationCount,
            generationUnstableSampleCount: generationUnstableCount,
            timingInvalidSampleCount: timingInvalidCount,
            targetMismatchSampleCount: targetMismatchCount,
            missingExternalAudibleMarkerCount: missingAudibleCount,
            fullyValidPhysicalSampleCount: fullyValidCount,
            duplicateSampleIDCount: duplicateCount,
            overallLatency: .init(samples: samples),
            seekLatency: .init(samples: seekSamples),
            enabledLoopLatency: .init(samples: enabledLoopSamples),
            loopDisabledLatency: .init(samples: loopDisabledSamples),
            issues: issues,
            issueDetailDrops: issueDetailDrops,
            physicalSessionComplete: physicalComplete,
            differentialListeningBundleComplete: differentialComplete
        )
    }
}
