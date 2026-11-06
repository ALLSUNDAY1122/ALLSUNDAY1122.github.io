import Foundation

@main
struct L3AW40InteractiveContinuityV2PhysicalSessionStress {
    static func main() {
        let total = 1_000_000
        var buffer = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 4_096)
        for index in 0..<total {
            let shape: Lane3InteractiveContinuityV2OperationShape
            switch index % 3 {
            case 0: shape = .seek
            case 1: shape = .loopEnabled
            default: shape = .loopDisabled
            }
            let base = UInt64(index) * 100
            buffer.append(.init(
                sampleID: UInt64(index),
                shape: shape,
                firstIntentUptimeNanoseconds: base,
                tokenIssuedUptimeNanoseconds: base + 10,
                backendCompletedUptimeNanoseconds: base + 20,
                audibleResultUptimeNanoseconds: base + 40,
                audibleTimestampSource: "external",
                callerCancellationObservedAfterDispatch: false,
                instrumentationValidForV2: true,
                generationStable: true,
                timingOrderValid: true,
                targetMatched: true,
                externalAudibleMarkerValid: true
            ))
        }

        let context = Lane3InteractiveContinuityV2PhysicalSessionContext(
            sessionIdentifier: "stress",
            physicalIPhone: true,
            hardwareIdentifier: "stress-device",
            osVersion: "stress-os",
            appBuildIdentifier: "stress-build",
            sampleRate: 48_000,
            uptimeClockDomain: "uptime-ns",
            audioFixtureIdentifier: "fixture-hash",
            rightsClearedRealAudio: true,
            currentMoisesDifferentialObserved: false,
            humanListeningObserved: false
        )
        let report = Lane3InteractiveContinuityV2PhysicalSessionAnalyzer.analyze(
            context: context,
            buffer: buffer
        )
        precondition(report.retainedSampleCount == 4_096)
        precondition(report.capacityDrops == UInt64(total - 4_096))
        precondition(report.duplicateSampleIDCount == 0)
        precondition(report.fullyValidPhysicalSampleCount == 4_096)
        precondition(report.seekSampleCount + report.enabledLoopSampleCount + report.loopDisabledSampleCount == 4_096)
        precondition(!report.physicalSessionComplete)
        precondition(!report.parityPromotionAllowed)

        print(
            "L3-AW40 stress PASS total=\(total) retained=\(report.retainedSampleCount) "
                + "drops=\(report.capacityDrops) issueDrops=\(report.issueDetailDrops)"
        )
    }
}
