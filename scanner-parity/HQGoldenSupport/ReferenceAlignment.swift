import Foundation

public struct ReferenceNearestMatch: Codable, Sendable, Equatable {
    public let outputIndex: Int
    /// Raw zero-based reference-PDF page index used by the local review bundle.
    public let referenceIndex: Int
    public let distance: Float
    public let secondBestDistance: Float?
    /// Canonical zero-based corpus group index when a reference-corpus manifest is active.
    public let canonicalReferenceIndex: Int?
    public let referenceCorpusPageCount: Int?
    public let referenceCorpusGroupID: String?
    public let nearestNegativeReferenceIndex: Int?
    public let nearestNegativeDistance: Float?
    public let referenceCorpusManifestSHA256: String?

    public init(
        outputIndex: Int,
        referenceIndex: Int,
        distance: Float,
        secondBestDistance: Float? = nil,
        canonicalReferenceIndex: Int? = nil,
        referenceCorpusPageCount: Int? = nil,
        referenceCorpusGroupID: String? = nil,
        nearestNegativeReferenceIndex: Int? = nil,
        nearestNegativeDistance: Float? = nil,
        referenceCorpusManifestSHA256: String? = nil
    ) {
        self.outputIndex = outputIndex
        self.referenceIndex = referenceIndex
        self.distance = distance
        self.secondBestDistance = secondBestDistance
        self.canonicalReferenceIndex = canonicalReferenceIndex
        self.referenceCorpusPageCount = referenceCorpusPageCount
        self.referenceCorpusGroupID = referenceCorpusGroupID
        self.nearestNegativeReferenceIndex = nearestNegativeReferenceIndex
        self.nearestNegativeDistance = nearestNegativeDistance
        self.referenceCorpusManifestSHA256 = referenceCorpusManifestSHA256
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
        let declaredCorpusCounts = Set(nearestMatches.compactMap(\.referenceCorpusPageCount))
        let referenceCount: Int
        if declaredCorpusCounts.count == 1, let corpusCount = declaredCorpusCounts.first {
            referenceCount = max(0, corpusCount)
        } else {
            // Inconsistent corpus metadata fails closed by retaining the raw
            // reference count rather than silently shrinking the denominator.
            referenceCount = max(0, referencePageCount)
        }

        let valid = nearestMatches
            .filter { match in
                let canonicalIndex = match.canonicalReferenceIndex ?? match.referenceIndex
                guard canonicalIndex >= 0,
                      canonicalIndex < referenceCount,
                      match.distance <= threshold else { return false }
                if let negativeDistance = match.nearestNegativeDistance,
                   negativeDistance <= threshold,
                   negativeDistance <= match.distance {
                    return false
                }
                return true
            }
            .sorted { $0.outputIndex < $1.outputIndex }

        let canonicalIndices = valid.map { $0.canonicalReferenceIndex ?? $0.referenceIndex }
        let uniqueReferences = Set(canonicalIndices)
        let pageRecall = referenceCount == 0 ? 1 : Double(uniqueReferences.count) / Double(referenceCount)
        let unmatched = max(0, nearestMatches.count - valid.count)

        var counts: [Int: Int] = [:]
        canonicalIndices.forEach { counts[$0, default: 0] += 1 }
        let duplicateExtra = counts.values.reduce(0) { $0 + max(0, $1 - 1) }
        let duplicateRate = nearestMatches.isEmpty ? 0 : Double(duplicateExtra) / Double(nearestMatches.count)

        var seen = Set<Int>()
        let uniqueSequence = canonicalIndices.compactMap { canonicalIndex -> Int? in
            guard seen.insert(canonicalIndex).inserted else { return nil }
            return canonicalIndex
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
