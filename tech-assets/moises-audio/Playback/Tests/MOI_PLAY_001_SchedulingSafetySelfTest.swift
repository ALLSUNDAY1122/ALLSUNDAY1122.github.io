import Foundation

@main
struct MOIPLAY001SchedulingSafetySelfTest {
    static func main() throws {
        try testLatestEndingStemUsesTimeNotFrames()
        try testDelayedStartCanBecomeLeader()
        try testSeekNormalizationInsideLoop()
        try testSeekValidation()
        print("MOI-PLAY-001 scheduling safety self-test: PASS")
    }

    static func testLatestEndingStemUsesTimeNotFrames() throws {
        let a = StemID()
        let b = StemID()
        let leader = try PlaybackSchedulingSafety.latestEndingStemID(windows: [
            PlaybackScheduledTrackWindow(
                stemID: a,
                delayedStartSeconds: 0,
                frameCount: 48_000,
                sampleRate: 48_000
            ),
            PlaybackScheduledTrackWindow(
                stemID: b,
                delayedStartSeconds: 0,
                frameCount: 44_200,
                sampleRate: 44_100
            )
        ])
        precondition(leader == b)
    }

    static func testDelayedStartCanBecomeLeader() throws {
        let early = StemID()
        let delayed = StemID()
        let leader = try PlaybackSchedulingSafety.latestEndingStemID(windows: [
            PlaybackScheduledTrackWindow(
                stemID: early,
                delayedStartSeconds: 0,
                frameCount: 96_000,
                sampleRate: 48_000
            ),
            PlaybackScheduledTrackWindow(
                stemID: delayed,
                delayedStartSeconds: 1.25,
                frameCount: 48_000,
                sampleRate: 48_000
            )
        ])
        precondition(leader == delayed)
    }

    static func testSeekNormalizationInsideLoop() throws {
        let loop = PlaybackLoopRange(startSeconds: 10, endSeconds: 20)
        let before = try PlaybackSchedulingSafety.normalizedSeekPosition(
            requestedSeconds: 7,
            durationSeconds: 120,
            loop: loop
        )
        precondition(before == 7)

        let atEnd = try PlaybackSchedulingSafety.normalizedSeekPosition(
            requestedSeconds: 20,
            durationSeconds: 120,
            loop: loop
        )
        precondition(atEnd == 10)

        let repeated = try PlaybackSchedulingSafety.normalizedSeekPosition(
            requestedSeconds: 47.5,
            durationSeconds: 120,
            loop: loop
        )
        precondition(abs(repeated - 17.5) < 1e-12)
    }

    static func testSeekValidation() throws {
        do {
            _ = try PlaybackSchedulingSafety.normalizedSeekPosition(
                requestedSeconds: 121,
                durationSeconds: 120,
                loop: nil
            )
            preconditionFailure("out-of-duration seek should fail")
        } catch PlaybackControlError.invalidSeek {
        }

        do {
            _ = try PlaybackSchedulingSafety.normalizedSeekPosition(
                requestedSeconds: 1,
                durationSeconds: 5,
                loop: PlaybackLoopRange(startSeconds: 2, endSeconds: 6)
            )
            preconditionFailure("loop beyond duration should fail")
        } catch PlaybackControlError.invalidLoop {
        }
    }
}
