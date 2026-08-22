import Foundation

@main
struct MOIPLAY001LongTrackBenchmark {
    static func main() throws {
        let project = ProjectID()
        let sampleRate = 48_000.0
        let durationSeconds = 3.0 * 60 * 60
        let roles = [
            StemRole(rawValue: "vocals"),
            StemRole(rawValue: "drums"),
            StemRole(rawValue: "bass"),
            StemRole(rawValue: "other")
        ]
        let stems = roles.map { role in
            StemArtifact(
                id: StemID(),
                projectID: project,
                role: role,
                relativePath: role.rawValue + ".wav",
                sampleRate: sampleRate,
                channels: 2,
                frameCount: Int64(durationSeconds * sampleRate),
                startTimeSeconds: 0
            )
        }
        let mixes = stems.map {
            PlaybackTrackMix(
                stemID: $0.id,
                role: $0.role,
                volume: 0.83
            )
        }

        let iterations = 20_000
        var samples: [Double] = []
        samples.reserveCapacity(iterations)
        var checksum: Int64 = 0

        for index in 0..<iterations {
            let seekSeconds = Double(
                (index * 7_919) % Int(durationSeconds * 1_000)
            ) / 1_000.0
            let start = DispatchTime.now().uptimeNanoseconds

            for stem in stems {
                checksum &+= try PlaybackTimelinePlanner.planStem(
                    stem,
                    projectPositionSeconds: seekSeconds
                ).sourceStartFrame
            }
            checksum &+= Int64(
                (
                    PlaybackTimelinePlanner
                        .effectiveGains(for: mixes)
                        .values
                        .reduce(0, +) * 1_000
                ).rounded()
            )

            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(
                Double(end - start) / 1_000_000.0
            )
        }

        samples.sort()
        func percentile(_ p: Double) -> Double {
            samples[min(
                samples.count - 1,
                Int(Double(samples.count - 1) * p)
            )]
        }

        print(String(
            format: "iterations=%d four_stem_3h_seek_plan median_ms=%.6f p95_ms=%.6f p99_ms=%.6f max_ms=%.6f checksum=%lld",
            iterations,
            percentile(0.50),
            percentile(0.95),
            percentile(0.99),
            samples.last ?? 0,
            checksum
        ))
    }
}
