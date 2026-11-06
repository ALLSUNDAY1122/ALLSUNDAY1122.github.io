import Foundation

public enum AnalysisAnalysisParityCanonicalGateError: Error, Equatable, Sendable {
    case manifestDecodeFailed
    case manifestNotCanonical
    case manifestDigestMismatch
}

/// Production byte-entry gate for W46.
///
/// `AnalysisRealAudioParityAdjudicator.adjudicate` operates on an already
/// decoded manifest and is useful for composition/testing. HQ production use
/// should enter here so the manifest SHA is derived from the exact retained
/// canonical bytes rather than supplied independently by the caller.
public enum AnalysisRealAudioParityCanonicalAdjudicator {
    public static func adjudicate(
        manifestBytes: Data,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        projectReport: AnalysisAuditedRealAudioBenchmarkReport,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        binding: AnalysisAnalysisParityEvidenceBinding,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        evaluatedAt: Date = Date()
    ) throws -> AnalysisAnalysisParityAdjudicationReport {
        let manifest: AnalysisRealAudioBenchmarkManifest
        do {
            manifest = try AnalysisRealAudioBenchmarkCodec.decodeManifest(manifestBytes)
        } catch {
            throw AnalysisAnalysisParityCanonicalGateError.manifestDecodeFailed
        }

        let canonicalBytes: Data
        do {
            canonicalBytes = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
        } catch {
            throw AnalysisAnalysisParityCanonicalGateError.manifestDecodeFailed
        }
        guard canonicalBytes == manifestBytes else {
            throw AnalysisAnalysisParityCanonicalGateError.manifestNotCanonical
        }

        let digest = AnalysisDeviceWorkloadSHA256.hexDigest(manifestBytes)
        guard digest == binding.manifestSHA256.lowercased() else {
            throw AnalysisAnalysisParityCanonicalGateError.manifestDigestMismatch
        }

        return try AnalysisRealAudioParityAdjudicator.adjudicate(
            manifest: manifest,
            manifestSHA256: digest,
            coveragePolicy: coveragePolicy,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            projectReport: projectReport,
            toleranceProfile: toleranceProfile,
            binding: binding,
            configuration: configuration,
            evaluatedAt: evaluatedAt
        )
    }
}
