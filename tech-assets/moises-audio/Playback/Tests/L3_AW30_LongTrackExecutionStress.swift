import Foundation

private struct AW30StressSource: Lane3PCMChunkReadable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 4_096

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        [Float](repeating: 0, count: frameCount * channels)
    }
}

@main
struct L3AW30LongTrackExecutionStress {
    static func main() throws {
        let cycles = 50_000
        var cancelled = 0
        var completed = 0
        var completionRejected = 0
        var checksum: UInt64 = 0
        let phases: [Lane3LongTrackEvidenceExecutionPhase] = [
            .timeDomain,
            .spectral,
            .envelope,
            .assemblingCore,
            .pcmIdentity,
            .finalizing
        ]

        for index in 0..<cycles {
            let controller = Lane3LongTrackEvidenceExecutionController()
            let source = Lane3CancellationAwarePCMChunkSource(
                base: AW30StressSource(),
                role: .reference,
                controller: controller
            )
            let cancelAt = index % 8
            var didCancel = false

            for (phaseIndex, phase) in phases.enumerated() {
                try controller.begin(phase)
                if phaseIndex < 5 {
                    _ = try source.readInterleavedFrames(
                        startFrame: Int64(phaseIndex * 8),
                        frameCount: 8
                    )
                }
                if phaseIndex == cancelAt {
                    controller.requestCancellation()
                    do {
                        try controller.throwIfCancellationRequested()
                        preconditionFailure("cancelled execution continued")
                    } catch Lane3LongTrackEvidenceExecutionError.cancelled {
                        didCancel = true
                        cancelled += 1
                    }
                    break
                }
            }

            if didCancel {
                do {
                    _ = try controller.completionReceipt()
                    preconditionFailure("cancelled execution produced completion")
                } catch Lane3LongTrackEvidenceExecutionError.completionUnavailable {
                    completionRejected += 1
                }
            } else {
                try controller.markCompleted(
                    runBindingSHA256: String(repeating: "b", count: 64)
                )
                let receipt = try controller.completionReceipt()
                completed += 1
                checksum &+= receipt.referenceReadCalls
            }

            let checkpoint = controller.checkpoint()
            precondition(!checkpoint.authoritativeEvidenceAllowed)
            checksum &+= checkpoint.checkpointSerial
        }

        print(
            "L3-AW30 stress PASS cycles=\(cycles) "
                + "cancelled=\(cancelled) completed=\(completed) "
                + "completionRejected=\(completionRejected) checksum=\(checksum)"
        )
    }
}
