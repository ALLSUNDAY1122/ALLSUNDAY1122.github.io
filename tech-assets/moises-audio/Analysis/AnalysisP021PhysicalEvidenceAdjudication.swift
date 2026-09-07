import Foundation

public enum AnalysisP021DecoderOrigin: String, Codable, Sendable {
    case genuineLane2BoundedDecoder = "GENUINE_LANE2_BOUNDED_DECODER"
    case compatibilityAdapter = "COMPATIBILITY_ADAPTER"
    case syntheticFixture = "SYNTHETIC_FIXTURE"
    case unknown = "UNKNOWN"
}

public struct AnalysisP021RunExecutionBinding: Codable, Equatable, Sendable {
    public let runID: String
    public let workloadExecutionID: String

    public init(runID: String, workloadExecutionID: String) {
        self.runID = runID
        self.workloadExecutionID = workloadExecutionID
    }
}

/// HQ-supplied runtime binding kept outside the W41 transfer package.
/// It does not replace physical telemetry; it closes the provenance gap that
/// W36's bounded-pull contract alone cannot prove: which decoder/backend and
/// selected Apple build actually supplied the physical workload.
public struct AnalysisP021RuntimeBinding: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let runtimeBindingID: String
    public let decoderOrigin: AnalysisP021DecoderOrigin
    public let decoderImplementationID: String
    public let decoderSourceRevision: String
    public let platform: String
    public let architecture: String
    public let xcodeVersion: String
    public let swiftVersion: String
    public let sourceRevision: String
    public let buildIdentity: String
    public let appBundleIdentifier: String
    public let appVersion: String
    public let buildVersion: String
    public let deviceModel: String
    public let osVersion: String
    public let physicalCaptureSessionID: String
    public let w44CheckpointCertificateRootSHA256: String
    public let w42AnchorReceiptRootSHA256: String
    public let w41TransferRootSHA256: String
    public let runExecutions: [AnalysisP021RunExecutionBinding]

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        runtimeBindingID: String,
        decoderOrigin: AnalysisP021DecoderOrigin,
        decoderImplementationID: String,
        decoderSourceRevision: String,
        platform: String,
        architecture: String,
        xcodeVersion: String,
        swiftVersion: String,
        sourceRevision: String,
        buildIdentity: String,
        appBundleIdentifier: String,
        appVersion: String,
        buildVersion: String,
        deviceModel: String,
        osVersion: String,
        physicalCaptureSessionID: String,
        w44CheckpointCertificateRootSHA256: String,
        w42AnchorReceiptRootSHA256: String,
        w41TransferRootSHA256: String,
        runExecutions: [AnalysisP021RunExecutionBinding]
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.runtimeBindingID = runtimeBindingID
        self.decoderOrigin = decoderOrigin
        self.decoderImplementationID = decoderImplementationID
        self.decoderSourceRevision = decoderSourceRevision
        self.platform = platform
        self.architecture = architecture
        self.xcodeVersion = xcodeVersion
        self.swiftVersion = swiftVersion
        self.sourceRevision = sourceRevision
        self.buildIdentity = buildIdentity
        self.appBundleIdentifier = appBundleIdentifier
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.physicalCaptureSessionID = physicalCaptureSessionID
        self.w44CheckpointCertificateRootSHA256 = w44CheckpointCertificateRootSHA256.lowercased()
        self.w42AnchorReceiptRootSHA256 = w42AnchorReceiptRootSHA256.lowercased()
        self.w41TransferRootSHA256 = w41TransferRootSHA256.lowercased()
        self.runExecutions = runExecutions.sorted { $0.runID < $1.runID }
    }
}

public enum AnalysisP021AdjudicationStatus: String, Codable, Sendable {
    case notReadyForHQJudgment = "NOT_READY_FOR_HQ_P021_JUDGMENT"
    case readyForHQJudgment = "READY_FOR_HQ_P021_JUDGMENT"
}

public enum AnalysisP021AdjudicationIssueCode: String, Codable, Hashable, Sendable {
    case checkpointVerificationFailed = "W45_CHECKPOINT_VERIFICATION_FAILED"
    case anchorReceiptMismatch = "W45_ANCHOR_RECEIPT_MISMATCH"
    case transferVerificationFailed = "W45_TRANSFER_VERIFICATION_FAILED"
    case transferAnchorMismatch = "W45_TRANSFER_ANCHOR_MISMATCH"
    case publishedBatchReopenFailed = "W45_PUBLISHED_BATCH_REOPEN_FAILED"
    case missingSingleton = "W45_MISSING_SINGLETON"
    case invalidSingleton = "W45_INVALID_SINGLETON"
    case invalidW24Acceptance = "W45_INVALID_W24_ACCEPTANCE"
    case archivedW24BatchMismatch = "W45_ARCHIVED_W24_BATCH_MISMATCH"
    case invalidRunInventory = "W45_INVALID_RUN_INVENTORY"
    case invalidW23Evidence = "W45_INVALID_W23_EVIDENCE"
    case invalidW25Receipt = "W45_INVALID_W25_RECEIPT"
    case invalidW35Evidence = "W45_INVALID_W35_EVIDENCE"
    case invalidW36Evidence = "W45_INVALID_W36_EVIDENCE"
    case invalidW37Evidence = "W45_INVALID_W37_EVIDENCE"
    case nonPhysicalRuntime = "W45_NON_PHYSICAL_RUNTIME"
    case incompletePhysicalTelemetry = "W45_INCOMPLETE_PHYSICAL_TELEMETRY"
    case reusedExecution = "W45_REUSED_EXECUTION"
    case invalidRuntimeBinding = "W45_INVALID_RUNTIME_BINDING"
    case compatibilityOrSyntheticRuntime = "W45_COMPATIBILITY_OR_SYNTHETIC_RUNTIME"
    case runtimeBindingMismatch = "W45_RUNTIME_BINDING_MISMATCH"
    case corroborationMismatch = "W45_CORROBORATION_MISMATCH"
}

public struct AnalysisP021AdjudicationIssue: Codable, Equatable, Sendable {
    public let code: AnalysisP021AdjudicationIssueCode
    public let runID: String?
    public let detail: String

    public init(code: AnalysisP021AdjudicationIssueCode, runID: String? = nil, detail: String) {
        self.code = code
        self.runID = runID
        self.detail = detail
    }
}

public struct AnalysisP021RunAdjudication: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let workloadExecutionID: String
    public let performanceStatus: AnalysisDevicePerformanceValidationStatus
    public let workloadStatus: AnalysisDeviceWorkloadValidationStatus
    public let physicalDeviceClaim: Bool
    public let peakResidentBytes: UInt64?
    public let peakPhysicalFootprintBytes: UInt64?
    public let worstThermalState: AnalysisDeviceThermalState?
    public let batteryDrainFraction: Double?
    public let cancellationLatencySeconds: Double?
    public let boundedPullObserved: Bool

    public init(
        runID: String,
        fixtureID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        workloadExecutionID: String,
        performanceStatus: AnalysisDevicePerformanceValidationStatus,
        workloadStatus: AnalysisDeviceWorkloadValidationStatus,
        physicalDeviceClaim: Bool,
        peakResidentBytes: UInt64?,
        peakPhysicalFootprintBytes: UInt64?,
        worstThermalState: AnalysisDeviceThermalState?,
        batteryDrainFraction: Double?,
        cancellationLatencySeconds: Double?,
        boundedPullObserved: Bool
    ) {
        self.runID = runID
        self.fixtureID = fixtureID
        self.runKind = runKind
        self.workloadExecutionID = workloadExecutionID
        self.performanceStatus = performanceStatus
        self.workloadStatus = workloadStatus
        self.physicalDeviceClaim = physicalDeviceClaim
        self.peakResidentBytes = peakResidentBytes
        self.peakPhysicalFootprintBytes = peakPhysicalFootprintBytes
        self.worstThermalState = worstThermalState
        self.batteryDrainFraction = batteryDrainFraction
        self.cancellationLatencySeconds = cancellationLatencySeconds
        self.boundedPullObserved = boundedPullObserved
    }
}

public struct AnalysisP021PhysicalEvidenceAdjudicationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisP021AdjudicationStatus
    public let checkpointID: String
    public let checkpointSequence: UInt64
    public let checkpointCertificateRootSHA256: String
    public let anchorID: String
    public let anchorSequence: UInt64
    public let anchorReceiptRootSHA256: String
    public let transferID: String
    public let transferRootSHA256: String
    public let publicationID: String
    public let w24ProfileID: String?
    public let w24BatchID: String?
    public let plannedRunCount: Int
    public let observedRunCount: Int
    public let runtimeBindingID: String
    public let runAdjudications: [AnalysisP021RunAdjudication]
    public let issues: [AnalysisP021AdjudicationIssue]
    public let limitations: [String]
    public let declaredReportRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisP021AdjudicationStatus,
        checkpointID: String,
        checkpointSequence: UInt64,
        checkpointCertificateRootSHA256: String,
        anchorID: String,
        anchorSequence: UInt64,
        anchorReceiptRootSHA256: String,
        transferID: String,
        transferRootSHA256: String,
        publicationID: String,
        w24ProfileID: String?,
        w24BatchID: String?,
        plannedRunCount: Int,
        observedRunCount: Int,
        runtimeBindingID: String,
        runAdjudications: [AnalysisP021RunAdjudication],
        issues: [AnalysisP021AdjudicationIssue],
        limitations: [String],
        declaredReportRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.checkpointID = checkpointID
        self.checkpointSequence = checkpointSequence
        self.checkpointCertificateRootSHA256 = checkpointCertificateRootSHA256.lowercased()
        self.anchorID = anchorID
        self.anchorSequence = anchorSequence
        self.anchorReceiptRootSHA256 = anchorReceiptRootSHA256.lowercased()
        self.transferID = transferID
        self.transferRootSHA256 = transferRootSHA256.lowercased()
        self.publicationID = publicationID
        self.w24ProfileID = w24ProfileID
        self.w24BatchID = w24BatchID
        self.plannedRunCount = plannedRunCount
        self.observedRunCount = observedRunCount
        self.runtimeBindingID = runtimeBindingID
        self.runAdjudications = runAdjudications.sorted { $0.runID < $1.runID }
        self.issues = issues.sorted { lhs, rhs in
            (lhs.code.rawValue, lhs.runID ?? "", lhs.detail) < (rhs.code.rawValue, rhs.runID ?? "", rhs.detail)
        }
        self.limitations = limitations
        self.declaredReportRootSHA256 = declaredReportRootSHA256.lowercased()
    }
}

public enum AnalysisP021AdjudicationError: Error, Equatable, Sendable {
    case checkpointVerificationFailed
    case anchorReceiptMismatch
    case transferVerificationFailed
    case transferAnchorMismatch
    case publishedBatchReopenFailed
    case decodeFailure(String)
    case reportRootFailure
}

public enum AnalysisP021AdjudicationReportRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let status: AnalysisP021AdjudicationStatus
        let checkpointID: String
        let checkpointSequence: UInt64
        let checkpointCertificateRootSHA256: String
        let anchorID: String
        let anchorSequence: UInt64
        let anchorReceiptRootSHA256: String
        let transferID: String
        let transferRootSHA256: String
        let publicationID: String
        let w24ProfileID: String?
        let w24BatchID: String?
        let plannedRunCount: Int
        let observedRunCount: Int
        let runtimeBindingID: String
        let runAdjudications: [AnalysisP021RunAdjudication]
        let issues: [AnalysisP021AdjudicationIssue]
        let limitations: [String]
    }

    public static func compute(_ report: AnalysisP021PhysicalEvidenceAdjudicationReport) throws -> String {
        let payload = Payload(
            schemaVersion: report.schemaVersion,
            status: report.status,
            checkpointID: report.checkpointID,
            checkpointSequence: report.checkpointSequence,
            checkpointCertificateRootSHA256: report.checkpointCertificateRootSHA256.lowercased(),
            anchorID: report.anchorID,
            anchorSequence: report.anchorSequence,
            anchorReceiptRootSHA256: report.anchorReceiptRootSHA256.lowercased(),
            transferID: report.transferID,
            transferRootSHA256: report.transferRootSHA256.lowercased(),
            publicationID: report.publicationID,
            w24ProfileID: report.w24ProfileID,
            w24BatchID: report.w24BatchID,
            plannedRunCount: report.plannedRunCount,
            observedRunCount: report.observedRunCount,
            runtimeBindingID: report.runtimeBindingID,
            runAdjudications: report.runAdjudications.sorted { $0.runID < $1.runID },
            issues: report.issues.sorted { lhs, rhs in
                (lhs.code.rawValue, lhs.runID ?? "", lhs.detail) < (rhs.code.rawValue, rhs.runID ?? "", rhs.detail)
            },
            limitations: report.limitations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisP021PhysicalEvidenceAdjudicator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: READY_FOR_HQ_P021_JUDGMENT means the anchored physical evidence package is complete enough for HQ to judge P021; it does not itself promote or prove PARITY.",
        "The external runtime binding is HQ metadata. Without an external signature/trusted timestamp/build attestation it is not cryptographic proof of decoder or device origin.",
        "W23 physical telemetry remains authoritative for resident memory, physical footprint, thermal, battery and cancellation observations; BOUNDED_PULL_CONTRACT alone is not proof of hidden decoder buffering.",
        "The W44 checkpoint, W42 anchor, W41 transfer and W45 report roots are SHA-256 commitments, not signatures, Secure Enclave proofs, Apple attestation or trusted timestamps.",
        "HQ must still inspect the selected physical-iPhone evidence and may reject P021 even when this gate is READY_FOR_HQ_P021_JUDGMENT."
    ]

    public static func adjudicate(
        ledgerRootURL: URL,
        checkpointExpectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation,
        checkpointCertificate: AnalysisPhysicalEvidenceLedgerCheckpointCertificate,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        transferDirectoryURL: URL,
        runtimeBinding: AnalysisP021RuntimeBinding,
        fileManager: FileManager = .default
    ) throws -> AnalysisP021PhysicalEvidenceAdjudicationReport {
        do {
            try AnalysisPhysicalEvidenceLedgerCheckpointVerifier.verifyCertificateAgainstCurrentLedger(
                checkpointCertificate,
                rootURL: ledgerRootURL,
                expectation: checkpointExpectation,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisP021AdjudicationError.checkpointVerificationFailed
        }

        guard AnalysisPhysicalEvidenceAnchorReceiptIssuer.validateAnchor(anchorReceipt.anchor),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(anchorReceipt.declaredAnchorReceiptRootSHA256),
              (try? AnalysisPhysicalEvidenceAnchorReceiptRoot.compute(anchorReceipt.anchor)) == anchorReceipt.declaredAnchorReceiptRootSHA256.lowercased(),
              anchorReceipt.declaredAnchorReceiptRootSHA256.lowercased() == checkpointCertificate.observedLatestAnchorReceiptRootSHA256.lowercased(),
              anchorReceipt.anchor.anchorID == checkpointCertificate.anchorID,
              anchorReceipt.anchor.anchorSequence == checkpointCertificate.observedLatestLedgerSequence else {
            throw AnalysisP021AdjudicationError.anchorReceiptMismatch
        }

        let transfer: AnalysisPhysicalEvidenceTransferManifest
        do {
            transfer = try AnalysisPhysicalEvidenceTransferVerifier.verify(
                transferDirectoryURL: transferDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisP021AdjudicationError.transferVerificationFailed
        }
        let anchor = anchorReceipt.anchor
        guard transfer.transferID == anchor.transferID,
              transfer.publicationID == anchor.publicationID,
              transfer.w27RootSHA256 == anchor.w27RootSHA256,
              transfer.w38RootSHA256 == anchor.w38RootSHA256,
              transfer.w40RootSHA256 == anchor.w40RootSHA256,
              transfer.declaredTransferRootSHA256 == anchor.w41RootSHA256,
              transfer.runs == anchor.runs else {
            throw AnalysisP021AdjudicationError.transferAnchorMismatch
        }

        let payloadRoot = transferDirectoryURL.appendingPathComponent("payload", isDirectory: true)
        let reopened: AnalysisPhysicalEvidenceReopenedBatch
        do {
            reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
                publicationID: transfer.publicationID,
                archiveRootURL: payloadRoot,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisP021AdjudicationError.publishedBatchReopenFailed
        }

        return try adjudicateVerifiedInputs(
            checkpointExpectation: checkpointExpectation,
            checkpointCertificate: checkpointCertificate,
            anchorReceipt: anchorReceipt,
            transfer: transfer,
            reopened: reopened,
            runtimeBinding: runtimeBinding
        )
    }

    static func adjudicateVerifiedInputs(
        checkpointExpectation: AnalysisPhysicalEvidenceLedgerCheckpointExpectation,
        checkpointCertificate: AnalysisPhysicalEvidenceLedgerCheckpointCertificate,
        anchorReceipt: AnalysisPhysicalEvidenceAnchorReceipt,
        transfer: AnalysisPhysicalEvidenceTransferManifest,
        reopened: AnalysisPhysicalEvidenceReopenedBatch,
        runtimeBinding: AnalysisP021RuntimeBinding
    ) throws -> AnalysisP021PhysicalEvidenceAdjudicationReport {
        var issues: [AnalysisP021AdjudicationIssue] = []

        let checkpointRoot = checkpointCertificate.declaredCertificateRootSHA256.lowercased()
        let anchorRoot = anchorReceipt.declaredAnchorReceiptRootSHA256.lowercased()
        let transferRoot = transfer.declaredTransferRootSHA256.lowercased()

        validateRuntimeBinding(
            runtimeBinding,
            checkpointCertificateRoot: checkpointRoot,
            anchorReceiptRoot: anchorRoot,
            transfer: transfer,
            issues: &issues
        )

        let singletonItems = reopened.items.filter { $0.kind == .singleton }
        let singletonByRole = Dictionary(grouping: singletonItems, by: { $0.role ?? "" })

        let profile: AnalysisDevicePerformanceAcceptanceProfile? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.w24PerformanceProfile.rawValue,
            from: singletonByRole,
            as: AnalysisDevicePerformanceAcceptanceProfile.self,
            issues: &issues
        )
        let archivedBatch: AnalysisDevicePerformanceEvidenceBatch? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.w24PerformanceBatch.rawValue,
            from: singletonByRole,
            as: AnalysisDevicePerformanceEvidenceBatch.self,
            dateAware: true,
            issues: &issues
        )
        let archivedAcceptance: AnalysisDevicePerformanceAcceptanceReport? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.w24AcceptanceReport.rawValue,
            from: singletonByRole,
            as: AnalysisDevicePerformanceAcceptanceReport.self,
            dateAware: true,
            issues: &issues
        )
        let workloadPolicy: AnalysisDeviceWorkloadPolicy? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.w25WorkloadPolicy.rawValue,
            from: singletonByRole,
            as: AnalysisDeviceWorkloadPolicy.self,
            issues: &issues
        )
        let buildCorroboration: AnalysisPhysicalEvidenceBuildCorroboration? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.buildCorroboration.rawValue,
            from: singletonByRole,
            as: AnalysisPhysicalEvidenceBuildCorroboration.self,
            issues: &issues
        )
        let deviceCorroboration: AnalysisPhysicalEvidenceDeviceCorroboration? = decodeSingleton(
            role: AnalysisPhysicalEvidenceArtifactRole.deviceCorroboration.rawValue,
            from: singletonByRole,
            as: AnalysisPhysicalEvidenceDeviceCorroboration.self,
            issues: &issues
        )

        var performances: [AnalysisDevicePerformanceEvidence] = []
        var performanceReports: [String: AnalysisDevicePerformanceValidationReport] = [:]
        var receipts: [AnalysisDeviceWorkloadReceipt] = []
        var workloadReports: [String: AnalysisDeviceWorkloadValidationReport] = [:]
        var algorithms: [AnalysisDeviceAlgorithmExecutionEvidence] = []
        var runtimeEvidence: [String: AnalysisCurrentDeviceWorkloadArchiveEvidence] = [:]
        var capturePlans: [String: AnalysisDeviceCapturePlan] = [:]
        var integrityEvidence: [String: AnalysisDeviceCaptureExecutionIntegrityEvidence] = [:]
        var integrityReports: [String: AnalysisDeviceCaptureExecutionIntegrityReport] = [:]

        for run in transfer.runs.sorted(by: { $0.runID < $1.runID }) {
            let runItems = reopened.items.filter { $0.kind == .w39Artifact && $0.runID == run.runID }
            func bytes(_ role: AnalysisPhysicalCaptureArtifactRole) -> Data? {
                let matches = runItems.filter { $0.role == role.rawValue }
                guard matches.count == 1 else { return nil }
                return matches[0].bytes
            }
            do {
                guard let performanceBytes = bytes(.w23PerformanceEvidence),
                      let performanceReportBytes = bytes(.w23PerformanceValidation),
                      let receiptBytes = bytes(.w25WorkloadReceipt),
                      let workloadReportBytes = bytes(.w25WorkloadValidation),
                      let algorithmBytes = bytes(.w35AlgorithmEvidence),
                      let runtimeBytes = bytes(.w36CurrentRuntimeEvidence),
                      let planBytes = bytes(.w37CapturePlan),
                      let integrityBytes = bytes(.w37ExecutionIntegrityEvidence),
                      let integrityReportBytes = bytes(.w37ExecutionIntegrityReport) else {
                    issues.append(.init(code: .invalidRunInventory, runID: run.runID, detail: "exactly nine W39 artifacts are required for every W24 planned run"))
                    continue
                }
                let performance = try AnalysisDevicePerformanceEvidenceCodec.decodeEvidence(performanceBytes)
                let performanceReport = try AnalysisDevicePerformanceEvidenceCodec.decodeReport(performanceReportBytes)
                let receipt = try dateDecoder().decode(AnalysisDeviceWorkloadReceipt.self, from: receiptBytes)
                let workloadReport = try JSONDecoder().decode(AnalysisDeviceWorkloadValidationReport.self, from: workloadReportBytes)
                let algorithm = try JSONDecoder().decode(AnalysisDeviceAlgorithmExecutionEvidence.self, from: algorithmBytes)
                let currentRuntime = try JSONDecoder().decode(AnalysisCurrentDeviceWorkloadArchiveEvidence.self, from: runtimeBytes)
                let plan = try JSONDecoder().decode(AnalysisDeviceCapturePlan.self, from: planBytes)
                let integrity = try JSONDecoder().decode(AnalysisDeviceCaptureExecutionIntegrityEvidence.self, from: integrityBytes)
                let integrityReport = try JSONDecoder().decode(AnalysisDeviceCaptureExecutionIntegrityReport.self, from: integrityReportBytes)

                performances.append(performance)
                performanceReports[run.runID] = performanceReport
                receipts.append(receipt)
                workloadReports[run.runID] = workloadReport
                algorithms.append(algorithm)
                runtimeEvidence[run.runID] = currentRuntime
                capturePlans[run.runID] = plan
                integrityEvidence[run.runID] = integrity
                integrityReports[run.runID] = integrityReport
            } catch {
                issues.append(.init(code: .invalidRunInventory, runID: run.runID, detail: "one or more W23/W25/W35/W36/W37 artifacts could not be decoded"))
            }
        }

        var runAdjudications: [AnalysisP021RunAdjudication] = []
        if let profile, let archivedBatch, let archivedAcceptance, let workloadPolicy {
            validateCorroboration(
                profile: profile,
                workloadPolicy: workloadPolicy,
                build: buildCorroboration,
                device: deviceCorroboration,
                runtimeBinding: runtimeBinding,
                issues: &issues
            )

            let plannedIDs = profile.plannedRuns.map(\.runID)
            let observedIDs = performances.map { $0.provenance.runID }
            if Set(plannedIDs) != Set(transfer.runs.map(\.runID))
                || Set(plannedIDs) != Set(observedIDs)
                || plannedIDs.count != Set(plannedIDs).count
                || observedIDs.count != Set(observedIDs).count
                || transfer.runs.count != profile.plannedRuns.count {
                issues.append(.init(code: .invalidRunInventory, detail: "W24 planned runs, W41 transfer runs and W23 physical runs must be the exact same unique set"))
            }

            let reconstructedByRun = Dictionary(uniqueKeysWithValues: performances.map { ($0.provenance.runID, $0) })
            let archivedByRun = Dictionary(grouping: archivedBatch.runs, by: { $0.provenance.runID })
            if archivedBatch.batchID != profile.expectedBatchID
                || archivedBatch.profileID != profile.profileID
                || archivedBatch.runs.count != profile.plannedRuns.count
                || archivedByRun.contains(where: { $0.value.count != 1 })
                || Set(archivedByRun.keys) != Set(plannedIDs)
                || archivedByRun.contains(where: { reconstructedByRun[$0.key] != $0.value.first }) {
                issues.append(.init(code: .archivedW24BatchMismatch, detail: "archived W24 batch must exactly equal the W23 per-run evidence retained in W39/W41"))
            }

            let recomputedAcceptance = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(
                batch: archivedBatch,
                profile: profile,
                evaluatedAt: archivedAcceptance.generatedAt
            )
            if recomputedAcceptance != archivedAcceptance
                || archivedAcceptance.status != .withinApprovedLimitsPendingHQ
                || !archivedAcceptance.completePlannedRunSet {
                issues.append(.init(code: .invalidW24Acceptance, detail: "repeated W24 acceptance must recompute exactly and remain within HQ-approved limits"))
            }

            let performanceByRun = Dictionary(uniqueKeysWithValues: performances.map { ($0.provenance.runID, $0) })
            let receiptByRun = Dictionary(uniqueKeysWithValues: receipts.map { ($0.runID, $0) })
            let algorithmBatch = AnalysisDeviceAlgorithmEvidenceBatch(
                batchID: archivedBatch.batchID,
                performanceProfileID: archivedBatch.profileID,
                runs: algorithms
            )
            let algorithmReport = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
                algorithmBatch: algorithmBatch,
                performanceBatch: archivedBatch,
                receipts: receipts,
                workloadPolicy: workloadPolicy,
                performanceProfile: profile
            )
            if !algorithmReport.valid || !algorithmReport.exactRunInventory {
                issues.append(.init(code: .invalidW35Evidence, detail: "W35 current-runtime algorithm evidence must validate for the exact W24 run inventory"))
            }

            let batchWorkloadReports = AnalysisDeviceWorkloadReceiptValidator.validateBatch(
                receipts: receipts,
                performanceRuns: performances,
                policy: workloadPolicy
            )
            if batchWorkloadReports.contains(where: { $0.status == .invalid }) {
                issues.append(.init(code: .invalidW25Receipt, detail: "W25 receipt batch contains invalid or reused execution evidence"))
            }

            let executionIDs = receipts.map(\.executionID)
            if Set(executionIDs).count != executionIDs.count
                || Set(executionIDs) != Set(transfer.runs.map(\.workloadExecutionID)) {
                issues.append(.init(code: .reusedExecution, detail: "every planned run requires one unique W36 workload execution ID matching the W41 transfer summary"))
            }

            for planned in profile.plannedRuns.sorted(by: { $0.runID < $1.runID }) {
                guard let performance = performanceByRun[planned.runID],
                      let receipt = receiptByRun[planned.runID],
                      let archivedPerformanceReport = performanceReports[planned.runID],
                      let archivedWorkloadReport = workloadReports[planned.runID],
                      let currentRuntime = runtimeEvidence[planned.runID],
                      let plan = capturePlans[planned.runID],
                      let executionIntegrity = integrityEvidence[planned.runID],
                      let archivedIntegrityReport = integrityReports[planned.runID] else {
                    issues.append(.init(code: .invalidRunInventory, runID: planned.runID, detail: "planned run is missing decoded physical evidence"))
                    continue
                }

                let recomputedPerformance = AnalysisDevicePerformanceEvidenceValidator.validate(
                    performance,
                    expectedManifestID: profile.expectedManifestID,
                    expectedManifestSHA256: profile.expectedManifestSHA256,
                    evaluatedAt: archivedPerformanceReport.generatedAt
                )
                if recomputedPerformance != archivedPerformanceReport
                    || archivedPerformanceReport.status != .structurallyCompletePendingHQ {
                    issues.append(.init(code: .invalidW23Evidence, runID: planned.runID, detail: "W23 report must recompute exactly and be structurally complete"))
                }

                let recomputedWorkload = AnalysisDeviceWorkloadReceiptValidator.validate(
                    receipt,
                    performanceEvidence: performance,
                    policy: workloadPolicy
                )
                let expectedWorkloadStatus: AnalysisDeviceWorkloadValidationStatus = planned.runKind == .completeAnalysis
                    ? .fullWorkloadCompletePendingHQ
                    : .realWorkCancellationPendingHQ
                if recomputedWorkload != archivedWorkloadReport || archivedWorkloadReport.status != expectedWorkloadStatus {
                    issues.append(.init(code: .invalidW25Receipt, runID: planned.runID, detail: "W25 receipt must recompute exactly with the expected complete/cancellation status"))
                }

                let planReport = AnalysisDeviceCapturePlanValidator.validate(
                    plan,
                    workloadPolicy: workloadPolicy,
                    performanceProfile: profile
                )
                let recomputedIntegrity = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(executionIntegrity)
                if !planReport.valid
                    || recomputedIntegrity != archivedIntegrityReport
                    || !archivedIntegrityReport.valid {
                    issues.append(.init(code: .invalidW37Evidence, runID: planned.runID, detail: "W37 capture plan and execution-integrity evidence must validate exactly"))
                }

                let bounded = currentRuntime.sourceMemoryContract == .boundedPull
                    && currentRuntime.boundedSourceContractAccepted
                    && executionIntegrity.sourceMemoryContract == .boundedPull
                    && algorithms.first(where: { $0.runID == planned.runID })?.sourceInputContract == .boundedPull
                let runtimeBindingsMatch = currentRuntime.schemaVersion == 1
                    && currentRuntime.runID == planned.runID
                    && currentRuntime.performanceEvidenceRunID == planned.runID
                    && currentRuntime.runKind == planned.runKind
                    && currentRuntime.workloadExecutionID == receipt.executionID
                    && currentRuntime.algorithmRunID == planned.runID
                    && currentRuntime.algorithmWorkloadExecutionID == receipt.executionID
                    && currentRuntime.observedSourceChunkCount > 0
                    && currentRuntime.observedSourceSampleCount > 0
                if !bounded || !runtimeBindingsMatch {
                    issues.append(.init(code: .invalidW36Evidence, runID: planned.runID, detail: "W36 must prove a bounded-pull current runtime with observed source work and exact execution bindings"))
                }

                if performance.provenance.runtimeClass != .physicalIOSDevice || !archivedPerformanceReport.physicalDeviceClaim {
                    issues.append(.init(code: .nonPhysicalRuntime, runID: planned.runID, detail: "P021 requires PHYSICAL_IOS_DEVICE evidence for every planned run"))
                }

                let usableMemory = performance.memoryTelemetry.available
                    && performance.memorySamples.contains { $0.residentBytes != nil && $0.physicalFootprintBytes != nil }
                let usableThermal = performance.thermalTelemetry.available
                    && performance.thermalSamples.contains { $0.state != .unavailable }
                let usableBattery = performance.batteryTelemetry.available
                    && performance.batterySamples.filter { $0.levelFraction != nil && $0.state != .unavailable }.count >= 2
                let usablePressure = performance.memoryPressureObservation.available
                let cancellationComplete = planned.runKind == .completeAnalysis
                    || archivedPerformanceReport.cancellationLatencySeconds != nil
                if !usableMemory || !usableThermal || !usableBattery || !usablePressure || !cancellationComplete {
                    issues.append(.init(code: .incompletePhysicalTelemetry, runID: planned.runID, detail: "resident/physical-footprint/thermal/battery/memory-pressure telemetry and cancellation latency must all be observable where applicable"))
                }

                runAdjudications.append(.init(
                    runID: planned.runID,
                    fixtureID: planned.fixtureID,
                    runKind: planned.runKind,
                    workloadExecutionID: receipt.executionID,
                    performanceStatus: archivedPerformanceReport.status,
                    workloadStatus: archivedWorkloadReport.status,
                    physicalDeviceClaim: archivedPerformanceReport.physicalDeviceClaim,
                    peakResidentBytes: archivedPerformanceReport.peakResidentBytes,
                    peakPhysicalFootprintBytes: archivedPerformanceReport.peakPhysicalFootprintBytes,
                    worstThermalState: archivedPerformanceReport.worstThermalState,
                    batteryDrainFraction: archivedPerformanceReport.batteryDrainFraction,
                    cancellationLatencySeconds: archivedPerformanceReport.cancellationLatencySeconds,
                    boundedPullObserved: bounded
                ))
            }
        }

        let ready = issues.isEmpty
        let provisional = AnalysisP021PhysicalEvidenceAdjudicationReport(
            status: ready ? .readyForHQJudgment : .notReadyForHQJudgment,
            checkpointID: checkpointExpectation.checkpointID,
            checkpointSequence: checkpointExpectation.checkpointSequence,
            checkpointCertificateRootSHA256: checkpointRoot,
            anchorID: anchorReceipt.anchor.anchorID,
            anchorSequence: anchorReceipt.anchor.anchorSequence,
            anchorReceiptRootSHA256: anchorRoot,
            transferID: transfer.transferID,
            transferRootSHA256: transferRoot,
            publicationID: transfer.publicationID,
            w24ProfileID: profile?.profileID,
            w24BatchID: archivedBatch?.batchID,
            plannedRunCount: profile?.plannedRuns.count ?? 0,
            observedRunCount: runAdjudications.count,
            runtimeBindingID: runtimeBinding.runtimeBindingID,
            runAdjudications: runAdjudications,
            issues: issues,
            limitations: limitations,
            declaredReportRootSHA256: String(repeating: "0", count: 64)
        )
        let root: String
        do { root = try AnalysisP021AdjudicationReportRoot.compute(provisional) }
        catch { throw AnalysisP021AdjudicationError.reportRootFailure }
        return .init(
            status: provisional.status,
            checkpointID: provisional.checkpointID,
            checkpointSequence: provisional.checkpointSequence,
            checkpointCertificateRootSHA256: provisional.checkpointCertificateRootSHA256,
            anchorID: provisional.anchorID,
            anchorSequence: provisional.anchorSequence,
            anchorReceiptRootSHA256: provisional.anchorReceiptRootSHA256,
            transferID: provisional.transferID,
            transferRootSHA256: provisional.transferRootSHA256,
            publicationID: provisional.publicationID,
            w24ProfileID: provisional.w24ProfileID,
            w24BatchID: provisional.w24BatchID,
            plannedRunCount: provisional.plannedRunCount,
            observedRunCount: provisional.observedRunCount,
            runtimeBindingID: provisional.runtimeBindingID,
            runAdjudications: provisional.runAdjudications,
            issues: provisional.issues,
            limitations: provisional.limitations,
            declaredReportRootSHA256: root
        )
    }

    private static func validateRuntimeBinding(
        _ binding: AnalysisP021RuntimeBinding,
        checkpointCertificateRoot: String,
        anchorReceiptRoot: String,
        transfer: AnalysisPhysicalEvidenceTransferManifest,
        issues: inout [AnalysisP021AdjudicationIssue]
    ) {
        let strings = [
            binding.approvalReference, binding.runtimeBindingID, binding.decoderImplementationID,
            binding.decoderSourceRevision, binding.xcodeVersion, binding.swiftVersion, binding.sourceRevision,
            binding.buildIdentity, binding.appBundleIdentifier, binding.appVersion, binding.buildVersion,
            binding.deviceModel, binding.osVersion, binding.physicalCaptureSessionID
        ]
        let runIDs = binding.runExecutions.map(\.runID)
        let executionIDs = binding.runExecutions.map(\.workloadExecutionID)
        let valid = binding.schemaVersion == 1
            && binding.authority == requiredAuthority
            && strings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(binding.runtimeBindingID)
            && binding.platform.lowercased() == "iphoneos"
            && binding.architecture.lowercased() == "arm64"
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(binding.w44CheckpointCertificateRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(binding.w42AnchorReceiptRootSHA256)
            && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(binding.w41TransferRootSHA256)
            && !runIDs.isEmpty
            && Set(runIDs).count == runIDs.count
            && Set(executionIDs).count == executionIDs.count
            && binding.runExecutions.allSatisfy {
                AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.runID)
                    && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.workloadExecutionID)
            }
        if !valid {
            issues.append(.init(code: .invalidRuntimeBinding, detail: "HQ runtime binding requires exact iphoneos/arm64 build, decoder, device and unique run/execution identities"))
        }
        if binding.decoderOrigin != .genuineLane2BoundedDecoder {
            issues.append(.init(code: .compatibilityOrSyntheticRuntime, detail: "compatibility-adapter, synthetic-fixture, unknown or other non-genuine decoder origins cannot make P021 ready"))
        }
        let expectedRuns = transfer.runs.sorted { $0.runID < $1.runID }.map {
            AnalysisP021RunExecutionBinding(runID: $0.runID, workloadExecutionID: $0.workloadExecutionID)
        }
        if binding.w44CheckpointCertificateRootSHA256 != checkpointCertificateRoot.lowercased()
            || binding.w42AnchorReceiptRootSHA256 != anchorReceiptRoot.lowercased()
            || binding.w41TransferRootSHA256 != transfer.declaredTransferRootSHA256.lowercased()
            || binding.runExecutions != expectedRuns {
            issues.append(.init(code: .runtimeBindingMismatch, detail: "runtime binding must pin the exact W44/W42/W41 roots and every W36 execution ID"))
        }
    }

    private static func validateCorroboration(
        profile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        build: AnalysisPhysicalEvidenceBuildCorroboration?,
        device: AnalysisPhysicalEvidenceDeviceCorroboration?,
        runtimeBinding: AnalysisP021RuntimeBinding,
        issues: inout [AnalysisP021AdjudicationIssue]
    ) {
        guard let build, let device else {
            issues.append(.init(code: .corroborationMismatch, detail: "build and device corroboration singletons are required"))
            return
        }
        let suspiciousTokens = ["synthetic", "simulator", "compatibility", "mock", "portable"]
        let evidenceText = ([device.evidenceMethod] + device.limitations).joined(separator: " ").lowercased()
        let suspicious = suspiciousTokens.contains { evidenceText.contains($0) }
        let ok = build.schemaVersion == 1
            && device.schemaVersion == 1
            && device.runtimeClass == .physicalIOSDevice
            && !device.captureSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !device.evidenceMethod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !suspicious
            && build.buildIdentity == workloadPolicy.identity.buildIdentity
            && build.buildIdentity == runtimeBinding.buildIdentity
            && build.appBundleIdentifier == profile.expectedAppBundleIdentifier
            && build.appBundleIdentifier == runtimeBinding.appBundleIdentifier
            && build.appVersion == profile.expectedAppVersion
            && build.appVersion == runtimeBinding.appVersion
            && build.buildVersion == profile.expectedBuildVersion
            && build.buildVersion == runtimeBinding.buildVersion
            && !build.sourceRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && build.sourceRevision == runtimeBinding.sourceRevision
            && device.deviceModel == profile.expectedDeviceModel
            && device.deviceModel == runtimeBinding.deviceModel
            && device.osVersion == profile.expectedOSVersion
            && device.osVersion == runtimeBinding.osVersion
            && device.captureSessionID == runtimeBinding.physicalCaptureSessionID
        if !ok {
            issues.append(.init(code: .corroborationMismatch, detail: "W27 build/device corroboration, W24 profile, W25 build identity and HQ runtime binding must describe one selected physical iPhone execution"))
        }
    }

    private static func decodeSingleton<T: Decodable>(
        role: String,
        from grouped: [String: [AnalysisPhysicalEvidenceReopenedItem]],
        as type: T.Type,
        dateAware: Bool = false,
        issues: inout [AnalysisP021AdjudicationIssue]
    ) -> T? {
        guard let matches = grouped[role], matches.count == 1 else {
            issues.append(.init(code: .missingSingleton, detail: "required singleton \(role) is missing or duplicated"))
            return nil
        }
        do {
            let decoder = dateAware ? dateDecoder() : JSONDecoder()
            return try decoder.decode(T.self, from: matches[0].bytes)
        } catch {
            issues.append(.init(code: .invalidSingleton, detail: "required singleton \(role) could not be decoded"))
            return nil
        }
    }

    private static func dateDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum AnalysisP021PhysicalEvidenceAdjudicationCodec {
    public static func encodeRuntimeBinding(_ value: AnalysisP021RuntimeBinding) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decodeRuntimeBinding(_ data: Data) throws -> AnalysisP021RuntimeBinding {
        try JSONDecoder().decode(AnalysisP021RuntimeBinding.self, from: data)
    }

    public static func encodeReport(_ value: AnalysisP021PhysicalEvidenceAdjudicationReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decodeReport(_ data: Data) throws -> AnalysisP021PhysicalEvidenceAdjudicationReport {
        try JSONDecoder().decode(AnalysisP021PhysicalEvidenceAdjudicationReport.self, from: data)
    }
}
