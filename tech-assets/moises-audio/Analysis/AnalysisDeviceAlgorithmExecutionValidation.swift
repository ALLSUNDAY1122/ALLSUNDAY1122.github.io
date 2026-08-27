import Foundation

public enum AnalysisDeviceAlgorithmEvidenceIssueCode: String, Codable, Hashable, Sendable {
    case invalidBatch = "INVALID_ALGORITHM_EVIDENCE_BATCH"
    case duplicateRunID = "DUPLICATE_ALGORITHM_RUN_ID"
    case missingRun = "MISSING_ALGORITHM_RUN_EVIDENCE"
    case unexpectedRun = "UNEXPECTED_ALGORITHM_RUN_EVIDENCE"
    case bindingMismatch = "ALGORITHM_EVIDENCE_BINDING_MISMATCH"
    case invalidCaptureState = "INVALID_ALGORITHM_CAPTURE_STATE"
    case missingFinalRuntimeIdentity = "MISSING_FINAL_RUNTIME_IDENTITY"
    case nonCurrentRuntimePath = "NON_CURRENT_ANALYSIS_RUNTIME_PATH"
    case invalidRuntimeIdentity = "INVALID_RUNTIME_IDENTITY"
    case runtimeIdentityHashMismatch = "RUNTIME_IDENTITY_HASH_MISMATCH"
    case mixedCompleteRuntimeIdentity = "MIXED_COMPLETE_RUNTIME_IDENTITY_WITHIN_FIXTURE"
}

public struct AnalysisDeviceAlgorithmEvidenceIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDeviceAlgorithmEvidenceIssueCode
    public let fixtureID: String?
    public let runID: String?
    public let detail: String

    public init(code: AnalysisDeviceAlgorithmEvidenceIssueCode, fixtureID: String? = nil, runID: String? = nil, detail: String) {
        self.code = code
        self.fixtureID = fixtureID
        self.runID = runID
        self.detail = detail
    }
}

public enum AnalysisDeviceAlgorithmRunEvidenceStatus: String, Codable, Sendable {
    case invalid = "INVALID_ALGORITHM_RUN_EVIDENCE"
    case completeRuntimeBoundPendingHQ = "COMPLETE_RUNTIME_BOUND_PENDING_HQ"
    case cancellationBoundPendingHQ = "CANCELLATION_BOUND_PENDING_HQ"
}

public struct AnalysisDeviceAlgorithmRunEvidenceReport: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let status: AnalysisDeviceAlgorithmRunEvidenceStatus
    public let runtimeIdentitySHA256: String?
    public let issues: [AnalysisDeviceAlgorithmEvidenceIssue]
}

public struct AnalysisDeviceAlgorithmEvidenceBatchReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let batchID: String
    public let valid: Bool
    public let exactRunInventory: Bool
    public let runReports: [AnalysisDeviceAlgorithmRunEvidenceReport]
    public let issues: [AnalysisDeviceAlgorithmEvidenceIssue]
}

public enum AnalysisDeviceAlgorithmEvidenceValidator {
    public static func validateBatch(
        algorithmBatch: AnalysisDeviceAlgorithmEvidenceBatch,
        performanceBatch: AnalysisDevicePerformanceEvidenceBatch,
        receipts: [AnalysisDeviceWorkloadReceipt],
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile
    ) -> AnalysisDeviceAlgorithmEvidenceBatchReport {
        var batchIssues: [AnalysisDeviceAlgorithmEvidenceIssue] = []
        guard algorithmBatch.schemaVersion == 1,
              algorithmBatch.batchID == performanceBatch.batchID,
              algorithmBatch.batchID == performanceProfile.expectedBatchID,
              algorithmBatch.performanceProfileID == performanceBatch.profileID,
              algorithmBatch.performanceProfileID == performanceProfile.profileID else {
            batchIssues.append(.init(code: .invalidBatch, detail: "algorithm batch must use schema 1 and match the exact W23/W24 batch/profile identifiers"))
            return .init(schemaVersion: 1, batchID: algorithmBatch.batchID, valid: false, exactRunInventory: false, runReports: [], issues: batchIssues)
        }

        let planned = uniqueByRun(performanceProfile.plannedRuns)
        let performance = uniquePerformanceByRun(performanceBatch.runs)
        let receiptMap = uniqueReceiptByRun(receipts)
        let algorithm = uniqueAlgorithmByRun(algorithmBatch.runs)

        appendDuplicateIssues(performanceProfile.plannedRuns.map(\.runID), code: .duplicateRunID, detail: "duplicate W24 planned run ID", into: &batchIssues)
        appendDuplicateIssues(performanceBatch.runs.map { $0.provenance.runID }, code: .duplicateRunID, detail: "duplicate W23 performance run ID", into: &batchIssues)
        appendDuplicateIssues(receipts.map(\.runID), code: .duplicateRunID, detail: "duplicate W25 receipt run ID", into: &batchIssues)
        appendDuplicateIssues(algorithmBatch.runs.map(\.runID), code: .duplicateRunID, detail: "duplicate W35 algorithm evidence run ID", into: &batchIssues)

        let expectedIDs = Set(planned.keys)
        let performanceIDs = Set(performance.keys)
        let receiptIDs = Set(receiptMap.keys)
        let algorithmIDs = Set(algorithm.keys)
        let inventories = [performanceIDs, receiptIDs, algorithmIDs]
        for id in expectedIDs.subtracting(performanceIDs).sorted() {
            batchIssues.append(.init(code: .missingRun, fixtureID: planned[id]?.fixtureID, runID: id, detail: "predeclared run lacks W23 performance evidence"))
        }
        for id in expectedIDs.subtracting(receiptIDs).sorted() {
            batchIssues.append(.init(code: .missingRun, fixtureID: planned[id]?.fixtureID, runID: id, detail: "predeclared run lacks W25 workload receipt"))
        }
        for id in expectedIDs.subtracting(algorithmIDs).sorted() {
            batchIssues.append(.init(code: .missingRun, fixtureID: planned[id]?.fixtureID, runID: id, detail: "predeclared run lacks W35 algorithm evidence"))
        }
        for id in performanceIDs.subtracting(expectedIDs).sorted() {
            batchIssues.append(.init(code: .unexpectedRun, runID: id, detail: "W23 performance run was not predeclared by W24"))
        }
        for id in receiptIDs.subtracting(expectedIDs).sorted() {
            batchIssues.append(.init(code: .unexpectedRun, runID: id, detail: "W25 receipt run was not predeclared by W24"))
        }
        for id in algorithmIDs.subtracting(expectedIDs).sorted() {
            batchIssues.append(.init(code: .unexpectedRun, runID: id, detail: "W35 algorithm evidence run was not predeclared by W24"))
        }
        let exactInventory = batchIssues.allSatisfy { ![.duplicateRunID, .missingRun, .unexpectedRun].contains($0.code) }
            && inventories.allSatisfy { $0 == expectedIDs }
            && performanceBatch.runs.count == expectedIDs.count
            && receipts.count == expectedIDs.count
            && algorithmBatch.runs.count == expectedIDs.count

        var reports: [AnalysisDeviceAlgorithmRunEvidenceReport] = []
        for id in expectedIDs.sorted() {
            guard let p = planned[id], let perf = performance[id], let receipt = receiptMap[id], let evidence = algorithm[id] else { continue }
            var issues: [AnalysisDeviceAlgorithmEvidenceIssue] = []
            validateBindings(evidence, p, perf, receipt, workloadPolicy, performanceProfile, &issues)
            validateCapture(evidence, receipt, p, &issues)
            let status: AnalysisDeviceAlgorithmRunEvidenceStatus
            if !issues.isEmpty {
                status = .invalid
            } else if p.runKind == .completeAnalysis {
                status = .completeRuntimeBoundPendingHQ
            } else {
                status = .cancellationBoundPendingHQ
            }
            reports.append(.init(runID: id, fixtureID: p.fixtureID, status: status, runtimeIdentitySHA256: evidence.runtimeIdentitySHA256, issues: issues))
        }

        for fixtureID in performanceProfile.requiredFixtureIDs.sorted() {
            let hashes = Set(reports.filter { $0.fixtureID == fixtureID && $0.status == .completeRuntimeBoundPendingHQ }.compactMap(\.runtimeIdentitySHA256))
            let expectedComplete = performanceProfile.plannedRuns.filter { $0.fixtureID == fixtureID && $0.runKind == .completeAnalysis }.count
            let validComplete = reports.filter { $0.fixtureID == fixtureID && $0.status == .completeRuntimeBoundPendingHQ }.count
            if validComplete == expectedComplete && hashes.count > 1 {
                batchIssues.append(.init(code: .mixedCompleteRuntimeIdentity, fixtureID: fixtureID, detail: "repeated complete runs for one fixture executed different W31-W34 runtime identities"))
            }
        }

        let allRunIssues = reports.flatMap(\.issues)
        let valid = exactInventory && batchIssues.isEmpty && allRunIssues.isEmpty && reports.count == expectedIDs.count
        return .init(schemaVersion: 1, batchID: algorithmBatch.batchID, valid: valid, exactRunInventory: exactInventory, runReports: reports, issues: batchIssues + allRunIssues)
    }

    private static func validateBindings(
        _ evidence: AnalysisDeviceAlgorithmExecutionEvidence,
        _ planned: AnalysisDevicePerformancePlannedRun,
        _ performance: AnalysisDevicePerformanceEvidence,
        _ receipt: AnalysisDeviceWorkloadReceipt,
        _ policy: AnalysisDeviceWorkloadPolicy,
        _ profile: AnalysisDevicePerformanceAcceptanceProfile,
        _ issues: inout [AnalysisDeviceAlgorithmEvidenceIssue]
    ) {
        let expectedSource = policy.fixtures[planned.fixtureID]
        let ok = evidence.schemaVersion == 1
            && evidence.runID == planned.runID
            && evidence.performanceEvidenceRunID == performance.provenance.runID
            && evidence.runKind == planned.runKind
            && receipt.runID == planned.runID
            && receipt.performanceEvidenceRunID == performance.provenance.runID
            && receipt.runKind == planned.runKind
            && evidence.workloadExecutionID == receipt.executionID
            && evidence.manifestID == receipt.manifestID
            && evidence.manifestSHA256 == receipt.manifestSHA256.lowercased()
            && evidence.manifestID == profile.expectedManifestID
            && evidence.manifestSHA256 == profile.expectedManifestSHA256.lowercased()
            && evidence.source == receipt.source
            && expectedSource == receipt.source
            && evidence.identity == receipt.identity
            && evidence.identity == policy.identity
            && evidence.snapshotSHA256 == receipt.snapshotSHA256?.lowercased()
            && policy.manifestID == evidence.manifestID
            && policy.manifestSHA256.lowercased() == evidence.manifestSHA256
            && performance.provenance.fixtureID == planned.fixtureID
            && performance.provenance.runKind == planned.runKind
            && performance.provenance.manifestID == evidence.manifestID
            && performance.provenance.manifestSHA256.lowercased() == evidence.manifestSHA256
            && abs(performance.provenance.fixtureDurationSeconds - receipt.source.sourceDurationSeconds) <= max(0.001, receipt.source.sourceDurationSeconds * 0.001)
            && performance.provenance.deviceModel == profile.expectedDeviceModel
            && performance.provenance.osVersion == profile.expectedOSVersion
            && performance.provenance.appBundleIdentifier == profile.expectedAppBundleIdentifier
            && performance.provenance.appVersion == profile.expectedAppVersion
            && performance.provenance.buildVersion == profile.expectedBuildVersion
        if !ok {
            issues.append(.init(code: .bindingMismatch, fixtureID: planned.fixtureID, runID: planned.runID, detail: "W35 evidence must bind exactly to W23 provenance, W25 execution/source/snapshot, workload policy and W24 planned run"))
        }
    }

    private static func validateCapture(
        _ evidence: AnalysisDeviceAlgorithmExecutionEvidence,
        _ receipt: AnalysisDeviceWorkloadReceipt,
        _ planned: AnalysisDevicePerformancePlannedRun,
        _ issues: inout [AnalysisDeviceAlgorithmEvidenceIssue]
    ) {
        switch planned.runKind {
        case .completeAnalysis:
            guard evidence.captureState == .finalized,
                  receipt.snapshotSHA256 != nil,
                  let runtime = evidence.runtimeIdentity,
                  let claimedHash = evidence.runtimeIdentitySHA256 else {
                issues.append(.init(code: .missingFinalRuntimeIdentity, fixtureID: planned.fixtureID, runID: planned.runID, detail: "complete run requires finalized runtime identity and W25 snapshot SHA"))
                return
            }
            do {
                let computed = try AnalysisDeviceAlgorithmExecutionEvidenceCodec.identitySHA256(runtime)
                if computed != claimedHash.lowercased() {
                    issues.append(.init(code: .runtimeIdentityHashMismatch, fixtureID: planned.fixtureID, runID: planned.runID, detail: "runtime identity SHA-256 does not match canonical identity bytes"))
                }
            } catch {
                issues.append(.init(code: .runtimeIdentityHashMismatch, fixtureID: planned.fixtureID, runID: planned.runID, detail: "runtime identity could not be canonically encoded"))
            }
            validateRuntime(runtime, fixtureID: planned.fixtureID, runID: planned.runID, issues: &issues)

        case .cancellationProbe:
            if evidence.captureState != .cancelledBeforeFinalization || evidence.runtimeIdentity != nil || evidence.runtimeIdentitySHA256 != nil || receipt.snapshotSHA256 != nil {
                issues.append(.init(code: .invalidCaptureState, fixtureID: planned.fixtureID, runID: planned.runID, detail: "cancellation probe must bind the run/execution but must not pretend a finalized runtime/snapshot exists"))
            }
        }
    }

    private static func validateRuntime(
        _ runtime: AnalysisRuntimeAlgorithmIdentity,
        fixtureID: String,
        runID: String,
        issues: inout [AnalysisDeviceAlgorithmEvidenceIssue]
    ) {
        guard runtime.algorithmSchemaID == AnalysisRuntimeAlgorithmIdentity.currentAlgorithmSchemaID,
              runtime.exactSinglePreparedTraversal else {
            issues.append(.init(code: .nonCurrentRuntimePath, fixtureID: fixtureID, runID: runID, detail: "complete evidence must come from the current W29-W34 single-pass path, not the legacy W25 materialized analyzer"))
            return
        }
        let basic = runtime.preparedSampleCount > 0
            && runtime.tempoFrameStride > 0
            && runtime.chordFrameStride > 0
            && runtime.sectionEnergyFrameStrideEquivalent > 0
            && runtime.chordBackendVerificationFrameLimit == AnalysisChordBackendEquivalenceGuard.verificationFrameLimit
            && runtime.chordBackendVerificationComparisons >= 0
            && runtime.chordBackendVerificationMatches >= 0
            && runtime.chordBackendReferencePublicationCount >= 0
            && runtime.chordBackendVectorizedPublicationCount >= 0
        guard basic else {
            issues.append(.init(code: .invalidRuntimeIdentity, fixtureID: fixtureID, runID: runID, detail: "runtime cardinality/guard counters are invalid"))
            return
        }
        switch runtime.chordBackendGuardState {
        case AnalysisChordBackendGuardState.verifying.rawValue:
            let ok = !runtime.chordBackendFallbackTriggered
                && runtime.chordBackendFallbackComparisonIndex == nil
                && runtime.chordBackendVectorizedPublicationCount == 0
                && runtime.chordBackendVerificationComparisons == runtime.chordBackendVerificationMatches
                && runtime.chordBackendVerificationComparisons < runtime.chordBackendVerificationFrameLimit
                && runtime.chordBackendReferencePublicationCount == runtime.chordBackendVerificationComparisons
            if !ok { issues.append(.init(code: .invalidRuntimeIdentity, fixtureID: fixtureID, runID: runID, detail: "verifying backend counters are inconsistent")) }
        case AnalysisChordBackendGuardState.vectorizedVerified.rawValue:
            let ok = !runtime.chordBackendFallbackTriggered
                && runtime.chordBackendFallbackComparisonIndex == nil
                && runtime.chordBackendVerificationComparisons == runtime.chordBackendVerificationFrameLimit
                && runtime.chordBackendVerificationMatches == runtime.chordBackendVerificationFrameLimit
                && runtime.chordBackendReferencePublicationCount == runtime.chordBackendVerificationFrameLimit
            if !ok { issues.append(.init(code: .invalidRuntimeIdentity, fixtureID: fixtureID, runID: runID, detail: "verified backend counters are inconsistent")) }
        case AnalysisChordBackendGuardState.scalarFallback.rawValue:
            let fallbackIndex = runtime.chordBackendFallbackComparisonIndex ?? 0
            let ok = runtime.chordBackendFallbackTriggered
                && fallbackIndex >= 1
                && fallbackIndex <= runtime.chordBackendVerificationComparisons
                && runtime.chordBackendVectorizedPublicationCount == 0
                && runtime.chordBackendReferencePublicationCount >= runtime.chordBackendVerificationComparisons
                && runtime.chordBackendVerificationMatches < runtime.chordBackendVerificationComparisons
            if !ok { issues.append(.init(code: .invalidRuntimeIdentity, fixtureID: fixtureID, runID: runID, detail: "scalar fallback counters are inconsistent")) }
        default:
            issues.append(.init(code: .invalidRuntimeIdentity, fixtureID: fixtureID, runID: runID, detail: "unknown Chord backend guard state"))
        }
    }

    private static func appendDuplicateIssues(
        _ ids: [String],
        code: AnalysisDeviceAlgorithmEvidenceIssueCode,
        detail: String,
        into issues: inout [AnalysisDeviceAlgorithmEvidenceIssue]
    ) {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for id in ids where !seen.insert(id).inserted { duplicates.insert(id) }
        for id in duplicates.sorted() { issues.append(.init(code: code, runID: id, detail: detail)) }
    }

    private static func uniqueByRun(_ values: [AnalysisDevicePerformancePlannedRun]) -> [String: AnalysisDevicePerformancePlannedRun] {
        var out: [String: AnalysisDevicePerformancePlannedRun] = [:]
        for value in values where out[value.runID] == nil { out[value.runID] = value }
        return out
    }

    private static func uniquePerformanceByRun(_ values: [AnalysisDevicePerformanceEvidence]) -> [String: AnalysisDevicePerformanceEvidence] {
        var out: [String: AnalysisDevicePerformanceEvidence] = [:]
        for value in values where out[value.provenance.runID] == nil { out[value.provenance.runID] = value }
        return out
    }

    private static func uniqueReceiptByRun(_ values: [AnalysisDeviceWorkloadReceipt]) -> [String: AnalysisDeviceWorkloadReceipt] {
        var out: [String: AnalysisDeviceWorkloadReceipt] = [:]
        for value in values where out[value.runID] == nil { out[value.runID] = value }
        return out
    }

    private static func uniqueAlgorithmByRun(_ values: [AnalysisDeviceAlgorithmExecutionEvidence]) -> [String: AnalysisDeviceAlgorithmExecutionEvidence] {
        var out: [String: AnalysisDeviceAlgorithmExecutionEvidence] = [:]
        for value in values where out[value.runID] == nil { out[value.runID] = value }
        return out
    }
}
