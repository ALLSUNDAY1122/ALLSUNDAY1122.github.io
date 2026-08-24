import Foundation

enum AnalysisPhysicalEvidenceArchiveContentValidator {
    static func validate(
        entries: [AnalysisPhysicalEvidenceArchiveEntry],
        bytesByPath: [String: Data],
        policy: AnalysisPhysicalEvidenceArchivePolicy,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        issues: inout [AnalysisPhysicalEvidenceArchiveIssue]
    ) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let plannedByID = firstPlannedByRunID(performanceProfile.plannedRuns)
        for entry in entries {
            guard let bytes = bytesByPath[entry.relativePath] else { continue }
            do {
                switch entry.role {
                case .goldenManifest:
                    let value = try decoder.decode(AnalysisRealAudioBenchmarkManifest.self, from: bytes)
                    if value.manifestID != policy.binding.manifestID || entry.sha256 != policy.binding.manifestSHA256 {
                        throw ContentMismatch("golden manifest ID or exact byte SHA does not match the archive binding")
                    }
                case .w22CoveragePolicy:
                    let value = try decoder.decode(AnalysisCorpusCoveragePolicy.self, from: bytes)
                    if value != coveragePolicy { throw ContentMismatch("archived W22 coverage policy differs from the canonical policy supplied to W27") }
                case .w22CoverageReport:
                    let value = try decoder.decode(AnalysisCorpusCoverageReport.self, from: bytes)
                    if value.policyID != coveragePolicy.policyID || value.manifestID != policy.binding.manifestID || value.manifestSHA256 != policy.binding.manifestSHA256 {
                        throw ContentMismatch("W22 report binding does not match archive policy")
                    }
                case .w26SelectionPolicy:
                    let value = try decoder.decode(AnalysisDeviceCorpusSelectionPolicy.self, from: bytes)
                    if value != selectionPolicy { throw ContentMismatch("archived W26 selection policy differs from the canonical selection policy supplied to W27") }
                case .w26SelectionReport:
                    let value = try decoder.decode(AnalysisDeviceCorpusSelectionReport.self, from: bytes)
                    if value.policyID != selectionPolicy.policyID || value.coveragePolicyID != coveragePolicy.policyID || value.manifestID != policy.binding.manifestID || value.manifestSHA256 != policy.binding.manifestSHA256 {
                        throw ContentMismatch("W26 report binding does not match archive policy")
                    }
                case .w24PerformanceProfile:
                    let value = try decoder.decode(AnalysisDevicePerformanceAcceptanceProfile.self, from: bytes)
                    if value != performanceProfile { throw ContentMismatch("archived W24 performance profile differs from the canonical profile supplied to W27") }
                case .w24PerformanceBatch:
                    let value = try decoder.decode(AnalysisDevicePerformanceEvidenceBatch.self, from: bytes)
                    let runIDs = value.runs.map { $0.provenance.runID }
                    if value.batchID != policy.binding.batchID || value.profileID != policy.binding.performanceProfileID || Set(runIDs) != Set(policy.requiredRunIDs) || runIDs.count != policy.requiredRunIDs.count {
                        throw ContentMismatch("W24 batch identifiers/run inventory do not match the archive policy")
                    }
                case .w24AcceptanceReport:
                    let value = try decoder.decode(AnalysisDevicePerformanceAcceptanceReport.self, from: bytes)
                    if value.profileID != policy.binding.performanceProfileID || value.batchID != policy.binding.batchID {
                        throw ContentMismatch("W24 acceptance report is bound to a different profile/batch")
                    }
                case .w25WorkloadPolicy:
                    let value = try decoder.decode(AnalysisDeviceWorkloadPolicy.self, from: bytes)
                    if value != workloadPolicy { throw ContentMismatch("archived W25 workload policy differs from the canonical policy supplied to W27") }
                case .buildCorroboration:
                    let value = try decoder.decode(AnalysisPhysicalEvidenceBuildCorroboration.self, from: bytes)
                    if value.schemaVersion != 1 || value.buildIdentity != policy.binding.buildIdentity || value.appBundleIdentifier != performanceProfile.expectedAppBundleIdentifier || value.appVersion != performanceProfile.expectedAppVersion || value.buildVersion != performanceProfile.expectedBuildVersion || trimmed(value.sourceRevision).isEmpty || (value.buildArtifactSHA256 != nil && !isSHA256(value.buildArtifactSHA256!)) {
                        throw ContentMismatch("build corroboration does not match W24/W25 build identity")
                    }
                case .deviceCorroboration:
                    let value = try decoder.decode(AnalysisPhysicalEvidenceDeviceCorroboration.self, from: bytes)
                    if value.schemaVersion != 1 || value.runtimeClass != .physicalIOSDevice || value.deviceModel != policy.binding.deviceModel || value.osVersion != policy.binding.osVersion || trimmed(value.captureSessionID).isEmpty || trimmed(value.evidenceMethod).isEmpty {
                        throw ContentMismatch("device corroboration does not match the approved physical-device binding")
                    }
                case .w23RawTelemetry:
                    let value = try decoder.decode(AnalysisDevicePerformanceEvidence.self, from: bytes)
                    guard let runID = entry.runID, let planned = plannedByID[runID] else { throw ContentMismatch("W23 telemetry entry has no approved run") }
                    if value.provenance.runID != runID || value.provenance.runKind != planned.runKind || value.provenance.fixtureID != planned.fixtureID || value.provenance.manifestID != policy.binding.manifestID || value.provenance.manifestSHA256 != policy.binding.manifestSHA256 || value.provenance.runtimeClass != .physicalIOSDevice || value.provenance.deviceModel != policy.binding.deviceModel || value.provenance.osVersion != policy.binding.osVersion || value.provenance.buildVersion != performanceProfile.expectedBuildVersion {
                        throw ContentMismatch("W23 telemetry does not match run/fixture/device/build/manifest binding")
                    }
                case .w23ValidationReport:
                    let value = try decoder.decode(AnalysisDevicePerformanceValidationReport.self, from: bytes)
                    if value.runID != entry.runID { throw ContentMismatch("W23 validation report run ID mismatch") }
                case .w25WorkloadReceipt:
                    let value = try decoder.decode(AnalysisDeviceWorkloadReceipt.self, from: bytes)
                    guard let runID = entry.runID, let planned = plannedByID[runID] else { throw ContentMismatch("W25 receipt entry has no approved run") }
                    if value.runID != runID || value.performanceEvidenceRunID != runID || value.runKind != planned.runKind || value.source.fixtureID != planned.fixtureID || value.manifestID != policy.binding.manifestID || value.manifestSHA256 != policy.binding.manifestSHA256 || value.identity != workloadPolicy.identity {
                        throw ContentMismatch("W25 workload receipt does not match run/fixture/manifest/analyzer binding")
                    }
                case .w25WorkloadValidationReport:
                    let value = try decoder.decode(AnalysisDeviceWorkloadValidationReport.self, from: bytes)
                    if value.runID != entry.runID { throw ContentMismatch("W25 validation report run ID mismatch") }
                }
            } catch {
                issues.append(.init(
                    code: .artifactContentMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID,
                    detail: "artifact cannot be decoded/cross-bound for its declared role: \(error)"
                ))
            }
        }
    }

    private struct ContentMismatch: Error, CustomStringConvertible {
        let message: String
        init(_ message: String) { self.message = message }
        var description: String { message }
    }

    private static func firstPlannedByRunID(_ values: [AnalysisDevicePerformancePlannedRun]) -> [String: AnalysisDevicePerformancePlannedRun] {
        var out: [String: AnalysisDevicePerformancePlannedRun] = [:]
        for value in values where out[value.runID] == nil { out[value.runID] = value }
        return out
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102: return true
            default: return false
            }
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
