import Foundation

public struct OCRPageNumberCandidate: Equatable, Sendable {
    public var text: String
    public var confidence: Double
    public var boundingBox: NormalizedRect
    public var rotationDegrees: Int

    public init(text: String, confidence: Double, boundingBox: NormalizedRect, rotationDegrees: Int = 0) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.rotationDegrees = rotationDegrees
    }
}

public struct PageNumberScoringConfiguration: Equatable, Sendable {
    public var maximumPageNumber: Int
    public var edgeBandFraction: Double
    public var headerFooterBandFraction: Double

    public init(maximumPageNumber: Int = 3000, edgeBandFraction: Double = 0.28, headerFooterBandFraction: Double = 0.22) {
        self.maximumPageNumber = maximumPageNumber
        self.edgeBandFraction = edgeBandFraction
        self.headerFooterBandFraction = headerFooterBandFraction
    }
}

public enum PageNumberScorer {
    public static func bestObservation(pageID: String, candidates: [OCRPageNumberCandidate], configuration: PageNumberScoringConfiguration = .init()) -> PageNumberObservation? {
        candidates.compactMap { candidate in
            observation(pageID: pageID, candidate: candidate, configuration: configuration)
        }.max { lhs, rhs in lhs.score < rhs.score }
    }

    public static func observation(pageID: String, candidate: OCRPageNumberCandidate, configuration: PageNumberScoringConfiguration = .init()) -> PageNumberObservation? {
        let normalizedText = normalizeDigits(candidate.text)
        guard let value = extractStandaloneNumber(from: normalizedText), value >= 0, value <= configuration.maximumPageNumber else {
            return nil
        }

        let compact = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitCount = compact.filter(\.isNumber).count
        let nonDigitCount = compact.filter { !$0.isNumber && !$0.isWhitespace && !"-–—()[]".contains($0) }.count
        guard digitCount > 0 else { return nil }

        let x = candidate.boundingBox.midX
        let y = candidate.boundingBox.midY
        let nearHorizontalEdge = x <= configuration.edgeBandFraction || x >= (1 - configuration.edgeBandFraction)
        let nearVerticalEdge = y <= configuration.headerFooterBandFraction || y >= (1 - configuration.headerFooterBandFraction)

        var score = clamp(candidate.confidence, 0, 1) * 55
        if nearVerticalEdge { score += 24 }
        if nearHorizontalEdge { score += 10 }
        if compact.count <= 5 { score += 12 }
        if nonDigitCount == 0 { score += 14 }
        if digitCount <= 4 { score += 6 }
        if digitCount == 4 && value >= 1900 && value <= 2100 { score -= 28 }
        score -= Double(nonDigitCount) * 5

        return PageNumberObservation(
            pageID: pageID,
            value: value,
            confidence: clamp(candidate.confidence, 0, 1),
            rawText: candidate.text,
            boundingBox: candidate.boundingBox,
            rotationDegrees: candidate.rotationDegrees,
            score: score
        )
    }

    public static func normalizeDigits(_ text: String) -> String {
        let fullwidth = Array("０１２３４５６７８９")
        let ascii = Array("0123456789")
        var map: [Character: Character] = [:]
        for (index, char) in fullwidth.enumerated() { map[char] = ascii[index] }
        return String(text.map { map[$0] ?? $0 })
    }

    private static func extractStandaloneNumber(from text: String) -> Int? {
        let parts = text.split { !$0.isNumber }
        let values = parts.compactMap { Int($0) }
        guard values.count == 1 else { return nil }
        return values[0]
    }

    private static func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
