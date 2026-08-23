import Foundation

public struct PageIntegrityAuditConfiguration: Equatable, Sendable {
    public var trustedPageNumberScore: Double
    public var trustedPageNumberConfidence: Double
    public var duplicateImageSimilarity: Double
    public var duplicateTextSimilarity: Double
    public var autoDuplicateConfidence: Double
    public var autoSwapConfidence: Double

    public init(
        trustedPageNumberScore: Double = 72,
        trustedPageNumberConfidence: Double = 0.72,
        duplicateImageSimilarity: Double = 0.94,
        duplicateTextSimilarity: Double = 0.88,
        autoDuplicateConfidence: Double = 0.97,
        autoSwapConfidence: Double = 0.985
    ) {
        self.trustedPageNumberScore = trustedPageNumberScore
        self.trustedPageNumberConfidence = trustedPageNumberConfidence
        self.duplicateImageSimilarity = duplicateImageSimilarity
        self.duplicateTextSimilarity = duplicateTextSimilarity
        self.autoDuplicateConfidence = autoDuplicateConfidence
        self.autoSwapConfidence = autoSwapConfidence
    }
}

public struct PageIntegrityAuditor: Sendable {
    public var configuration: PageIntegrityAuditConfiguration

    public init(configuration: PageIntegrityAuditConfiguration = .init()) {
        self.configuration = configuration
    }

    public func audit(_ pages: [PageAuditInput]) -> PageAuditResult {
        guard !pages.isEmpty else {
            return PageAuditResult(
                orderedPageIDs: [], pageNumberObservations: [], duplicateGroups: [],
                missingPageSuspicions: [], reversalEvents: [], autoFixes: [], reviewRequired: []
            )
        }

        let timeline = pages.sorted {
            if $0.sourceTimeMs == $1.sourceTimeMs { return $0.pageID < $1.pageID }
            return $0.sourceTimeMs < $1.sourceTimeMs
        }
        let trusted = Dictionary(uniqueKeysWithValues: timeline.compactMap { page -> (String, PageNumberObservation)? in
            guard let number = page.pageNumber,
                  number.confidence >= configuration.trustedPageNumberConfidence,
                  number.score >= configuration.trustedPageNumberScore else { return nil }
            return (page.pageID, number)
        })
        let trustedValues = Set(trusted.values.map(\.value))

        var duplicateGroups: [DuplicateGroup] = []
        var missing: [MissingPageSuspicion] = []
        var reversals: [ReversalEvent] = []
        var autoFixes: [PageAutoFix] = []
        var review: [PageReviewItem] = []

        for page in timeline {
            if let observation = page.pageNumber,
               trusted[page.pageID] == nil {
                review.append(PageReviewItem(
                    pageIDs: [page.pageID],
                    reason: .lowConfidencePageNumber,
                    confidence: observation.confidence,
                    detail: "ページ番号候補 \(observation.value) は自動順序修復に使う閾値未満"
                ))
            }
        }

        for i in 0..<timeline.count {
            for j in (i + 1)..<timeline.count {
                let lhs = timeline[i]
                let rhs = timeline[j]
                let imageSimilarity = Self.imageSimilarity(lhs.perceptualHash, rhs.perceptualHash)
                let textSimilarity = Self.textSimilarity(lhs.text, rhs.text)
                guard imageSimilarity >= configuration.duplicateImageSimilarity || textSimilarity >= configuration.duplicateTextSimilarity else {
                    continue
                }

                let sameTrustedPageNumber: Bool = {
                    guard let l = trusted[lhs.pageID], let r = trusted[rhs.pageID] else { return false }
                    return l.value == r.value
                }()

                let confidence = Self.duplicateConfidence(
                    imageSimilarity: imageSimilarity,
                    textSimilarity: textSimilarity,
                    sameTrustedPageNumber: sameTrustedPageNumber
                )
                let evidence: [PageAuditEvidenceSource] = [
                    imageSimilarity >= configuration.duplicateImageSimilarity ? .imageSimilarity : nil,
                    textSimilarity >= configuration.duplicateTextSimilarity ? .textSimilarity : nil,
                    sameTrustedPageNumber ? .pageNumberOCR : nil,
                    .sourceTimeline
                ].compactMap { $0 }

                duplicateGroups.append(DuplicateGroup(pageIDs: [lhs.pageID, rhs.pageID], confidence: confidence, evidence: evidence))

                if confidence >= configuration.autoDuplicateConfidence {
                    autoFixes.append(PageAutoFix(
                        kind: .removeDuplicate,
                        pageIDs: [rhs.pageID],
                        confidence: confidence,
                        rationale: "画像/本文類似度とページ番号証拠が一致する重複"
                    ))
                } else {
                    review.append(PageReviewItem(
                        pageIDs: [lhs.pageID, rhs.pageID],
                        reason: .possibleDuplicate,
                        confidence: confidence,
                        detail: "重複候補だが自動削除閾値未満"
                    ))
                }
            }
        }

        for index in 0..<(timeline.count - 1) {
            let lhs = timeline[index]
            let rhs = timeline[index + 1]
            guard let lnum = trusted[lhs.pageID], let rnum = trusted[rhs.pageID] else { continue }

            if rnum.value > lnum.value + 1 {
                let gap = Array((lnum.value + 1)..<rnum.value)
                let actuallyAbsent = gap.filter { !trustedValues.contains($0) }
                if !actuallyAbsent.isEmpty {
                    let confidence = min(0.995, 0.72 + min(0.25, Double(actuallyAbsent.count) * 0.035) + (lnum.confidence + rnum.confidence) * 0.02)
                    missing.append(MissingPageSuspicion(
                        afterPageID: lhs.pageID,
                        beforePageID: rhs.pageID,
                        expectedPageNumbers: actuallyAbsent,
                        confidence: confidence,
                        evidence: [.pageNumberOCR, .sourceTimeline]
                    ))
                    review.append(PageReviewItem(
                        pageIDs: [lhs.pageID, rhs.pageID],
                        reason: .missingPage,
                        confidence: confidence,
                        detail: "ページ番号 \(lnum.value) と \(rnum.value) の間に \(actuallyAbsent.map(String.init).joined(separator: ",")) が不足する可能性"
                    ))
                }
            }

            if rnum.value < lnum.value {
                let confidence = min(0.999, (lnum.confidence + rnum.confidence) / 2 * 0.8 + 0.18)
                reversals.append(ReversalEvent(
                    leftPageID: lhs.pageID,
                    rightPageID: rhs.pageID,
                    observedNumbers: [lnum.value, rnum.value],
                    confidence: confidence,
                    evidence: [.pageNumberOCR, .sourceTimeline]
                ))
                review.append(PageReviewItem(
                    pageIDs: [lhs.pageID, rhs.pageID],
                    reason: .possibleReversal,
                    confidence: confidence,
                    detail: "元動画時系列に対してページ番号が逆行"
                ))
            }
        }

        var working = timeline
        var removedIDs = Set<String>()
        for fix in autoFixes where fix.kind == .removeDuplicate && fix.confidence >= configuration.autoDuplicateConfidence {
            removedIDs.formUnion(fix.pageIDs)
        }
        working.removeAll { removedIDs.contains($0.pageID) }

        var index = 0
        while index + 1 < working.count {
            let first = working[index]
            let second = working[index + 1]
            guard let a = trusted[first.pageID], let b = trusted[second.pageID] else {
                index += 1
                continue
            }

            let previousNumber = index > 0 ? trusted[working[index - 1].pageID]?.value : nil
            let nextNumber = index + 2 < working.count ? trusted[working[index + 2].pageID]?.value : nil
            let looksLikeAdjacentSwap = a.value == b.value + 1
                && (previousNumber == nil || previousNumber == b.value - 1)
                && (nextNumber == nil || nextNumber == a.value + 1)

            let confidence = min(min(a.confidence, b.confidence), min(a.score, b.score) / 100)
            if looksLikeAdjacentSwap && confidence >= configuration.autoSwapConfidence {
                working.swapAt(index, index + 1)
                autoFixes.append(PageAutoFix(
                    kind: .swapAdjacentPages,
                    pageIDs: [first.pageID, second.pageID],
                    confidence: confidence,
                    rationale: "高信頼ページ番号が隣接1ページだけ反転し、前後連続性も一致"
                ))
                let fixedIDs = Set([first.pageID, second.pageID])
                review.removeAll { item in
                    item.reason == .possibleReversal && Set(item.pageIDs) == fixedIDs
                }
                index += 2
            } else {
                index += 1
            }
        }

        return PageAuditResult(
            orderedPageIDs: working.map(\.pageID),
            pageNumberObservations: timeline.compactMap(\.pageNumber),
            duplicateGroups: Self.deduplicatedGroups(duplicateGroups),
            missingPageSuspicions: missing,
            reversalEvents: reversals,
            autoFixes: autoFixes,
            reviewRequired: Self.deduplicatedReview(review)
        )
    }

    static func imageSimilarity(_ lhs: UInt64?, _ rhs: UInt64?) -> Double {
        guard let lhs, let rhs else { return 0 }
        let distance = (lhs ^ rhs).nonzeroBitCount
        return 1 - Double(distance) / 64
    }

    static func textSimilarity(_ lhs: String?, _ rhs: String?) -> Double {
        guard let lhs, let rhs else { return 0 }
        let a = shingles(lhs)
        let b = shingles(rhs)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }

    private static func shingles(_ text: String) -> Set<String> {
        let normalized = text.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
        guard normalized.count >= 3 else { return normalized.isEmpty ? [] : [normalized] }
        let chars = Array(normalized)
        return Set((0...(chars.count - 3)).map { String(chars[$0...($0 + 2)]) })
    }

    private static func duplicateConfidence(imageSimilarity: Double, textSimilarity: Double, sameTrustedPageNumber: Bool) -> Double {
        var value = imageSimilarity * 0.56 + textSimilarity * 0.32
        if sameTrustedPageNumber { value += 0.12 }
        return min(0.999, value)
    }

    private static func deduplicatedGroups(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        var seen = Set<String>()
        return groups.filter { group in
            let key = group.pageIDs.sorted().joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private static func deduplicatedReview(_ items: [PageReviewItem]) -> [PageReviewItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = item.reason.rawValue + ":" + item.pageIDs.sorted().joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
