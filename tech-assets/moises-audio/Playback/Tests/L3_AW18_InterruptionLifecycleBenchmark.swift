import Foundation

private actor AW18BenchmarkPlaybackBackend: PlaybackBackendDriving {
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW18BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0
    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        tempo = tempoRatio
        pitch = pitchSemitones
    }
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW18BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW18InterruptionLifecycleBenchmark {
    static func main() async throws {
        let rounds = 20
        let cyclesPerRound = 2_000
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var checksum = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let playback = RescheduleFencedPlaybackBackend(backend: AW18BenchmarkPlaybackBackend())
            let controller = try PracticeDSPProductionController(projectID: project, backend: AW18BenchmarkDSPBackend())
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW18BenchmarkClickInvalidator()
            )
            let authority = Lane3UnifiedProductionTransportAuthority(
                projectID: project,
                playback: playback,
                coordinator: coordinator,
                policy: Lane3UnifiedTransportPolicy(
                    seekQuietPeriod: .milliseconds(1),
                    loopQuietPeriod: .milliseconds(1),
                    tempoQuietPeriod: .milliseconds(1)
                )
            )
            let gate = Lane3InterruptionLifecycleGate(authority: authority)
            _ = await gate.submitPlay()

            let start = clock.now
            var resumed = 0
            var blocked = 0
            for index in 0..<cyclesPerRound {
                _ = await gate.submitInterruptionBegan()
                if case .rejectedBeforeTransport = await gate.submitSeek(
                    to: Double(index), resume: true, loop: nil
                ) {
                    blocked += 1
                }
                if index % 4 == 0 { _ = await gate.submitPause() }
                if case let .ended(receipt) = await gate.submitInterruptionEnded(shouldResume: true),
                   receipt.resumedPlayback {
                    resumed += 1
                }
                if index % 4 == 0 { _ = await gate.submitPlay() }
            }
            let duration = start.duration(to: clock.now).components
            milliseconds.append(
                Double(duration.seconds) * 1_000
                    + Double(duration.attoseconds) / 1_000_000_000_000_000
            )
            let token = await playback.rescheduleTokenSnapshot(projectID: project)
            checksum += resumed + blocked + Int(token?.generation ?? 0) + round
        }

        milliseconds.sort()
        func percentile(_ fraction: Double) -> Double {
            let index = Int((Double(milliseconds.count - 1) * fraction).rounded())
            return milliseconds[index]
        }
        print(String(format:
            "L3-AW18 lifecycle benchmark 20x2000 median %.3fms p95 %.3fms max %.3fms checksum %d",
            percentile(0.50), percentile(0.95), milliseconds.last!, checksum
        ))
    }
}
