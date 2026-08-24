import Foundation

@main
struct L3AW31TempoBoundaryClockSelfTest {
    static func main() throws {
        let twice = try PlaybackTempoClockMath.projectPosition(
            anchorProjectSeconds: 10,
            elapsedHostSeconds: 1.5,
            tempoRatio: 2,
            durationSeconds: 30,
            loop: nil
        )
        precondition(abs(twice - 13) < 1e-12)

        let half = try PlaybackTempoClockMath.projectPosition(
            anchorProjectSeconds: 10,
            elapsedHostSeconds: 2,
            tempoRatio: 0.5,
            durationSeconds: 30,
            loop: nil
        )
        precondition(abs(half - 11) < 1e-12)

        let loop = PlaybackLoopRange(startSeconds: 10, endSeconds: 14)
        let wrapped = try PlaybackTempoClockMath.projectPosition(
            anchorProjectSeconds: 13,
            elapsedHostSeconds: 1,
            tempoRatio: 2,
            durationSeconds: 30,
            loop: loop
        )
        precondition(abs(wrapped - 11) < 1e-12)

        let twiceHost = try PlaybackTempoClockMath.hostDuration(
            forProjectDuration: 8,
            tempoRatio: 2
        )
        let halfHost = try PlaybackTempoClockMath.hostDuration(
            forProjectDuration: 8,
            tempoRatio: 0.5
        )
        precondition(abs(twiceHost - 4) < 1e-12)
        precondition(abs(halfHost - 16) < 1e-12)

        let receipt = PlaybackTempoBoundaryReceipt(
            serial: 7,
            fromTempoRatio: 1,
            toTempoRatio: 1.25,
            capturedProjectPositionSeconds: 12,
            loop: loop,
            resumeWasPlaying: true,
            backendScheduleGeneration: 42
        )
        precondition(receipt.schemaVersion == 1)
        precondition(receipt.evidenceScope == "LANE3_AW31_TEMPO_BOUNDARY_NON_PARITY")
        precondition(!receipt.parityPromotionAllowed)

        for invalid in [0.0, -1.0, Double.nan, Double.infinity] {
            do {
                _ = try PlaybackTempoClockMath.hostDuration(
                    forProjectDuration: 1,
                    tempoRatio: invalid
                )
                preconditionFailure("invalid tempo accepted")
            } catch PlaybackTempoBoundaryError.invalidClockInput {
                // expected
            }
        }

        do {
            _ = try PlaybackTempoClockMath.projectPosition(
                anchorProjectSeconds: 0,
                elapsedHostSeconds: .nan,
                tempoRatio: 1,
                durationSeconds: nil,
                loop: nil
            )
            preconditionFailure("non-finite elapsed host time accepted")
        } catch PlaybackTempoBoundaryError.invalidClockInput {
            // expected
        }

        print("L3-AW31 clock PASS twice=\(twice) half=\(half) wrapped=\(wrapped)")
    }
}
