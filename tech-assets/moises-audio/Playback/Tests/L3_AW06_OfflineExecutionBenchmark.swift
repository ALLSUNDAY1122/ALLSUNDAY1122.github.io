import Foundation

@main
struct L3AW06OfflineExecutionBenchmark {
    static func main() throws {
        let request = Lane3ReferenceRenderRequest(
            fixtureID: "aw06-benchmark",
            stems: [
                Lane3ReferenceStemDescriptor(id: "vocals", startSeconds: 0, frameCount: 96_000, sampleRate: 48_000, gain: 0.8),
                Lane3ReferenceStemDescriptor(id: "drums", startSeconds: 0, frameCount: 96_000, sampleRate: 48_000, gain: 1)
            ],
            projectStartSeconds: 0,
            projectEndSeconds: 2,
            outputSampleRate: 48_000,
            practice: Lane3ReferencePracticeSettings(
                tempoRatio: 1,
                pitchSemitones: 2,
                metronomeEnabled: true,
                countInClicks: 2,
                downbeatStride: 4
            ),
            beatTimesSeconds: [0, 0.5, 1, 1.5],
            countInBeatIntervalSeconds: 0.5
        )
        let plan = try Lane3OfflineReferencePlanner.makePlan(request)
        let metadata = [
            Lane3OfflineStemFileMetadata(stemID: "vocals", sampleRate: 48_000, frameCount: 96_000, channels: 2),
            Lane3OfflineStemFileMetadata(stemID: "drums", sampleRate: 48_000, frameCount: 96_000, channels: 2)
        ]
        let click = Lane3OfflinePCMFormatDescriptor(sampleRate: 48_000, channels: 1)
        let rounds = 20
        let operations = 100_000
        var elapsed: [Double] = []
        var checksum = 0
        for _ in 0..<rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<operations {
                let manifest = try Lane3OfflineExecutionValidator.makeManifest(
                    request: request,
                    plan: plan,
                    stemMetadata: metadata,
                    clickPCMFormat: click
                )
                checksum &+= manifest.renderWindowCount + manifest.clickEventCount
            }
            let end = DispatchTime.now().uptimeNanoseconds
            elapsed.append(Double(end - start) / 1_000_000)
        }
        elapsed.sort()
        let median = (elapsed[9] + elapsed[10]) / 2
        let p95 = elapsed[18]
        let maxValue = elapsed[19]
        print(String(format: "median %.3f ms p95 %.3f ms p99/max %.3f ms checksum %d", median, p95, maxValue, checksum))
    }
}
