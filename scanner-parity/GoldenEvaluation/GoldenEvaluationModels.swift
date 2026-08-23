import Foundation

public struct GoldenGroundTruth: Codable, Equatable, Sendable {
    public let expectedPageIDs: [String]
    public let transitionCandidateIDs: Set<String>
    public let expectedVideoSHA256: String?
    public let expectedPDFSHA256: String?

    public init(
        expectedPageIDs: [String],
        transitionCandidateIDs: Set<String> = [],
        expectedVideoSHA256: String? = nil,
        expectedPDFSHA256: String? = nil
    ) {
        self.expectedPageIDs = expectedPageIDs
        self.transitionCandidateIDs = transitionCandidateIDs
        self.expectedVideoSHA256 = expectedVideoSHA256
        self.expectedPDFSHA256 = expectedPDFSHA256
    }
}

public struct GoldenObservedHashes: Codable, Equatable, Sendable {
    public let videoSHA256: String?
    public let pdfSHA256: String?

    public init(videoSHA256: String? = nil, pdfSHA256: String? = nil) {
        self.videoSHA256 = videoSHA256
        self.pdfSHA256 = pdfSHA256
    }
}

public struct GoldenMetricTargets: Codable, Equatable, Sendable {
    public var minimumPageRecall: Double
    public var maximumTransitionAccepted: Int
    public var maximumDuplicateRate: Double
    public var minimumOrderingAccuracy: Double

    public init(
        minimumPageRecall: Double = 0.99,
        maximumTransitionAccepted: Int = 0,
        maximumDuplicateRate: Double = 0.005,
        minimumOrderingAccuracy: Double = 1.0
    ) {
        self.minimumPageRecall = minimumPageRecall
        self.maximumTransitionAccepted = maximumTransitionAccepted
        self.maximumDuplicateRate = maximumDuplicateRate
        self.minimumOrderingAccuracy = minimumOrderingAccuracy
    }
}

public struct GoldenMetricEvaluation: Codable, Equatable, Sendable {
    public let name: String
    public let value: Double
    public let targetDescription: String
    public let meetsTarget: Bool

    public init(name: String, value: Double, targetDescription: String, meetsTarget: Bool) {
        self.name = name
        self.value = value
        self.targetDescription = targetDescription
        self.meetsTarget = meetsTarget
    }
}

public struct GoldenSHAObservation: Codable, Equatable, Sendable {
    public let artifact: String
    public let expectedSHA256: String?
    public let observedSHA256: String?
    public let matchesExpected: Bool?
    public let ownership: String

    public init(artifact: String, expectedSHA256: String?, observedSHA256: String?) {
        self.artifact = artifact
        self.expectedSHA256 = expectedSHA256
        self.observedSHA256 = observedSHA256
        if let expectedSHA256, let observedSHA256 {
            self.matchesExpected = expectedSHA256.caseInsensitiveCompare(observedSHA256) == .orderedSame
        } else {
            self.matchesExpected = nil
        }
        self.ownership = "HQ_ONLY"
    }
}

public struct GoldenEvaluationReport: Codable, Equatable, Sendable {
    public let generatedAtISO8601: String
    public let expectedPageCount: Int
    public let observedCorrectedPageCount: Int
    public let pageRecall: Double
    public let transitionAcceptedCount: Int
    public let duplicateRate: Double
    public let orderingAccuracy: Double
    public let duplicateGroupCount: Int
    public let reviewRequiredCount: Int
    public let metricEvaluations: [GoldenMetricEvaluation]
    public let shaObservations: [GoldenSHAObservation]
    public let workerGoldenVerdict: String

    public init(
        generatedAtISO8601: String,
        expectedPageCount: Int,
        observedCorrectedPageCount: Int,
        pageRecall: Double,
        transitionAcceptedCount: Int,
        duplicateRate: Double,
        orderingAccuracy: Double,
        duplicateGroupCount: Int,
        reviewRequiredCount: Int,
        metricEvaluations: [GoldenMetricEvaluation],
        shaObservations: [GoldenSHAObservation]
    ) {
        self.generatedAtISO8601 = generatedAtISO8601
        self.expectedPageCount = expectedPageCount
        self.observedCorrectedPageCount = observedCorrectedPageCount
        self.pageRecall = pageRecall
        self.transitionAcceptedCount = transitionAcceptedCount
        self.duplicateRate = duplicateRate
        self.orderingAccuracy = orderingAccuracy
        self.duplicateGroupCount = duplicateGroupCount
        self.reviewRequiredCount = reviewRequiredCount
        self.metricEvaluations = metricEvaluations
        self.shaObservations = shaObservations
        self.workerGoldenVerdict = "NOT_ISSUED_HQ_GOLDEN_GATE_ONLY"
    }
}
