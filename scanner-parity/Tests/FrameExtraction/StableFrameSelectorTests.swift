import XCTest

final class StableFrameSelectorTests: XCTestCase {
    private let config = FrameExtractionConfiguration(
        analysisFramesPerSecond: 10,
        stableMotionThreshold: 0.03,
        unstableMotionThreshold: 0.07,
        minimumStableDurationMS: 400,
        settlePaddingMS: 100,
        departurePaddingMS: 100,
        duplicateCenteredMADThreshold: 0.01,
        duplicateHashDistanceThreshold: 4,
        minimumSharpnessScore: 0.01
    )

    func testTransitionFramesAreNotSelected() {
        let pageA = thumbnail(seed: 17)
        let pageB = thumbnail(seed: 61)
        var frames: [AnalyzedFrame] = []
        frames += stableFrames(from: 0, through: 900, thumbnail: pageA, bestAt: 500)
        frames += [1000, 1100, 1200, 1300].map {
            AnalyzedFrame(timestampMS: Int64($0), thumbnail: thumbnail(seed: UInt8($0 / 10)), motionScore: 0.20, sharpnessScore: 0.5)
        }
        frames += stableFrames(from: 1400, through: 2400, thumbnail: pageB, bestAt: 1900)

        let selections = StableFrameSelector(configuration: config).select(from: frames)
        XCTAssertEqual(selections.count, 2)
        XCTAssertTrue((100...800).contains(Int(selections[0].sourceTimeMS)))
        XCTAssertTrue((1500...2300).contains(Int(selections[1].sourceTimeMS)))
        XCTAssertFalse((1000...1300).contains(Int(selections[0].sourceTimeMS)))
        XCTAssertFalse((1000...1300).contains(Int(selections[1].sourceTimeMS)))
    }

    func testShortPauseDuringPageTurnIsRejected() {
        let pageA = thumbnail(seed: 21)
        let transient = thumbnail(seed: 33)
        let pageB = thumbnail(seed: 77)
        var frames = stableFrames(from: 0, through: 800, thumbnail: pageA, bestAt: 400)
        frames.append(AnalyzedFrame(timestampMS: 900, thumbnail: transient, motionScore: 0.18, sharpnessScore: 0.6))
        frames += [1000, 1100, 1200].map {
            AnalyzedFrame(timestampMS: Int64($0), thumbnail: transient, motionScore: 0.01, sharpnessScore: 0.9)
        }
        frames.append(AnalyzedFrame(timestampMS: 1300, thumbnail: transient, motionScore: 0.18, sharpnessScore: 0.8))
        frames += stableFrames(from: 1400, through: 2300, thumbnail: pageB, bestAt: 1800)

        let selections = StableFrameSelector(configuration: config).select(from: frames)
        XCTAssertEqual(selections.count, 2, "a short pause inside a page turn must not become a page")
    }

    func testSamePageSeparatedByCameraBumpCollapsesToOneCandidate() {
        let page = thumbnail(seed: 42)
        var frames = stableFrames(from: 0, through: 800, thumbnail: page, bestAt: 400)
        frames.append(AnalyzedFrame(timestampMS: 900, thumbnail: page, motionScore: 0.2, sharpnessScore: 0.2))
        frames += stableFrames(from: 1000, through: 1900, thumbnail: brighter(page, delta: 7), bestAt: 1500)

        let selections = StableFrameSelector(configuration: config).select(from: frames)
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0].sourceRangeMS.start, 0)
        XCTAssertEqual(selections[0].sourceRangeMS.end, 1900)
        XCTAssertNotNil(selections[0].duplicateGroupID)
        XCTAssertTrue(selections[0].flags.contains("collapsed-consecutive-duplicate"))
    }

    func testSharpestFrameWinsWithinStableInterval() {
        let page = thumbnail(seed: 19)
        var frames = (0...10).map { step in
            AnalyzedFrame(timestampMS: Int64(step * 100), thumbnail: page, motionScore: 0.01, sharpnessScore: 0.20)
        }
        frames[6].sharpnessScore = 0.95

        let selections = StableFrameSelector(configuration: config).select(from: frames)
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0].sourceTimeMS, 600)
        XCTAssertEqual(selections[0].sharpnessScore, 0.95, accuracy: 0.0001)
    }

    func testStableSelectorDiffersFromNaiveSceneChangeBaseline() {
        let pageA = thumbnail(seed: 4)
        let transition = thumbnail(seed: 120)
        let pageB = thumbnail(seed: 80)
        var frames = stableFrames(from: 0, through: 700, thumbnail: pageA, bestAt: 400)
        frames.append(AnalyzedFrame(timestampMS: 800, thumbnail: transition, motionScore: 0.25, sharpnessScore: 0.8))
        frames += stableFrames(from: 900, through: 1700, thumbnail: pageB, bestAt: 1300)

        let naiveTimestamp = frames.first(where: { $0.motionScore > 0.10 })?.timestampMS
        let selections = StableFrameSelector(configuration: config).select(from: frames)

        XCTAssertEqual(naiveTimestamp, 800, "scene-change picks the transition boundary itself")
        XCTAssertEqual(selections.count, 2)
        XCTAssertFalse(selections.contains(where: { $0.sourceTimeMS == 800 }))
    }

    private func stableFrames(from start: Int, through end: Int, thumbnail: LumaThumbnail, bestAt: Int) -> [AnalyzedFrame] {
        stride(from: start, through: end, by: 100).map { timestamp in
            AnalyzedFrame(
                timestampMS: Int64(timestamp),
                thumbnail: thumbnail,
                motionScore: timestamp == start ? 0.02 : 0.01,
                sharpnessScore: timestamp == bestAt ? 0.90 : 0.30
            )
        }
    }

    private func thumbnail(seed: UInt8) -> LumaThumbnail {
        let width = 18
        let height = 12
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height)
        for index in 0..<(width * height) {
            let base = Int(seed) + index * 17
            let rowBias = (index / width) * 13
            pixels.append(UInt8((base + rowBias) % 256))
        }
        return LumaThumbnail(width: width, height: height, pixels: pixels)
    }

    private func brighter(_ input: LumaThumbnail, delta: Int) -> LumaThumbnail {
        LumaThumbnail(
            width: input.width,
            height: input.height,
            pixels: input.pixels.map { UInt8(max(0, min(255, Int($0) + delta))) }
        )
    }
}
