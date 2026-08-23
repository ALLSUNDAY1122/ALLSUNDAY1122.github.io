import Foundation

public struct StableFrameSelector: Sendable {
    public let configuration: FrameExtractionConfiguration

    public init(configuration: FrameExtractionConfiguration = .init()) {
        self.configuration = configuration
    }

    public func select(from frames: [AnalyzedFrame]) -> [StableFrameSelection] {
        var incremental = IncrementalStableFrameSelector(configuration: configuration)
        for frame in frames.sorted(by: { $0.timestampMS < $1.timestampMS }) {
            incremental.consume(frame)
        }
        return incremental.finish()
    }

    public func makePageCandidates(
        selections: [StableFrameSelection],
        bookID: String,
        imageRef: (StableFrameSelection, Int) -> String
    ) -> [PageCandidate] {
        selections.enumerated().map { index, selection in
            PageCandidate(
                candidateID: String(format: "%@-candidate-%04d", bookID, index + 1),
                bookID: bookID,
                sourceTimeMS: selection.sourceTimeMS,
                sourceRangeMS: selection.sourceRangeMS,
                imageRef: imageRef(selection, index),
                stabilityScore: selection.stabilityScore,
                sharpnessScore: selection.sharpnessScore,
                motionScore: selection.motionScore,
                duplicateGroupID: selection.duplicateGroupID,
                flags: selection.flags
            )
        }
    }
}

public struct IncrementalStableFrameSelector: Sendable {
    private let configuration: FrameExtractionConfiguration
    private var stableRun: [AnalyzedFrame] = []
    private var selections: [StableFrameSelection] = []
    private var duplicateCounter = 0
    private var lastTimestampMS: Int64?

    public init(configuration: FrameExtractionConfiguration = .init()) {
        self.configuration = configuration
    }

    public mutating func consume(_ frame: AnalyzedFrame) {
        if let previousTimestamp = lastTimestampMS, frame.timestampMS < previousTimestamp { return }
        lastTimestampMS = frame.timestampMS

        if frame.motionScore <= configuration.stableMotionThreshold {
            stableRun.append(frame)
            return
        }
        if frame.motionScore >= configuration.unstableMotionThreshold {
            flushStableRun()
            return
        }

        let hysteresisCeiling = (configuration.stableMotionThreshold + configuration.unstableMotionThreshold) / 2
        if !stableRun.isEmpty, frame.motionScore <= hysteresisCeiling {
            stableRun.append(frame)
        } else {
            flushStableRun()
        }
    }

    public mutating func finish() -> [StableFrameSelection] {
        flushStableRun()
        return selections
    }

    private mutating func flushStableRun() {
        defer { stableRun.removeAll(keepingCapacity: true) }
        guard let selection = makeSelection(from: stableRun) else { return }
        appendCollapsingDuplicate(selection)
    }

    private func makeSelection(from run: [AnalyzedFrame]) -> StableFrameSelection? {
        guard let first = run.first, let last = run.last else { return nil }
        let duration = last.timestampMS - first.timestampMS
        guard duration >= configuration.minimumStableDurationMS else { return nil }

        let paddedStart = first.timestampMS + configuration.settlePaddingMS
        let paddedEnd = last.timestampMS - configuration.departurePaddingMS
        var eligible = run.filter { $0.timestampMS >= paddedStart && $0.timestampMS <= paddedEnd }
        if eligible.isEmpty { eligible = run }

        let midpoint = Double(first.timestampMS + last.timestampMS) / 2
        let halfDuration = max(1, Double(duration) / 2)
        let best = eligible.max { left, right in
            selectionScore(left, midpoint: midpoint, halfDuration: halfDuration)
                < selectionScore(right, midpoint: midpoint, halfDuration: halfDuration)
        }
        guard let best, best.sharpnessScore >= configuration.minimumSharpnessScore else { return nil }

        let averageMotion = run.reduce(0.0) { $0 + $1.motionScore } / Double(run.count)
        return StableFrameSelection(
            sourceTimeMS: best.timestampMS,
            sourceRangeMS: SourceRangeMS(start: first.timestampMS, end: last.timestampMS),
            stabilityScore: max(0, min(1, 1 - averageMotion)),
            sharpnessScore: best.sharpnessScore,
            motionScore: best.motionScore,
            thumbnail: best.thumbnail,
            flags: []
        )
    }

    private func selectionScore(_ frame: AnalyzedFrame, midpoint: Double, halfDuration: Double) -> Double {
        let centrality = max(0, 1 - abs(Double(frame.timestampMS) - midpoint) / halfDuration)
        let stability = 1 - frame.motionScore
        return frame.sharpnessScore * 0.60 + stability * 0.30 + centrality * 0.10
    }

    private mutating func appendCollapsingDuplicate(_ selection: StableFrameSelection) {
        guard var previous = selections.last else {
            selections.append(selection)
            return
        }

        let centeredMAD = previous.thumbnail.centeredMeanAbsoluteDifference(to: selection.thumbnail)
        let hashDistance = previous.thumbnail.hashDistance(to: selection.thumbnail)
        let isDuplicate = centeredMAD <= configuration.duplicateCenteredMADThreshold
            && hashDistance <= configuration.duplicateHashDistanceThreshold

        guard isDuplicate else {
            selections.append(selection)
            return
        }

        duplicateCounter += 1
        let groupID = previous.duplicateGroupID ?? "stable-dup-\(duplicateCounter)"
        let keepNew = selection.sharpnessScore > previous.sharpnessScore
            || (selection.sharpnessScore == previous.sharpnessScore && selection.motionScore < previous.motionScore)
        let oldRange = previous.sourceRangeMS
        if keepNew { previous = selection }
        previous.sourceRangeMS = SourceRangeMS(
            start: min(oldRange.start, selection.sourceRangeMS.start),
            end: max(oldRange.end, selection.sourceRangeMS.end)
        )
        previous.duplicateGroupID = groupID
        if !previous.flags.contains("collapsed-consecutive-duplicate") {
            previous.flags.append("collapsed-consecutive-duplicate")
        }
        selections[selections.count - 1] = previous
    }
}
