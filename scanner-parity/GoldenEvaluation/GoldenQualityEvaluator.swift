import Foundation

public enum GoldenQualityEvaluator {
    public static func evaluate(
        candidates: [PageCandidate],
        correctedPages: [CorrectedPageMetadata],
        auditResult: PageAuditResult,
        groundTruth: GoldenGroundTruth,
        observedHashes: GoldenObservedHashes = .init(),
        targets: GoldenMetricTargets = .init(),
        generatedAt: Date = Date()
    ) -> GoldenEvaluationReport {
        let expectedIDs = groundTruth.expectedPageIDs
        let expectedSet = Set(expectedIDs)
        let observedOrder = auditResult.orderedPageIDs
        let observedSet = Set(observedOrder)

        let pageRecall: Double = {
            guard !expectedIDs.isEmpty else { return 1 }
            let found = expectedSet.intersection(observedSet).count
            return Double(found) / Double(expectedIDs.count)
        }()

        let correctedCandidateIDs = Set(correctedPages.map(\.candidateID))
        let transitionAcceptedCount = correctedCandidateIDs
            .intersection(groundTruth.transitionCandidateIDs)
            .count

        let duplicateExtraIDs: Set<String> = auditResult.duplicateGroups.reduce(into: Set<String>()) { partial, group in
            guard group.pageIDs.count > 1 else { return }
            for pageID in group.pageIDs.dropFirst() { partial.insert(pageID) }
        }
        let duplicateRate: Double = {
            guard !correctedPages.isEmpty else { return 0 }
            return Double(duplicateExtraIDs.count) / Double(correctedPages.count)
        }()

        let orderingAccuracy: Double = {
            guard !expectedIDs.isEmpty else { return 1 }
            let filteredObserved = observedOrder.filter { expectedSet.contains($0) }
            var matches = 0
            for index in expectedIDs.indices {
                guard index < filteredObserved.count else { continue }
                if expectedIDs[index] == filteredObserved[index] { matches += 1 }
            }
            return Double(matches) / Double(expectedIDs.count)
        }()

        let metrics = [
            GoldenMetricEvaluation(
                name: "page_recall",
                value: pageRecall,
                targetDescription: ">= \(targets.minimumPageRecall)",
                meetsTarget: pageRecall >= targets.minimumPageRecall
            ),
            GoldenMetricEvaluation(
                name: "mid_transition_accepted",
                value: Double(transitionAcceptedCount),
                targetDescription: "<= \(targets.maximumTransitionAccepted)",
                meetsTarget: transitionAcceptedCount <= targets.maximumTransitionAccepted
            ),
            GoldenMetricEvaluation(
                name: "duplicate_rate",
                value: duplicateRate,
                targetDescription: "<= \(targets.maximumDuplicateRate)",
                meetsTarget: duplicateRate <= targets.maximumDuplicateRate
            ),
            GoldenMetricEvaluation(
                name: "ordering_accuracy",
                value: orderingAccuracy,
                targetDescription: ">= \(targets.minimumOrderingAccuracy)",
                meetsTarget: orderingAccuracy >= targets.minimumOrderingAccuracy
            )
        ]

        let hashes = [
            GoldenSHAObservation(
                artifact: "video",
                expectedSHA256: groundTruth.expectedVideoSHA256,
                observedSHA256: observedHashes.videoSHA256
            ),
            GoldenSHAObservation(
                artifact: "pdf",
                expectedSHA256: groundTruth.expectedPDFSHA256,
                observedSHA256: observedHashes.pdfSHA256
            )
        ]

        return GoldenEvaluationReport(
            generatedAtISO8601: iso8601(generatedAt),
            expectedPageCount: expectedIDs.count,
            observedCorrectedPageCount: correctedPages.count,
            pageRecall: pageRecall,
            transitionAcceptedCount: transitionAcceptedCount,
            duplicateRate: duplicateRate,
            orderingAccuracy: orderingAccuracy,
            duplicateGroupCount: auditResult.duplicateGroups.count,
            reviewRequiredCount: auditResult.reviewRequired.count,
            metricEvaluations: metrics,
            shaObservations: hashes
        )
    }

    public static func jsonData(_ report: GoldenEvaluationReport, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(report)
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
