import Foundation

public struct FrameExtractionConfiguration: Sendable, Equatable {
    public var analysisFramesPerSecond: Double
    public var thumbnailWidth: Int
    public var thumbnailHeight: Int
    public var stableMotionThreshold: Double
    public var unstableMotionThreshold: Double
    public var minimumStableDurationMS: Int64
    public var settlePaddingMS: Int64
    public var departurePaddingMS: Int64
    public var duplicateCenteredMADThreshold: Double
    public var duplicateHashDistanceThreshold: Int
    public var minimumSharpnessScore: Double

    public init(
        analysisFramesPerSecond: Double = 8,
        thumbnailWidth: Int = 64,
        thumbnailHeight: Int = 48,
        stableMotionThreshold: Double = 0.035,
        unstableMotionThreshold: Double = 0.075,
        minimumStableDurationMS: Int64 = 420,
        settlePaddingMS: Int64 = 120,
        departurePaddingMS: Int64 = 80,
        duplicateCenteredMADThreshold: Double = 0.020,
        duplicateHashDistanceThreshold: Int = 6,
        minimumSharpnessScore: Double = 0.02
    ) {
        self.analysisFramesPerSecond = analysisFramesPerSecond
        self.thumbnailWidth = thumbnailWidth
        self.thumbnailHeight = thumbnailHeight
        self.stableMotionThreshold = stableMotionThreshold
        self.unstableMotionThreshold = unstableMotionThreshold
        self.minimumStableDurationMS = minimumStableDurationMS
        self.settlePaddingMS = settlePaddingMS
        self.departurePaddingMS = departurePaddingMS
        self.duplicateCenteredMADThreshold = duplicateCenteredMADThreshold
        self.duplicateHashDistanceThreshold = duplicateHashDistanceThreshold
        self.minimumSharpnessScore = minimumSharpnessScore
    }
}

public struct SourceRangeMS: Codable, Sendable, Equatable {
    public var start: Int64
    public var end: Int64

    public init(start: Int64, end: Int64) {
        self.start = start
        self.end = end
    }
}

public struct PageCandidate: Codable, Sendable, Equatable {
    public var candidateID: String
    public var bookID: String
    public var sourceTimeMS: Int64
    public var sourceRangeMS: SourceRangeMS
    public var imageRef: String
    public var stabilityScore: Double
    public var sharpnessScore: Double
    public var motionScore: Double
    public var duplicateGroupID: String?
    public var flags: [String]

    public init(candidateID: String, bookID: String, sourceTimeMS: Int64, sourceRangeMS: SourceRangeMS, imageRef: String, stabilityScore: Double, sharpnessScore: Double, motionScore: Double, duplicateGroupID: String? = nil, flags: [String] = []) {
        self.candidateID = candidateID
        self.bookID = bookID
        self.sourceTimeMS = sourceTimeMS
        self.sourceRangeMS = sourceRangeMS
        self.imageRef = imageRef
        self.stabilityScore = stabilityScore
        self.sharpnessScore = sharpnessScore
        self.motionScore = motionScore
        self.duplicateGroupID = duplicateGroupID
        self.flags = flags
    }

    enum CodingKeys: String, CodingKey {
        case candidateID = "candidate_id"
        case bookID = "book_id"
        case sourceTimeMS = "source_time_ms"
        case sourceRangeMS = "source_range_ms"
        case imageRef = "image_ref"
        case stabilityScore = "stability_score"
        case sharpnessScore = "sharpness_score"
        case motionScore = "motion_score"
        case duplicateGroupID = "duplicate_group_id"
        case flags
    }
}

public struct LumaThumbnail: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(width > 0 && height > 0, "thumbnail dimensions must be positive")
        precondition(pixels.count == width * height, "pixel count must match dimensions")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func meanAbsoluteDifference(to other: LumaThumbnail) -> Double {
        guard width == other.width, height == other.height else { return 1 }
        var total = 0
        for index in pixels.indices { total += abs(Int(pixels[index]) - Int(other.pixels[index])) }
        return Double(total) / Double(pixels.count * 255)
    }

    public func centeredMeanAbsoluteDifference(to other: LumaThumbnail) -> Double {
        guard width == other.width, height == other.height else { return 1 }
        let leftMean = pixels.reduce(0.0) { $0 + Double($1) } / Double(pixels.count)
        let rightMean = other.pixels.reduce(0.0) { $0 + Double($1) } / Double(other.pixels.count)
        var total = 0.0
        for index in pixels.indices {
            total += abs((Double(pixels[index]) - leftMean) - (Double(other.pixels[index]) - rightMean))
        }
        return min(1, total / Double(pixels.count * 255))
    }

    public func differenceHash64() -> UInt64 {
        guard width >= 9, height >= 8 else { return 0 }
        var hash: UInt64 = 0
        for row in 0..<8 {
            let y = min(height - 1, row * height / 8)
            for column in 0..<8 {
                let x0 = min(width - 1, column * width / 9)
                let x1 = min(width - 1, (column + 1) * width / 9)
                if pixels[y * width + x0] > pixels[y * width + x1] { hash |= UInt64(1) << UInt64(row * 8 + column) }
            }
        }
        return hash
    }

    public func hashDistance(to other: LumaThumbnail) -> Int {
        (differenceHash64() ^ other.differenceHash64()).nonzeroBitCount
    }

    public func sharpnessScore() -> Double {
        guard width >= 3, height >= 3 else { return 0 }
        var energy = 0.0
        var samples = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Int(pixels[y * width + x])
                let left = Int(pixels[y * width + x - 1])
                let right = Int(pixels[y * width + x + 1])
                let top = Int(pixels[(y - 1) * width + x])
                let bottom = Int(pixels[(y + 1) * width + x])
                energy += Double(abs(4 * center - left - right - top - bottom)) / 1020.0
                samples += 1
            }
        }
        guard samples > 0 else { return 0 }
        return min(1, energy / Double(samples) * 6.0)
    }
}

public struct AnalyzedFrame: Sendable, Equatable {
    public var timestampMS: Int64
    public var thumbnail: LumaThumbnail
    public var motionScore: Double
    public var sharpnessScore: Double

    public init(timestampMS: Int64, thumbnail: LumaThumbnail, motionScore: Double, sharpnessScore: Double? = nil) {
        self.timestampMS = timestampMS
        self.thumbnail = thumbnail
        self.motionScore = max(0, min(1, motionScore))
        self.sharpnessScore = max(0, min(1, sharpnessScore ?? thumbnail.sharpnessScore()))
    }
}

public struct StableFrameSelection: Sendable, Equatable {
    public var sourceTimeMS: Int64
    public var sourceRangeMS: SourceRangeMS
    public var stabilityScore: Double
    public var sharpnessScore: Double
    public var motionScore: Double
    public var thumbnail: LumaThumbnail
    public var duplicateGroupID: String?
    public var flags: [String]

    public init(sourceTimeMS: Int64, sourceRangeMS: SourceRangeMS, stabilityScore: Double, sharpnessScore: Double, motionScore: Double, thumbnail: LumaThumbnail, duplicateGroupID: String? = nil, flags: [String] = []) {
        self.sourceTimeMS = sourceTimeMS
        self.sourceRangeMS = sourceRangeMS
        self.stabilityScore = stabilityScore
        self.sharpnessScore = sharpnessScore
        self.motionScore = motionScore
        self.thumbnail = thumbnail
        self.duplicateGroupID = duplicateGroupID
        self.flags = flags
    }
}
