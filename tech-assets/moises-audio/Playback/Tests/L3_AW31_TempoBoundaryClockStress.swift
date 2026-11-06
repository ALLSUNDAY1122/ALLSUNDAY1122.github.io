import Foundation

@main
struct L3AW31TempoBoundaryClockStress {
    static func main() throws {
        var checksum = 0.0
        for index in 0..<1_000_000 {
            let ratio = 0.5 + Double(index % 151) / 100.0
            checksum += try PlaybackTempoClockMath.projectPosition(
                anchorProjectSeconds: Double(index % 11),
                elapsedHostSeconds: 0.001 * Double(index % 100),
                tempoRatio: ratio,
                durationSeconds: 600,
                loop: nil
            )
        }
        precondition(checksum.isFinite)
        print(String(
            format: "L3-AW31 clock stress PASS cycles=1000000 checksum=%.6f",
            checksum
        ))
    }
}
