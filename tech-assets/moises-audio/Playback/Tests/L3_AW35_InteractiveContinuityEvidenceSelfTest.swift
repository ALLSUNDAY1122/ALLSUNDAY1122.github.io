import Foundation

@main
struct L3AW35InteractiveContinuityEvidenceSelfTest {
    static func main() {
        let context = Lane3InteractiveContinuityDeviceContext(
            physicalIPhone: true,
            hardwareIdentifier: "test-device",
            osVersion: "test-os",
            appBuildIdentifier: "aw35",
            sampleRate: 48_000,
            rightsClearedRealAudio: true,
            currentMoisesDifferentialObserved: false,
            humanListeningObserved: false
        )
        var buffer = Lane3InteractiveContinuityEvidenceBuffer(capacity: 64)
        for index in 0..<50 {
            let start = UInt64(index) * 10_000_000
            let target = Double(index) * 0.125
            buffer.append(.init(
                sampleID: UInt64(index + 1), operation: .seek, outcome: .executed,
                slotGenerationAtIntent: 7, slotGenerationAtCompletion: 7,
                transportTicket: UInt64(index + 100), playbackGeneration: UInt64(index + 200),
                firstIntentUptimeNanoseconds: start,
                tokenIssuedUptimeNanoseconds: start + UInt64(1_000_000 + index * 20_000),
                audibleResultUptimeNanoseconds: start + UInt64(6_000_000 + index * 40_000),
                requestedTarget: .seek(positionSeconds: target),
                appliedTarget: .seek(positionSeconds: target + 0.004),
                callerCancellationObservedAfterDispatch: false
            ))
        }
        buffer.append(.init(
            sampleID: 51, operation: .loop, outcome: .staleGenerationRejected,
            slotGenerationAtIntent: 7, slotGenerationAtCompletion: 8,
            transportTicket: nil, playbackGeneration: nil,
            firstIntentUptimeNanoseconds: 600_000_000,
            tokenIssuedUptimeNanoseconds: nil, audibleResultUptimeNanoseconds: nil,
            requestedTarget: .loop(startSeconds: 12, endSeconds: 16), appliedTarget: nil,
            callerCancellationObservedAfterDispatch: false
        ))
        let report = Lane3InteractiveContinuityEvidenceAnalyzer.analyze(context: context, buffer: buffer)
        precondition(report.retainedObservationCount == 51)
        precondition(report.executedObservationCount == 50)
        precondition(report.staleGenerationRejectionCount == 1)
        precondition(report.issues.isEmpty)
        precondition(report.firstIntentToToken.p95Nanoseconds == 1_940_000)
        precondition(report.firstIntentToToken.p99Nanoseconds == 1_980_000)
        precondition(report.physicalDeviceMeasurementComplete)
        precondition(!report.differentialListeningBundleComplete)
        precondition(!report.parityPromotionAllowed)

        var bounded = Lane3InteractiveContinuityEvidenceBuffer(capacity: 16)
        for index in 0..<100 {
            bounded.append(.init(
                sampleID: UInt64(index), operation: .seek, outcome: .cancelledBeforeDispatch,
                slotGenerationAtIntent: 1, slotGenerationAtCompletion: 1,
                transportTicket: nil, playbackGeneration: nil,
                firstIntentUptimeNanoseconds: UInt64(index),
                tokenIssuedUptimeNanoseconds: nil, audibleResultUptimeNanoseconds: nil,
                requestedTarget: .seek(positionSeconds: Double(index)), appliedTarget: nil,
                callerCancellationObservedAfterDispatch: false
            ))
        }
        precondition(bounded.retainedCount == 16)
        precondition(bounded.capacityDrops == 84)
        precondition(bounded.orderedObservations().first?.sampleID == 84)

        var bad = Lane3InteractiveContinuityEvidenceBuffer(capacity: 16)
        bad.append(.init(
            sampleID: 1, operation: .loop, outcome: .executed,
            slotGenerationAtIntent: 10, slotGenerationAtCompletion: 11,
            transportTicket: 1, playbackGeneration: 1,
            firstIntentUptimeNanoseconds: 1_000,
            tokenIssuedUptimeNanoseconds: 900, audibleResultUptimeNanoseconds: 800,
            requestedTarget: .loop(startSeconds: 2, endSeconds: 4),
            appliedTarget: .seek(positionSeconds: 3),
            callerCancellationObservedAfterDispatch: false
        ))
        let badKinds = Set(Lane3InteractiveContinuityEvidenceAnalyzer.analyze(context: context, buffer: bad).issues.map(\.kind))
        precondition(badKinds.contains(.executedAcrossSlotGeneration))
        precondition(badKinds.contains(.tokenBeforeIntent))
        precondition(badKinds.contains(.audibleBeforeToken))
        precondition(badKinds.contains(.targetShapeMismatch))
        print("L3-AW35 continuity evidence PASS")
    }
}
