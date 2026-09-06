import Foundation

private actor AW17BenchmarkPlaybackBackend: PlaybackBackendDriving {
    private var seekCount = 0
    func count() -> Int { seekCount }
    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(projectID: ProjectID, stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws {}
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(projectID: ProjectID, to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async throws { seekCount += 1 }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {}
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { 0 }
}

private final class AW17BenchmarkDSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW17BenchmarkClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    func invalidateSchedule(to generation: UInt64) throws {}
}

@main
struct L3AW17UnifiedTransportAuthorityBenchmark {
    static func main() async throws {
        let rounds = 20
        let seekBurst = 2_000
        let discretePerRound = 200
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var checksum = 0

        for round in 0..<rounds {
            let project = ProjectID()
            let rawPlayback = AW17BenchmarkPlaybackBackend()
            let playback = RescheduleFencedPlaybackBackend(backend: rawPlayback)
            let controller = try PracticeDSPProductionController(
                projectID: project,
                backend: AW17BenchmarkDSPBackend()
            )
            let coordinator = PracticeDSPGenerationCoordinator(
                projectID: project,
                controller: controller,
                clickInvalidator: AW17BenchmarkClickInvalidator()
            )
            let authority = Lane3UnifiedProductionTransportAuthority(
                projectID: project,
                playback: playback,
                coordinator: coordinator,
                policy: Lane3UnifiedTransportPolicy(
                    seekQuietPeriod: .milliseconds(2),
                    loopQuietPeriod: .milliseconds(2),
                    tempoQuietPeriod: .milliseconds(2)
                )
            )

            let start = clock.now
            var executedSeek = 0
            var superseded = 0
            await withTaskGroup(of: Lane3UnifiedTransportOutcome.self) { group in
                for index in 0..<seekBurst {
                    group.addTask {
                        await authority.submitSeek(to: Double(index), resume: true, loop: nil)
                    }
                }
                for await result in group {
                    switch result {
                    case .executed: executedSeek += 1
                    case .supersededBeforeToken: superseded += 1
                    default: preconditionFailure("benchmark seek burst failed")
                    }
                }
            }

            var executedDiscrete = 0
            for index in 0..<discretePerRound {
                let outcome = index.isMultiple(of: 2)
                    ? await authority.submitPlay()
                    : await authority.submitPause()
                guard case .executed = outcome else {
                    preconditionFailure("benchmark discrete operation failed")
                }
                executedDiscrete += 1
            }

            let elapsed = start.duration(to: clock.now).components
            let ms = Double(elapsed.seconds) * 1_000
                + Double(elapsed.attoseconds) / 1_000_000_000_000_000
            milliseconds.append(ms)

            let backendSeeks = await rawPlayback.count()
            let token = await playback.rescheduleTokenSnapshot(projectID: project)
            let totalExecuted = executedSeek + executedDiscrete
            precondition(executedSeek >= 1)
            precondition(executedSeek + superseded == seekBurst)
            precondition(backendSeeks == executedSeek)
            precondition(executedDiscrete == discretePerRound)
            precondition(token?.generation == UInt64(totalExecuted))
            checksum += totalExecuted * 31 + superseded + Int(token?.generation ?? 0) + round
        }

        milliseconds.sort()
        func percentile(_ fraction: Double) -> Double {
            let index = min(
                milliseconds.count - 1,
                Int((Double(milliseconds.count - 1) * fraction).rounded())
            )
            return milliseconds[index]
        }

        print(String(format:
            "L3-AW17 unified authority benchmark fixed-window 20x(2000 seek + 200 discrete) median %.3fms p95 %.3fms max %.3fms checksum %d",
            percentile(0.50), percentile(0.95), milliseconds.last!, checksum
        ))
    }
}
