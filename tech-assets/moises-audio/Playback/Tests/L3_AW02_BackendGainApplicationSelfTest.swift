import Foundation

@main
enum L3AW02BackendGainApplicationSelfTest {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { fatalError(message) }
        }
        func stem(_ suffix: String) -> StemID {
            StemID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!)
        }

        let a = stem("000000000001")
        let b = stem("000000000002")
        let c = stem("000000000003")

        let ramped = try PlaybackBackendGainApplicationPlanner.plan(
            loadedStemIDs: [b, a],
            committedGains: [a: 0.2, b: 0.4, c: 0.9],
            requestedGains: [a: 0.8],
            renderSampleRates: [a: 48_000, b: 44_100],
            isPlaying: true
        )
        check(ramped.mode == .ramped, "playing transport must ramp")
        check(ramped.normalizedTargetGains[a] == 0.8, "explicit target lost")
        check(ramped.normalizedTargetGains[b] == 1.0, "omitted target must normalize to unity")
        check(ramped.execution.steps.map(\.stemID) == [a, b], "step order must be deterministic")
        check(ramped.execution.steps[0].frameCount == 576, "48k ramp must be 576 frames")
        check(ramped.execution.steps[1].frameCount == 529, "44.1k ramp must be 529 frames")

        let immediate = try PlaybackBackendGainApplicationPlanner.plan(
            loadedStemIDs: [a, b],
            committedGains: [a: 0.8, b: 1],
            requestedGains: [a: 0.8, b: 1],
            renderSampleRates: [a: 48_000, b: 48_000],
            isPlaying: false
        )
        check(immediate.mode == .immediate, "paused transport must use immediate apply")
        check(immediate.execution.steps.isEmpty, "unchanged gain must not schedule work")

        do {
            _ = try PlaybackBackendGainApplicationPlanner.plan(
                loadedStemIDs: [a, a],
                committedGains: [:],
                requestedGains: [:],
                renderSampleRates: [a: 48_000],
                isPlaying: true
            )
            fatalError("duplicate loaded stem accepted")
        } catch PlaybackBackendGainApplicationError.duplicateLoadedStem(let got) {
            check(got == a, "wrong duplicate stem")
        }

        do {
            _ = try PlaybackBackendGainApplicationPlanner.plan(
                loadedStemIDs: [a],
                committedGains: [:],
                requestedGains: [c: 0.2],
                renderSampleRates: [a: 48_000],
                isPlaying: true
            )
            fatalError("unknown requested stem accepted")
        } catch PlaybackBackendGainApplicationError.unknownRequestedStem(let got) {
            check(got == c, "wrong unknown requested stem")
        }

        do {
            _ = try PlaybackBackendGainApplicationPlanner.plan(
                loadedStemIDs: [a],
                committedGains: [:],
                requestedGains: [:],
                renderSampleRates: [:],
                isPlaying: true
            )
            fatalError("missing sample rate accepted")
        } catch PlaybackBackendGainApplicationError.missingRenderSampleRate(let got) {
            check(got == a, "wrong missing-rate stem")
        }

        var committed: [StemID: Double] = [a: 1, b: 1]
        for i in 0..<10_000 {
            let next = try PlaybackBackendGainApplicationPlanner.plan(
                loadedStemIDs: [a, b],
                committedGains: committed,
                requestedGains: [
                    a: Double(i % 101) / 100,
                    b: Double(100 - (i % 101)) / 100
                ],
                renderSampleRates: [a: 48_000, b: 96_000],
                isPlaying: true
            )
            committed = next.normalizedTargetGains
            check(
                next.execution.steps.allSatisfy {
                    $0.frameCount == ($0.stemID == a ? 576 : 1_152)
                },
                "rapid retarget changed ramp duration"
            )
        }

        print("L3-AW02 backend gain application self-test PASS")
    }
}
