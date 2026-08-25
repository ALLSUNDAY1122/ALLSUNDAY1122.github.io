import Foundation

private func makeAW40Context(
    moises: Bool = true,
    listening: Bool = true
) -> Lane3InteractiveContinuityV2PhysicalSessionContext {
    .init(
        sessionIdentifier: "aw40-session",
        physicalIPhone: true,
        hardwareIdentifier: "iPhone-test-hardware",
        osVersion: "iOS-test",
        appBuildIdentifier: "build-test",
        sampleRate: 48_000,
        uptimeClockDomain: "system-uptime-nanoseconds",
        audioFixtureIdentifier: "rights-cleared-fixture-hash",
        rightsClearedRealAudio: true,
        currentMoisesDifferentialObserved: moises,
        humanListeningObserved: listening
    )
}

private func makeAW40Sample(
    id: UInt64,
    shape: Lane3InteractiveContinuityV2OperationShape,
    base: UInt64,
    audible: Bool = true,
    valid: Bool = true
) -> Lane3InteractiveContinuityV2SessionSample {
    .init(
        sampleID: id,
        shape: shape,
        firstIntentUptimeNanoseconds: base,
        tokenIssuedUptimeNanoseconds: base + 10,
        backendCompletedUptimeNanoseconds: base + 20,
        audibleResultUptimeNanoseconds: audible ? base + 40 : nil,
        audibleTimestampSource: audible ? "external-audio-observer" : nil,
        callerCancellationObservedAfterDispatch: id == 2,
        instrumentationValidForV2: valid,
        generationStable: valid,
        timingOrderValid: valid,
        targetMatched: valid,
        externalAudibleMarkerValid: audible && valid
    )
}

@main
struct L3AW40InteractiveContinuityV2PhysicalSessionSelfTest {
    static func main() {
        var buffer = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 64)
        buffer.append(makeAW40Sample(id: 1, shape: .seek, base: 100))
        buffer.append(makeAW40Sample(id: 2, shape: .loopEnabled, base: 200))
        buffer.append(makeAW40Sample(id: 3, shape: .loopDisabled, base: 300))
        buffer.noteNonExecutedObservation()

        let report = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(),
            buffer: buffer
        )
        precondition(report.retainedSampleCount == 3)
        precondition(report.nonExecutedObservationCount == 1)
        precondition(report.seekSampleCount == 1)
        precondition(report.enabledLoopSampleCount == 1)
        precondition(report.loopDisabledSampleCount == 1)
        precondition(report.callerCancellationAfterDispatchCount == 1)
        precondition(report.overallLatency.firstIntentToToken.count == 3)
        precondition(report.overallLatency.firstIntentToToken.p50Nanoseconds == 10)
        precondition(report.overallLatency.firstIntentToAudibleResult.p95Nanoseconds == 40)
        precondition(report.physicalSessionComplete)
        precondition(report.differentialListeningBundleComplete)
        precondition(!report.parityPromotionAllowed)

        let differentialMissing = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(moises: false, listening: false),
            buffer: buffer
        )
        precondition(differentialMissing.physicalSessionComplete)
        precondition(!differentialMissing.differentialListeningBundleComplete)

        var missingAudible = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 16)
        missingAudible.append(makeAW40Sample(id: 10, shape: .seek, base: 1_000, audible: false))
        missingAudible.append(makeAW40Sample(id: 11, shape: .loopEnabled, base: 2_000))
        missingAudible.append(makeAW40Sample(id: 12, shape: .loopDisabled, base: 3_000))
        let missingAudibleReport = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(),
            buffer: missingAudible
        )
        precondition(!missingAudibleReport.physicalSessionComplete)
        precondition(missingAudibleReport.missingExternalAudibleMarkerCount == 1)

        var dropped = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 1)
        precondition(dropped.capacity == 16)
        for index in 0..<20 {
            let shape: Lane3InteractiveContinuityV2OperationShape
            switch index % 3 {
            case 0: shape = .seek
            case 1: shape = .loopEnabled
            default: shape = .loopDisabled
            }
            dropped.append(makeAW40Sample(id: UInt64(index), shape: shape, base: UInt64(index * 100)))
        }
        let droppedReport = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(),
            buffer: dropped
        )
        precondition(dropped.retainedCount == 16)
        precondition(dropped.capacityDrops == 4)
        precondition(!droppedReport.physicalSessionComplete)

        var unusable = buffer
        unusable.noteUnusableInstrumentationResult()
        let unusableReport = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(),
            buffer: unusable
        )
        precondition(!unusableReport.physicalSessionComplete)
        precondition(unusableReport.unusableInstrumentationResultCount == 1)

        var duplicate = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 16)
        duplicate.append(makeAW40Sample(id: 50, shape: .seek, base: 5_000))
        duplicate.append(makeAW40Sample(id: 50, shape: .loopEnabled, base: 6_000))
        duplicate.append(makeAW40Sample(id: 51, shape: .loopDisabled, base: 7_000))
        let duplicateReport = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: makeAW40Context(),
            buffer: duplicate
        )
        precondition(duplicateReport.duplicateSampleIDCount == 1)
        precondition(!duplicateReport.physicalSessionComplete)

        print(
            "L3-AW40 v2 session PASS retained=\(report.retainedSampleCount) "
                + "nonExecuted=\(report.nonExecutedObservationCount) drops=\(dropped.capacityDrops)"
        )
    }
}
