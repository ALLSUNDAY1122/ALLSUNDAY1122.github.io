import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisChordBackendEquivalenceGuardTests: XCTestCase {
    private let evidence = AnalysisChordSpectrumEvidence(
        chroma: [0.10, 0.02, 0.03, 0.12, 0.19, 0.02, 0.01, 0.18, 0.02, 0.12, 0.03, 0.01],
        bassPitchClass: 0,
        bassDominance: 0.24
    )

    func testEightExactVerificationFramesPromoteOnlyFutureFrames() {
        var guardState = AnalysisChordBackendEquivalenceGuard()
        for index in 1...AnalysisChordBackendEquivalenceGuard.verificationFrameLimit {
            let decision = guardState.resolveVerification(
                referenceEvidence: evidence,
                vectorizedEvidence: evidence,
                referenceDecision: ("C", 0.81),
                vectorizedDecision: ("C", 0.81)
            )
            XCTAssertEqual(decision.label, "C")
            XCTAssertEqual(decision.confidence, 0.81)
            XCTAssertEqual(guardState.diagnostics.referencePublicationCount, index)
            XCTAssertEqual(guardState.diagnostics.vectorizedPublicationCount, 0)
        }
        XCTAssertEqual(guardState.state, .vectorizedVerified)
        XCTAssertEqual(guardState.diagnostics.verificationMatches, 8)
        guardState.recordVectorizedPublication()
        XCTAssertEqual(guardState.diagnostics.referencePublicationCount, 8)
        XCTAssertEqual(guardState.diagnostics.vectorizedPublicationCount, 1)
    }

    func testEvidenceMismatchFallsBackOnCurrentFrameAndPersists() {
        var guardState = AnalysisChordBackendEquivalenceGuard()
        _ = guardState.resolveVerification(
            referenceEvidence: evidence,
            vectorizedEvidence: evidence,
            referenceDecision: ("C", 0.81),
            vectorizedDecision: ("C", 0.81)
        )
        var changedChroma = evidence.chroma
        changedChroma[4] = changedChroma[4].nextUp
        let changed = AnalysisChordSpectrumEvidence(
            chroma: changedChroma,
            bassPitchClass: evidence.bassPitchClass,
            bassDominance: evidence.bassDominance
        )
        let published = guardState.resolveVerification(
            referenceEvidence: evidence,
            vectorizedEvidence: changed,
            referenceDecision: ("C", 0.81),
            vectorizedDecision: ("C", 0.81)
        )
        XCTAssertEqual(published.label, "C")
        XCTAssertEqual(guardState.state, .scalarFallback)
        XCTAssertTrue(guardState.diagnostics.fallbackTriggered)
        XCTAssertEqual(guardState.diagnostics.fallbackComparisonIndex, 2)
        XCTAssertEqual(guardState.diagnostics.mismatchCount, 1)
        XCTAssertEqual(guardState.diagnostics.referencePublicationCount, 2)
        XCTAssertEqual(guardState.diagnostics.vectorizedPublicationCount, 0)

        guardState.recordReferencePublication()
        guardState.recordReferencePublication()
        XCTAssertEqual(guardState.state, .scalarFallback)
        XCTAssertEqual(guardState.diagnostics.referencePublicationCount, 4)
        XCTAssertEqual(guardState.diagnostics.vectorizedPublicationCount, 0)
    }

    func testDecisionMismatchAloneTriggersFallback() {
        var guardState = AnalysisChordBackendEquivalenceGuard()
        _ = guardState.resolveVerification(
            referenceEvidence: evidence,
            vectorizedEvidence: evidence,
            referenceDecision: ("C", 0.81),
            vectorizedDecision: ("C:min", 0.81)
        )
        XCTAssertEqual(guardState.state, .scalarFallback)
        XCTAssertEqual(guardState.diagnostics.fallbackComparisonIndex, 1)
    }

    func testBitExactComparisonRejectsSignedZeroDifference() {
        let positiveZero = AnalysisChordSpectrumEvidence(
            chroma: [0.0] + Array(repeating: 1.0, count: 11),
            bassPitchClass: nil,
            bassDominance: 0
        )
        let negativeZero = AnalysisChordSpectrumEvidence(
            chroma: [-0.0] + Array(repeating: 1.0, count: 11),
            bassPitchClass: nil,
            bassDominance: 0
        )
        XCTAssertFalse(
            AnalysisChordBackendEquivalenceGuard.evidenceBitExactlyMatches(
                positiveZero,
                negativeZero
            )
        )
    }

    func testNoChordFramesDoNotConsumeVerificationBudget() {
        let configuration = MusicAnalysisConfiguration(noChordRMS: 0.5)
        let sampleRate = 8_000.0
        let sampleCount = 5_600
        let quiet = Array(repeating: 0.001, count: sampleCount)
        var workspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: sampleRate,
            windowSampleCount: sampleCount
        )
        for _ in 0..<20 {
            let decision = AnalysisReusableChordFrameClassifier.classify(
                samples: quiet,
                workspace: &workspace,
                sampleRate: sampleRate,
                configuration: configuration
            )
            XCTAssertEqual(decision.label, "N")
        }
        XCTAssertEqual(workspace.backendGuardDiagnostics.state, .verifying)
        XCTAssertEqual(workspace.backendGuardDiagnostics.verificationComparisons, 0)
        XCTAssertEqual(workspace.classificationCount, 0)
    }

    func testRealClassifierPromotesThenUsesVectorizedPublication() {
        let configuration = MusicAnalysisConfiguration(
            minimumChordConfidence: 0.02,
            minimumChordTemplateScore: 0.40
        )
        let sampleRate = 8_000.0
        let sampleCount = 5_600
        let samples = (0..<sampleCount).map { index -> Double in
            let time = Double(index) / sampleRate
            return 0.12 * sin(2 * Double.pi * 261.6256 * time)
                + 0.10 * sin(2 * Double.pi * 329.6276 * time)
                + 0.08 * sin(2 * Double.pi * 391.9954 * time)
        }
        var workspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: sampleRate,
            windowSampleCount: sampleCount
        )
        let legacy = ChordFrameClassifier.classify(
            samples: samples,
            sampleRate: sampleRate,
            configuration: configuration
        )
        for _ in 0..<10 {
            let guarded = AnalysisReusableChordFrameClassifier.classify(
                samples: samples,
                workspace: &workspace,
                sampleRate: sampleRate,
                configuration: configuration
            )
            XCTAssertEqual(guarded.label, legacy.label)
            XCTAssertEqual(guarded.confidence, legacy.confidence)
        }
        let diagnostics = workspace.backendGuardDiagnostics
        XCTAssertEqual(diagnostics.state, .vectorizedVerified)
        XCTAssertEqual(diagnostics.verificationComparisons, 8)
        XCTAssertEqual(diagnostics.verificationMatches, 8)
        XCTAssertEqual(diagnostics.referencePublicationCount, 8)
        XCTAssertEqual(diagnostics.vectorizedPublicationCount, 2)
        XCTAssertFalse(diagnostics.fallbackTriggered)
    }

    func testPreparedDiagnosticsRoundTripPersistsGuardState() throws {
        let diagnostics = AnalysisSinglePassPreparedFeatureDiagnostics(
            preparedSampleCount: 8_000,
            preparedSampleRequests: 8_000,
            preparedSampleComputations: 8_000,
            preparedBlockLoads: 2,
            tempoOnsetCount: 100,
            keyWindowCount: 2,
            keyWindowSampleCount: 4_096,
            chordFrameDecisionCount: 40,
            sectionEnergyFrameCount: 100,
            maximumTempoRingSamples: 368,
            maximumChordRingSamples: 5_600,
            estimatedRetainedFeatureBytes: 123_456,
            exactSinglePreparedTraversal: true,
            chordBackendGuardState: AnalysisChordBackendGuardState.scalarFallback.rawValue,
            chordBackendVerificationFrameLimit: 8,
            chordBackendVerificationComparisons: 3,
            chordBackendVerificationMatches: 2,
            chordBackendFallbackTriggered: true,
            chordBackendFallbackComparisonIndex: 3,
            chordBackendReferencePublicationCount: 40,
            chordBackendVectorizedPublicationCount: 0
        )
        let encoded = try JSONEncoder().encode(diagnostics)
        let decoded = try JSONDecoder().decode(
            AnalysisSinglePassPreparedFeatureDiagnostics.self,
            from: encoded
        )
        XCTAssertEqual(decoded, diagnostics)
    }

    func testLegacyPreparedDiagnosticsDecodeUsesFailSafeGuardDefaults() throws {
        let json = """
        {
          "preparedSampleCount": 100,
          "preparedSampleRequests": 100,
          "preparedSampleComputations": 100,
          "preparedBlockLoads": 1,
          "tempoOnsetCount": 1,
          "keyWindowCount": 1,
          "keyWindowSampleCount": 100,
          "chordFrameDecisionCount": 1,
          "sectionEnergyFrameCount": 1,
          "maximumTempoRingSamples": 100,
          "maximumChordRingSamples": 100,
          "estimatedRetainedFeatureBytes": 1000,
          "exactSinglePreparedTraversal": true
        }
        """
        let decoded = try JSONDecoder().decode(
            AnalysisSinglePassPreparedFeatureDiagnostics.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(decoded.chordBackendGuardState, "verifying")
        XCTAssertEqual(decoded.chordBackendVerificationComparisons, 0)
        XCTAssertEqual(decoded.chordBackendReferencePublicationCount, 0)
        XCTAssertEqual(decoded.chordBackendVectorizedPublicationCount, 0)
        XCTAssertFalse(decoded.chordBackendFallbackTriggered)
    }
}
