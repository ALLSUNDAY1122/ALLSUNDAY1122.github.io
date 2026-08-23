import Foundation

public enum CorrectionProfile: String, Codable, CaseIterable, Sendable {
    case archive
    case reading
    case ocr
}

public enum PreprocessingVariant: String, Codable, CaseIterable, Sendable {
    case original
    case balancedReading
    case ocrGrayscale
    case otsuBinary
}

public enum CorrectionFlag: String, Codable, Sendable {
    case boundaryFallback
    case lowBoundaryConfidence
    case perspectiveApplied
    case rotationApplied
    case dewarpPendingGoldenEvaluation
    case aggressiveBinarizationRejected
}

public struct NormalizedPoint: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PageQuad: Codable, Hashable, Sendable {
    public let topLeft: NormalizedPoint
    public let topRight: NormalizedPoint
    public let bottomRight: NormalizedPoint
    public let bottomLeft: NormalizedPoint

    public init(topLeft: NormalizedPoint, topRight: NormalizedPoint, bottomRight: NormalizedPoint, bottomLeft: NormalizedPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public static let fullFrame = PageQuad(
        topLeft: .init(x: 0, y: 1),
        topRight: .init(x: 1, y: 1),
        bottomRight: .init(x: 1, y: 0),
        bottomLeft: .init(x: 0, y: 0)
    )

    public var area: Double {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        var sum = 0.0
        for index in points.indices {
            let next = points[(index + 1) % points.count]
            sum += points[index].x * next.y - next.x * points[index].y
        }
        return abs(sum) * 0.5
    }

    public var residualSkewDegrees: Double {
        let dx = topRight.x - topLeft.x
        let dy = topRight.y - topLeft.y
        let raw = atan2(dy, dx) * 180 / .pi
        let nearestRightAngle = (raw / 90).rounded() * 90
        return raw - nearestRightAngle
    }

    public var perspectiveSeverity: Double {
        let top = distance(topLeft, topRight)
        let bottom = distance(bottomLeft, bottomRight)
        let left = distance(topLeft, bottomLeft)
        let right = distance(topRight, bottomRight)
        let horizontal = ratioDelta(top, bottom)
        let vertical = ratioDelta(left, right)
        return min(1, max(horizontal, vertical))
    }

    public func isPlausible(minimumArea: Double = 0.18) -> Bool {
        guard [topLeft, topRight, bottomRight, bottomLeft].allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            return false
        }
        return area >= minimumArea
    }

    private func distance(_ a: NormalizedPoint, _ b: NormalizedPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func ratioDelta(_ a: Double, _ b: Double) -> Double {
        let denominator = max(max(a, b), 0.000_001)
        return abs(a - b) / denominator
    }
}

public struct LuminanceMetrics: Codable, Equatable, Sendable {
    public let mean: Double
    public let standardDeviation: Double
    public let shadowFraction: Double
    public let highlightFraction: Double

    public init(mean: Double, standardDeviation: Double, shadowFraction: Double, highlightFraction: Double) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.shadowFraction = shadowFraction
        self.highlightFraction = highlightFraction
    }

    public static func from(histogram: [Int]) -> LuminanceMetrics? {
        guard histogram.count == 256 else { return nil }
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }

        let weighted = histogram.enumerated().reduce(0.0) { partial, pair in
            partial + Double(pair.offset * pair.element)
        }
        let mean = weighted / Double(total)
        let variance = histogram.enumerated().reduce(0.0) { partial, pair in
            let delta = Double(pair.offset) - mean
            return partial + delta * delta * Double(pair.element)
        } / Double(total)
        let shadow = histogram[0...35].reduce(0, +)
        let highlight = histogram[220...255].reduce(0, +)

        return .init(
            mean: mean / 255,
            standardDeviation: sqrt(variance) / 255,
            shadowFraction: Double(shadow) / Double(total),
            highlightFraction: Double(highlight) / Double(total)
        )
    }
}

public enum OtsuThreshold {
    public static func value(histogram: [Int]) -> Int? {
        guard histogram.count == 256 else { return nil }
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }

        let totalWeighted = histogram.enumerated().reduce(0.0) { partial, pair in
            partial + Double(pair.offset * pair.element)
        }

        var backgroundWeight = 0
        var backgroundWeighted = 0.0
        var bestVariance = -Double.infinity
        var bestThreshold = 0

        for threshold in 0..<256 {
            backgroundWeight += histogram[threshold]
            guard backgroundWeight > 0 else { continue }

            let foregroundWeight = total - backgroundWeight
            if foregroundWeight == 0 { break }

            backgroundWeighted += Double(threshold * histogram[threshold])
            let backgroundMean = backgroundWeighted / Double(backgroundWeight)
            let foregroundMean = (totalWeighted - backgroundWeighted) / Double(foregroundWeight)
            let delta = backgroundMean - foregroundMean
            let betweenClassVariance = Double(backgroundWeight * foregroundWeight) * delta * delta

            if betweenClassVariance > bestVariance {
                bestVariance = betweenClassVariance
                bestThreshold = threshold
            }
        }
        return bestThreshold
    }
}

public struct VariantSelection: Codable, Equatable, Sendable {
    public let selected: PreprocessingVariant
    public let score: Double
    public let reason: String
}

public enum VariantSelector {
    /// Avoids destructive preprocessing unless it beats the original by a meaningful margin.
    public static func choose(
        scores: [PreprocessingVariant: Double],
        minimumGainOverOriginal: Double = 0.03
    ) -> VariantSelection {
        let originalScore = scores[.original] ?? 0
        let ranked = scores.max { lhs, rhs in lhs.value < rhs.value }
        guard let best = ranked else {
            return .init(selected: .original, score: 0, reason: "no_score")
        }

        if best.key != .original, best.value < originalScore + minimumGainOverOriginal {
            return .init(selected: .original, score: originalScore, reason: "gain_below_guardrail")
        }
        return .init(selected: best.key, score: best.value, reason: "highest_validated_score")
    }
}

public enum PageOrientationPolicy: String, Codable, Sendable {
    case preserve
    case preferPortrait
}

public enum OrientationEstimator {
    public static func rotationDegrees(width: Double, height: Double, policy: PageOrientationPolicy) -> Int {
        guard policy == .preferPortrait, width > height * 1.05 else { return 0 }
        return 90
    }
}

public struct CorrectionQualityScores: Codable, Equatable, Sendable {
    public let boundaryConfidence: Double
    public let perspectiveSeverity: Double
    public let residualSkewDegrees: Double
    public let sourceLuminance: LuminanceMetrics?
    public let correctedLuminance: LuminanceMetrics?

    public init(
        boundaryConfidence: Double,
        perspectiveSeverity: Double,
        residualSkewDegrees: Double,
        sourceLuminance: LuminanceMetrics? = nil,
        correctedLuminance: LuminanceMetrics? = nil
    ) {
        self.boundaryConfidence = boundaryConfidence
        self.perspectiveSeverity = perspectiveSeverity
        self.residualSkewDegrees = residualSkewDegrees
        self.sourceLuminance = sourceLuminance
        self.correctedLuminance = correctedLuminance
    }
}

public struct CorrectedPageMetadata: Codable, Equatable, Sendable {
    public let pageID: String
    public let candidateID: String
    public let cropQuad: PageQuad
    public let rotationDegrees: Int
    public let perspectiveApplied: Bool
    public let dewarpApplied: Bool
    public let colorProfile: CorrectionProfile
    public let qualityScores: CorrectionQualityScores
    public let flags: [CorrectionFlag]

    public init(
        pageID: String,
        candidateID: String,
        cropQuad: PageQuad,
        rotationDegrees: Int,
        perspectiveApplied: Bool,
        dewarpApplied: Bool,
        colorProfile: CorrectionProfile,
        qualityScores: CorrectionQualityScores,
        flags: [CorrectionFlag]
    ) {
        self.pageID = pageID
        self.candidateID = candidateID
        self.cropQuad = cropQuad
        self.rotationDegrees = rotationDegrees
        self.perspectiveApplied = perspectiveApplied
        self.dewarpApplied = dewarpApplied
        self.colorProfile = colorProfile
        self.qualityScores = qualityScores
        self.flags = flags
    }
}
