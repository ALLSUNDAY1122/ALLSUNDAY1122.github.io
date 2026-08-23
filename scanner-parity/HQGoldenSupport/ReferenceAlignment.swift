import Foundation

public struct ReferenceNearestMatch: Codable, Sendable, Equatable {
    public let outputIndex: Int
    public let referenceIndex: Int
    public let distance: Float
    public let secondBestDistance: Float?

    public init(outputIndex: Int, referenceIndex: Int, distance: Float, secondBestDistance: Float? = nil) {
        self.outputIndex = outputIndex
        self.referenceIndex = referenceIndex
        self.distance = distance
        self.secondBestDistance = secondBestDistance
    }
}

public struct ReferenceAlignmentMetrics: Codable, Sendable, Equatable {
    public let referencePageCount: Int
    public let outputPageCount: Int
    public let matchedReferencePageCount: Int
    public let pageRecall: Double
    public let unmatchedOutputCount: Int
    public let duplicateExtraCount: Int
    public let duplicateRate: Double
    public let orderingAccuracy: Double
    public let threshold: Float

    public init(
        referencePageCount: Int,
        outputPageCount: Int,
        matchedReferencePageCount: Int,
        pageRecall: Double,
        unmatchedOutputCount: Int,
        duplicateExtraCount: Int,
        duplicateRate: Double,
        orderingAccuracy: Double,
        threshold: Float
    ) {
        self.referencePageCount = referencePageCount
        self.outputPageCount = outputPageCount
        self.matchedReferencePageCount = matchedReferencePageCount
        self.pageRecall = pageRecall
        self.unmatchedOutputCount = unmatchedOutputCount
        self.duplicateExtraCount = duplicateExtraCount
        self.duplicateRate = duplicateRate
        self.orderingAccuracy = orderingAccuracy
        self.threshold = threshold
    }
}

public enum ReferenceAlignment {
    public static func evaluate(
        referencePageCount: Int,
        nearestMatches: [ReferenceNearestMatch],
        threshold: Float
    ) -> ReferenceAlignmentMetrics {
        let referenceCount = max(0, referencePageCount)
        let valid = nearestMatches
            .filter { $0.referenceIndex >= 0 && $0.referenceIndex < referenceCount && $0.distance <= threshold }
            .sorted { $0.outputIndex < $1.outputIndex }

        let uniqueReferences = Set(valid.map(\.referenceIndex))
        let pageRecall = referenceCount == 0 ? 1 : Double(uniqueReferences.count) / Double(referenceCount)
        let unmatched = max(0, nearestMatches.count - valid.count)

        var counts: [Int: Int] = [:]
        valid.forEach { counts[$0.referenceIndex, default: 0] += 1 }
        let duplicateExtra = counts.values.reduce(0) { $0 + max(0, $1 - 1) }
        let duplicateRate = nearestMatches.isEmpty ? 0 : Double(duplicateExtra) / Double(nearestMatches.count)

        var seen = Set<Int>()
        let uniqueSequence = valid.compactMap { match -> Int? in
            guard seen.insert(match.referenceIndex).inserted else { return nil }
            return match.referenceIndex
        }
        let orderingAccuracy: Double
        if uniqueSequence.isEmpty {
            orderingAccuracy = referenceCount == 0 ? 1 : 0
        } else {
            orderingAccuracy = Double(longestIncreasingSubsequenceLength(uniqueSequence)) / Double(uniqueSequence.count)
        }

        return ReferenceAlignmentMetrics(
            referencePageCount: referenceCount,
            outputPageCount: nearestMatches.count,
            matchedReferencePageCount: uniqueReferences.count,
            pageRecall: pageRecall,
            unmatchedOutputCount: unmatched,
            duplicateExtraCount: duplicateExtra,
            duplicateRate: duplicateRate,
            orderingAccuracy: orderingAccuracy,
            threshold: threshold
        )
    }

    private static func longestIncreasingSubsequenceLength(_ values: [Int]) -> Int {
        var tails: [Int] = []
        for value in values {
            var low = 0
            var high = tails.count
            while low < high {
                let mid = (low + high) / 2
                if tails[mid] < value { low = mid + 1 } else { high = mid }
            }
            if low == tails.count { tails.append(value) } else { tails[low] = value }
        }
        return tails.count
    }
}
