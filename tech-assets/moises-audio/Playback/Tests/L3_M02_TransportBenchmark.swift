import Foundation
import Dispatch

@main
struct L3M02TransportBenchmark {
    static func main() throws {
        let clock = try PlaybackProjectFrameClock(sampleRate: 48_000)
        let project = ProjectID(rawValue: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)

        func stem(_ uuid: String, sampleRate: Double, start: Double, duration: Double) -> StemArtifact {
            StemArtifact(
                id: StemID(rawValue: UUID(uuidString: uuid)!),
                projectID: project,
                role: StemRole(rawValue: uuid),
                relativePath: "stems/\(uuid).wav",
                sampleRate: sampleRate,
                channels: 2,
                frameCount: Int64((duration * sampleRate).rounded()),
                startTimeSeconds: start
            )
        }

        let sixHours = 6.0 * 60 * 60
        let stems = [
            stem("10000000-0000-0000-0000-000000000011", sampleRate: 48_000, start: 0, duration: sixHours),
            stem("10000000-0000-0000-0000-000000000012", sampleRate: 44_100, start: 0.125, duration: sixHours - 0.125),
            stem("10000000-0000-0000-0000-000000000013", sampleRate: 96_000, start: 0.5, duration: sixHours - 0.5),
            stem("10000000-0000-0000-0000-000000000014", sampleRate: 48_000, start: 1.0, duration: sixHours - 1.0)
        ]

        let loopStart = try clock.frame(atSeconds: 18_000)
        let loopEnd = try clock.frame(atSeconds: 18_008)
        var samples: [Double] = []
        var checksum: Int64 = 0

        for round in 0..<25 {
            let start = DispatchTime.now().uptimeNanoseconds
            for i in 0..<250_000 {
                let raw = loopEnd + Int64(i) * (loopEnd - loopStart) + Int64(i % 383_999)
                checksum &+= try clock.normalizedFrame(raw, loopStartFrame: loopStart, loopEndFrame: loopEnd)
            }

            var state = PlaybackTransportMachineState(media: .source)
            state = try PlaybackTransportStateMachine.reduce(state, event: .play, clock: clock)
            for i in 0..<20_000 {
                let position = Double((i * 997) % Int(sixHours * 10)) / 10.0
                let plan = try PlaybackTransportSemantics.sourceToStemsTransition(
                    stems: stems,
                    currentPositionSeconds: position,
                    sourceDurationSeconds: sixHours,
                    wasPlaying: true
                )
                state = try PlaybackTransportStateMachine.reduce(
                    state,
                    event: .replaceSourceWithStems(plan),
                    clock: clock
                )
                if i % 2_000 == 0 {
                    state = try PlaybackTransportStateMachine.reduce(state, event: .interruptionBegan, clock: clock)
                    state = try PlaybackTransportStateMachine.reduce(
                        state,
                        event: .interruptionEnded(systemAllowsResume: true),
                        clock: clock
                    )
                }
                checksum &+= state.positionFrame
            }
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start) / 1_000_000.0)
            if round == 24 && checksum == 0 { fatalError("unreachable") }
        }

        let sorted = samples.sorted()
        func percentile(_ p: Double) -> Double {
            let index = min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))
            return sorted[index]
        }
        print(String(
            format: "L3-M02 benchmark: median=%.3fms p95=%.3fms p99=%.3fms max=%.3fms checksum=%lld",
            percentile(0.5), percentile(0.95), percentile(0.99), sorted.last!, checksum
        ))
    }
}
