import Foundation

private final class AW13BenchmarkBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private var tempo = 1.0
    private var pitch = 0.0

    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        tempo = tempoRatio
        pitch = pitchSemitones
    }

    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW13BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private var active: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        precondition(generation > active)
        active = generation
    }
}

@main
struct L3AW13UnifiedEvidenceV2Benchmark {
    static func main() async throws {
        let projectID = ProjectID()
        let controller = try PracticeDSPProductionController(
            projectID: projectID,
            backend: AW13BenchmarkBackend()
        )
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: projectID,
            controller: controller,
            clickInvalidator: AW13BenchmarkClickInvalidator()
        )
        let token = PlaybackTransportRescheduleToken(generation: 1, reason: .seek)
        let coordinatorReceipt = try await coordinator.bindTransportDiscontinuity(
            playbackToken: token
        )
        let production = try await Lane3ProductionGenerationEvidenceCapture.capture(
            coordinator: coordinator,
            receipt: coordinatorReceipt
        )
        let binding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: production.activePlaybackGeneration,
            clickGeneration: production.activeClickGeneration,
            reason: .seek
        )
        let lineage = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
            playbackToken: token,
            binding: binding,
            activeClickGeneration: production.activeClickGeneration
        )

        let frames = 16_384
        let reference = makePCM(frameCount: frames, phase: 0)
        let observed = makePCM(frameCount: frames, phase: 0.000_1)
        let offline = Lane3OfflineEvidenceReceipt(
            fixtureID: "aw13-benchmark",
            controlSignatureFNV1A64: "aw13-benchmark-controls",
            outputSampleRate: 48_000,
            plannedFrameCount: Int64(frames),
            renderedFrameCount: Int64(frames),
            clickEventCount: 4,
            actualAudioCaptured: true,
            outputFileWritten: true,
            eventEvidenceScope: "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION",
            componentParityPromotionAllowed: false
        )

        let rounds = 20
        let analysesPerRound = 2
        var timings: [Double] = []
        var checksum: UInt64 = 0
        for _ in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<analysesPerRound {
                let report = try Lane3UnifiedEvidencePipelineV2.analyze(
                    productionGeneration: production,
                    recoveryLineage: lineage,
                    offline: offline,
                    referencePCM: reference,
                    observedPCM: observed,
                    expectedEventFrames: [2_048, 4_096, 8_192, 12_288],
                    comparisonIntent: .peerSameControls
                )
                checksum &+= UInt64(report.runBindingFNV1A64.prefix(8), radix: 16) ?? 0
            }
            let end = DispatchTime.now().uptimeNanoseconds
            timings.append(Double(end - start) / 1_000_000)
        }
        let sorted = timings.sorted()
        let median = sorted[sorted.count / 2]
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        print(String(format: "L3-AW13 benchmark rounds=%d analyses_per_round=%d median_ms=%.3f p95_ms=%.3f max_ms=%.3f checksum=%llu", rounds, analysesPerRound, median, p95, sorted.last ?? 0, checksum))
    }

    private static func makePCM(frameCount: Int, phase: Double) -> Lane3PCMBufferDescriptor {
        var samples: [Float] = []
        samples.reserveCapacity(frameCount * 2)
        for frame in 0..<frameCount {
            let t = Double(frame) / 48_000 + phase
            let value = 0.35 * (
                0.55 * sin(2 * Double.pi * 220 * t)
                + 0.30 * sin(2 * Double.pi * 700 * t)
                + 0.20 * sin(2 * Double.pi * 1_300 * t)
                + 0.15 * sin(2 * Double.pi * 2_500 * t)
            )
            samples.append(Float(value))
            samples.append(Float(value * 0.97))
        }
        return Lane3PCMBufferDescriptor(
            interleavedSamples: samples,
            channels: 2,
            sampleRate: 48_000
        )
    }
}
