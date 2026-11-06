import Foundation

public enum Lane3DeviceEvidenceAW13AdapterError: Error, Equatable, Sendable {
    case unifiedEvidenceNotReviewReady
}

public extension Lane3DeviceEvidenceCaseReceipt {
    init(
        aw13 unifiedEvidence: Lane3UnifiedEvidenceReportV2,
        scenario: Lane3DeviceEvidenceScenario,
        candidateCaptureSHA256: String,
        currentMoisesCaptureSHA256: String,
        repetitionsCompleted: Int,
        successfulRepetitions: Int,
        observedDurationSeconds: Double,
        realAudio: Bool,
        rightsClearedFixture: Bool,
        currentMoisesCompared: Bool,
        timing: Lane3DeviceEvidenceTimingSummary,
        health: Lane3DeviceEvidenceRuntimeHealth
    ) throws {
        guard unifiedEvidence.schemaVersion == 2,
              unifiedEvidence.evidenceScope == "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY",
              unifiedEvidence.readyForRealAudioReview,
              !unifiedEvidence.humanAudibilityClaimed,
              !unifiedEvidence.standardizedPerceptualMetricClaimed,
              !unifiedEvidence.formantPreservationClaimed,
              !unifiedEvidence.parityPromotionAllowed else {
            throw Lane3DeviceEvidenceAW13AdapterError.unifiedEvidenceNotReviewReady
        }
        self.init(
            scenario: scenario,
            fixtureID: unifiedEvidence.fixtureID,
            controlSignatureFNV1A64: unifiedEvidence.controlSignatureFNV1A64,
            aw13RunBindingSHA256: unifiedEvidence.runBindingSHA256,
            candidateCaptureSHA256: candidateCaptureSHA256,
            currentMoisesCaptureSHA256: currentMoisesCaptureSHA256,
            repetitionsCompleted: repetitionsCompleted,
            successfulRepetitions: successfulRepetitions,
            observedDurationSeconds: observedDurationSeconds,
            realAudio: realAudio,
            rightsClearedFixture: rightsClearedFixture,
            currentMoisesCompared: currentMoisesCompared,
            timing: timing,
            health: health
        )
    }
}
