import Foundation

@main
struct L3AW35InteractiveContinuityEvidenceStress {
    static func main() {
        let total = 1_000_000
        var buffer = Lane3InteractiveContinuityEvidenceBuffer(capacity: 4_096)
        for index in 0..<total {
            let generation = UInt64(index / 1_000 + 1)
            let base = UInt64(index) * 10_000
            if index.isMultiple(of: 1_000), index > 0 {
                buffer.append(.init(
                    sampleID: UInt64(index), operation: .loop, outcome: .staleGenerationRejected,
                    slotGenerationAtIntent: generation - 1, slotGenerationAtCompletion: generation,
                    transportTicket: nil, playbackGeneration: nil,
                    firstIntentUptimeNanoseconds: base,
                    tokenIssuedUptimeNanoseconds: nil, audibleResultUptimeNanoseconds: nil,
                    requestedTarget: .loop(startSeconds: 10, endSeconds: 12), appliedTarget: nil,
                    callerCancellationObservedAfterDispatch: false
                ))
            } else {
                let position = Double(index % 50_000) / 100
                buffer.append(.init(
                    sampleID: UInt64(index), operation: .seek, outcome: .executed,
                    slotGenerationAtIntent: generation, slotGenerationAtCompletion: generation,
                    transportTicket: UInt64(index), playbackGeneration: UInt64(index + 10),
                    firstIntentUptimeNanoseconds: base,
                    tokenIssuedUptimeNanoseconds: base + 2_000_000,
                    audibleResultUptimeNanoseconds: base + 8_000_000,
                    requestedTarget: .seek(positionSeconds: position),
                    appliedTarget: .seek(positionSeconds: position + 0.001),
                    callerCancellationObservedAfterDispatch: false
                ))
            }
        }
        let context = Lane3InteractiveContinuityDeviceContext(
            physicalIPhone: false,
            hardwareIdentifier: "portable-stress",
            osVersion: "linux",
            appBuildIdentifier: "aw35-stress",
            sampleRate: 48_000,
            rightsClearedRealAudio: false,
            currentMoisesDifferentialObserved: false,
            humanListeningObserved: false
        )
        let report = Lane3InteractiveContinuityEvidenceAnalyzer.analyze(context: context, buffer: buffer)
        precondition(buffer.retainedCount == 4_096)
        precondition(buffer.capacityDrops == 995_904)
        precondition(report.issues.isEmpty)
        precondition(report.executedObservationCount > 4_000)
        precondition(report.staleGenerationRejectionCount >= 4)
        precondition(report.firstIntentToToken.p99Nanoseconds == 2_000_000)
        precondition(report.firstIntentToAudibleResult.p99Nanoseconds == 8_000_000)
        precondition(!report.physicalDeviceMeasurementComplete)
        precondition(!report.parityPromotionAllowed)
        print("L3-AW35 stress PASS total=\(total) retained=\(buffer.retainedCount) drops=\(buffer.capacityDrops)")
    }
}
