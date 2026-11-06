import Foundation

@main
struct L3M02PortableTransportSelfTest {
    static func main() throws {
        let clock = try PlaybackProjectFrameClock(sampleRate: 48_000)

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() {
                fatalError("FAIL: \(message)")
            }
        }

        func stem(
            _ uuid: String,
            project: ProjectID,
            sampleRate: Double,
            start: Double,
            duration: Double
        ) -> StemArtifact {
            let frames = Int64((duration * sampleRate).rounded())
            return StemArtifact(
                id: StemID(rawValue: UUID(uuidString: uuid)!),
                projectID: project,
                role: StemRole(rawValue: uuid),
                relativePath: "stems/\(uuid).wav",
                sampleRate: sampleRate,
                channels: 2,
                frameCount: frames,
                startTimeSeconds: start
            )
        }

        let longSeconds = 72.0 * 60 * 60
        let longFrame = try clock.frame(atSeconds: longSeconds)
        expect(longFrame == 12_441_600_000, "72h frame mapping")
        let roundTripSeconds = try clock.seconds(forFrame: longFrame)
        expect(abs(roundTripSeconds - longSeconds) < 1e-9, "72h round trip")

        let loopStart: Int64 = 1_234_567
        let loopLength: Int64 = 7 * 48_000
        let loopEnd = loopStart + loopLength
        let offset: Int64 = 12_345
        let repeated = loopEnd + 1_000_000 * loopLength + offset
        let normalized = try clock.normalizedFrame(
            repeated,
            loopStartFrame: loopStart,
            loopEndFrame: loopEnd
        )
        expect(normalized == loopStart + offset, "million-loop normalization")

        let project = ProjectID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let normalStems = [
            stem("00000000-0000-0000-0000-000000000011", project: project, sampleRate: 48_000, start: 0, duration: 120),
            stem("00000000-0000-0000-0000-000000000012", project: project, sampleRate: 44_100, start: 0, duration: 120),
            stem("00000000-0000-0000-0000-000000000013", project: project, sampleRate: 48_000, start: 4, duration: 116)
        ]
        let preserved = try PlaybackTransportSemantics.sourceToStemsTransition(
            stems: normalStems,
            currentPositionSeconds: 31.25,
            sourceDurationSeconds: 120,
            wasPlaying: true
        )
        expect(preserved.state == .preservedClock, "source->stems preserved state")
        expect(abs(preserved.projectPositionSeconds - 31.25) < 1.0 / 48_000, "source->stems position")
        expect(preserved.resumePlayback, "source->stems play intent")
        expect(preserved.timeline.activeStemIDs.count == 3, "mixed-rate active stems")

        let delayedStems = [
            stem("00000000-0000-0000-0000-000000000021", project: project, sampleRate: 48_000, start: 10, duration: 100),
            stem("00000000-0000-0000-0000-000000000022", project: project, sampleRate: 44_100, start: 12, duration: 98)
        ]
        let delayed = try PlaybackTransportSemantics.sourceToStemsTransition(
            stems: delayedStems,
            currentPositionSeconds: 5,
            sourceDurationSeconds: 110,
            wasPlaying: true
        )
        expect(delayed.state == .waitingForDelayedStem, "delayed-stem transition")
        expect(delayed.resumePlayback, "delayed-stem preserves play intent")
        expect(delayed.timeline.delayedStemIDs.count == 2, "delayed stems classified")

        let shortStems = [
            stem("00000000-0000-0000-0000-000000000031", project: project, sampleRate: 48_000, start: 0, duration: 90),
            stem("00000000-0000-0000-0000-000000000032", project: project, sampleRate: 44_100, start: 0, duration: 88)
        ]
        let clamped = try PlaybackTransportSemantics.sourceToStemsTransition(
            stems: shortStems,
            currentPositionSeconds: 100,
            sourceDurationSeconds: 120,
            wasPlaying: true
        )
        expect(clamped.state == .clampedToStemEnd, "short-stem clamp state")
        expect(!clamped.resumePlayback, "short-stem clamp stops false playback")
        expect(abs(clamped.projectPositionSeconds - 90) < 1.0 / 48_000, "short-stem clamp position")
        expect(abs(clamped.sourceTailGapSeconds - 30) < 1.0 / 48_000, "source tail gap")

        let longerStems = [
            stem("00000000-0000-0000-0000-000000000041", project: project, sampleRate: 48_000, start: 0, duration: 121.5)
        ]
        let extended = try PlaybackTransportSemantics.sourceToStemsTransition(
            stems: longerStems,
            currentPositionSeconds: 100,
            sourceDurationSeconds: 120,
            wasPlaying: false
        )
        expect(abs(extended.stemsExtendPastSourceSeconds - 1.5) < 1.0 / 48_000, "stem extension accounting")

        var state = PlaybackTransportMachineState(media: .source)
        state = try PlaybackTransportStateMachine.reduce(state, event: .play, clock: clock)
        expect(state.intent == .playing, "play")
        state = try PlaybackTransportStateMachine.reduce(state, event: .interruptionBegan, clock: clock)
        expect(state.interrupted && state.intent == .paused && state.resumeAfterInterruption, "interruption begin")
        state = try PlaybackTransportStateMachine.reduce(state, event: .replaceSourceWithStems(preserved), clock: clock)
        expect(state.media == .stems && state.interrupted && state.resumeAfterInterruption, "swap during interruption")
        state = try PlaybackTransportStateMachine.reduce(state, event: .interruptionEnded(systemAllowsResume: true), clock: clock)
        expect(!state.interrupted && state.intent == .playing, "resume after interruption")

        state = try PlaybackTransportStateMachine.reduce(state, event: .interruptionBegan, clock: clock)
        state = try PlaybackTransportStateMachine.reduce(state, event: .pause, clock: clock)
        state = try PlaybackTransportStateMachine.reduce(state, event: .interruptionEnded(systemAllowsResume: true), clock: clock)
        expect(state.intent == .paused, "explicit pause cancels resume intent")

        let loop55 = try clock.frame(atSeconds: 55)
        let loop65 = try clock.frame(atSeconds: 65)
        let seek875 = try clock.frame(atSeconds: 87.5)
        state = try PlaybackTransportStateMachine.reduce(state, event: .setLoop(startFrame: loop55, endFrame: loop65), clock: clock)
        state = try PlaybackTransportStateMachine.reduce(state, event: .seek(frame: seek875), clock: clock)
        let expected575 = try clock.frame(atSeconds: 57.5)
        expect(state.positionFrame == expected575, "87.5s seek under 55...65 loop")

        var seed: UInt64 = 0x9E3779B97F4A7C15
        for _ in 0..<50_000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let loops = Int64(seed % 10_000_000)
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let localOffset = Int64(seed % UInt64(loopLength))
            let raw = loopEnd + loops * loopLength + localOffset
            let value = try clock.normalizedFrame(raw, loopStartFrame: loopStart, loopEndFrame: loopEnd)
            expect(value == loopStart + localOffset, "property loop normalization")
        }

        var sawOverflow = false
        do {
            _ = try clock.frame(atSeconds: Double.greatestFiniteMagnitude)
        } catch PlaybackTransportSemanticsError.timelineOverflow {
            sawOverflow = true
        }
        expect(sawOverflow, "overflow fails closed")

        var sawInvalidLoop = false
        do {
            _ = try clock.normalizedFrame(100, loopStartFrame: 500, loopEndFrame: 500)
        } catch PlaybackTransportSemanticsError.invalidFrameLoop {
            sawInvalidLoop = true
        }
        expect(sawInvalidLoop, "invalid loop fails closed")

        print("L3-M02 portable transport self-test: PASS")
    }
}
