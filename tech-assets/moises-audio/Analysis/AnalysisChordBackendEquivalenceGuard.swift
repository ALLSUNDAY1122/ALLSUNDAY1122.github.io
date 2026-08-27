import Foundation

enum AnalysisChordBackendGuardState: String, Codable, Equatable, Sendable {
    case verifying
    case vectorizedVerified
    case scalarFallback
}

struct AnalysisChordBackendGuardDiagnostics: Codable, Equatable, Sendable {
    let state: AnalysisChordBackendGuardState
    let verificationFrameLimit: Int
    let verificationComparisons: Int
    let verificationMatches: Int
    let mismatchCount: Int
    let fallbackComparisonIndex: Int?
    let referencePublicationCount: Int
    let vectorizedPublicationCount: Int

    var fallbackTriggered: Bool { state == .scalarFallback }
}

struct AnalysisChordBackendEquivalenceGuard {
    /// Resource-safety verification count only. This is not a musical-quality or
    /// PARITY threshold. Verification consumes actual non-no-chord frames.
    static let verificationFrameLimit = 8

    private(set) var state: AnalysisChordBackendGuardState = .verifying
    private(set) var verificationComparisons = 0
    private(set) var verificationMatches = 0
    private(set) var mismatchCount = 0
    private(set) var fallbackComparisonIndex: Int?
    private(set) var referencePublicationCount = 0
    private(set) var vectorizedPublicationCount = 0

    var diagnostics: AnalysisChordBackendGuardDiagnostics {
        .init(
            state: state,
            verificationFrameLimit: Self.verificationFrameLimit,
            verificationComparisons: verificationComparisons,
            verificationMatches: verificationMatches,
            mismatchCount: mismatchCount,
            fallbackComparisonIndex: fallbackComparisonIndex,
            referencePublicationCount: referencePublicationCount,
            vectorizedPublicationCount: vectorizedPublicationCount
        )
    }

    mutating func resolveVerification(
        referenceEvidence: AnalysisChordSpectrumEvidence,
        vectorizedEvidence: AnalysisChordSpectrumEvidence,
        referenceDecision: (label: String, confidence: Double?),
        vectorizedDecision: (label: String, confidence: Double?)
    ) -> (label: String, confidence: Double?) {
        precondition(state == .verifying)
        verificationComparisons += 1
        referencePublicationCount += 1

        let evidenceMatches = Self.evidenceBitExactlyMatches(
            referenceEvidence,
            vectorizedEvidence
        )
        let decisionMatches = Self.decisionBitExactlyMatches(
            referenceDecision,
            vectorizedDecision
        )
        guard evidenceMatches && decisionMatches else {
            mismatchCount += 1
            fallbackComparisonIndex = fallbackComparisonIndex ?? verificationComparisons
            state = .scalarFallback
            return referenceDecision
        }

        verificationMatches += 1
        if verificationMatches >= Self.verificationFrameLimit {
            state = .vectorizedVerified
        }

        // Never publish an optimized result before the backend has completed the
        // bounded verification sequence. Even the final verification frame uses
        // the reference result; vectorized publication starts on the next frame.
        return referenceDecision
    }

    mutating func recordReferencePublication() {
        precondition(state == .scalarFallback)
        referencePublicationCount += 1
    }

    mutating func recordVectorizedPublication() {
        precondition(state == .vectorizedVerified)
        vectorizedPublicationCount += 1
    }

    static func evidenceBitExactlyMatches(
        _ lhs: AnalysisChordSpectrumEvidence,
        _ rhs: AnalysisChordSpectrumEvidence
    ) -> Bool {
        guard lhs.bassPitchClass == rhs.bassPitchClass,
              lhs.chroma.count == rhs.chroma.count,
              lhs.bassDominance.bitPattern == rhs.bassDominance.bitPattern else {
            return false
        }
        for index in lhs.chroma.indices {
            guard lhs.chroma[index].bitPattern == rhs.chroma[index].bitPattern else {
                return false
            }
        }
        return true
    }

    static func decisionBitExactlyMatches(
        _ lhs: (label: String, confidence: Double?),
        _ rhs: (label: String, confidence: Double?)
    ) -> Bool {
        guard lhs.label == rhs.label else { return false }
        switch (lhs.confidence, rhs.confidence) {
        case (nil, nil):
            return true
        case let (.some(left), .some(right)):
            return left.bitPattern == right.bitPattern
        default:
            return false
        }
    }
}
