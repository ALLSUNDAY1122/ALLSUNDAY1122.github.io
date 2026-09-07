import Foundation

public struct AnalysisPhysicalRealAudioParityBridgeExpectation: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let bridgeID: String
    public let expectedW47PackageRootSHA256: String
    public let expectedW47PackageBytesSHA256: String
    public let expectedManifestID: String
    public let expectedManifestSHA256: String
    public let expectedRuntimeBindingSHA256: String
    public let expectedPhysicalSessionID: String
    public let expectedAuditedProjectReportSHA256: String
    public let expectedW46BindingSHA256: String
    public let previouslyConsumedW47PackageRootSHA256s: [String]

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        bridgeID: String,
        expectedW47PackageRootSHA256: String,
        expectedW47PackageBytesSHA256: String,
        expectedManifestID: String,
        expectedManifestSHA256: String,
        expectedRuntimeBindingSHA256: String,
        expectedPhysicalSessionID: String,
        expectedAuditedProjectReportSHA256: String,
        expectedW46BindingSHA256: String,
        previouslyConsumedW47PackageRootSHA256s: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.bridgeID = bridgeID
        self.expectedW47PackageRootSHA256 = expectedW47PackageRootSHA256.lowercased()
        self.expectedW47PackageBytesSHA256 = expectedW47PackageBytesSHA256.lowercased()
        self.expectedManifestID = expectedManifestID
        self.expectedManifestSHA256 = expectedManifestSHA256.lowercased()
        self.expectedRuntimeBindingSHA256 = expectedRuntimeBindingSHA256.lowercased()
        self.expectedPhysicalSessionID = expectedPhysicalSessionID
        self.expectedAuditedProjectReportSHA256 = expectedAuditedProjectReportSHA256.lowercased()
        self.expectedW46BindingSHA256 = expectedW46BindingSHA256.lowercased()
        self.previouslyConsumedW47PackageRootSHA256s = previouslyConsumedW47PackageRootSHA256s.map { $0.lowercased() }.sorted()
    }
}

public enum AnalysisPhysicalRealAudioParityBridgeIssueCode: String, Codable, Hashable, Sendable {
    case invalidExpectation = "W48_INVALID_EXPECTATION"
    case packageDecodeFailed = "W48_W47_PACKAGE_DECODE_FAILED"
    case packageNotCanonical = "W48_W47_PACKAGE_NOT_CANONICAL"
    case packageRootMismatch = "W48_W47_PACKAGE_ROOT_MISMATCH"
    case packageRootReplay = "W48_W47_PACKAGE_ROOT_REPLAY"
    case manifestDecodeFailed = "W48_MANIFEST_DECODE_FAILED"
    case manifestNotCanonical = "W48_MANIFEST_NOT_CANONICAL"
    case manifestRootMismatch = "W48_MANIFEST_ROOT_MISMATCH"
    case w47ReopenFailed = "W48_W47_REOPEN_FAILED"
    case runtimeBindingMismatch = "W48_RUNTIME_BINDING_MISMATCH"
    case physicalSessionMismatch = "W48_PHYSICAL_SESSION_MISMATCH"
    case projectReportMismatch = "W48_PROJECT_REPORT_MISMATCH"
    case w46BindingRootMismatch = "W48_W46_BINDING_ROOT_MISMATCH"
    case w46ProjectBindingMismatch = "W48_W46_PROJECT_BINDING_MISMATCH"
    case w46EvidenceRootMismatch = "W48_W46_EVIDENCE_ROOT_MISMATCH"
    case w46AdjudicationFailed = "W48_W46_ADJUDICATION_FAILED"
}

public struct AnalysisPhysicalRealAudioParityBridgeIssue: Codable, Equatable, Sendable {
    public let code: AnalysisPhysicalRealAudioParityBridgeIssueCode
    public let detail: String

    public init(code: AnalysisPhysicalRealAudioParityBridgeIssueCode, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public enum AnalysisPhysicalRealAudioParityBridgeError: Error, Equatable, Sendable {
    case invalid([AnalysisPhysicalRealAudioParityBridgeIssue])
    case canonicalEncodingFailed
}

public enum AnalysisPhysicalRealAudioParityBridgeCertificateStatus: String, Codable, Sendable {
    case nonParityBridgeExecuted = "NON_PARITY_W47_W46_BRIDGE_EXECUTED_PENDING_HQ_JUDGMENT"
}

public struct AnalysisPhysicalRealAudioParityBridgeCertificate: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalRealAudioParityBridgeCertificateStatus
    public let bridgeID: String
    public let expectationRootSHA256: String
    public let w47PackageRootSHA256: String
    public let w47PackageBytesSHA256: String
    public let manifestID: String
    public let manifestSHA256: String
    public let runtimeBindingSHA256: String
    public let physicalSessionID: String
    public let auditedProjectReportSHA256: String
    public let w46BindingSHA256: String
    public let w46AdjudicationStatus: AnalysisAnalysisParityAdjudicationStatus
    public let w46AdjudicationReportRootSHA256: String
    public let limitations: [String]
    public let declaredCertificateRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalRealAudioParityBridgeCertificateStatus = .nonParityBridgeExecuted,
        bridgeID: String,
        expectationRootSHA256: String,
        w47PackageRootSHA256: String,
        w47PackageBytesSHA256: String,
        manifestID: String,
        manifestSHA256: String,
        runtimeBindingSHA256: String,
        physicalSessionID: String,
        auditedProjectReportSHA256: String,
        w46BindingSHA256: String,
        w46AdjudicationStatus: AnalysisAnalysisParityAdjudicationStatus,
        w46AdjudicationReportRootSHA256: String,
        limitations: [String],
        declaredCertificateRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.bridgeID = bridgeID
        self.expectationRootSHA256 = expectationRootSHA256.lowercased()
        self.w47PackageRootSHA256 = w47PackageRootSHA256.lowercased()
        self.w47PackageBytesSHA256 = w47PackageBytesSHA256.lowercased()
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.runtimeBindingSHA256 = runtimeBindingSHA256.lowercased()
        self.physicalSessionID = physicalSessionID
        self.auditedProjectReportSHA256 = auditedProjectReportSHA256.lowercased()
        self.w46BindingSHA256 = w46BindingSHA256.lowercased()
        self.w46AdjudicationStatus = w46AdjudicationStatus
        self.w46AdjudicationReportRootSHA256 = w46AdjudicationReportRootSHA256.lowercased()
        self.limitations = limitations
        self.declaredCertificateRootSHA256 = declaredCertificateRootSHA256.lowercased()
    }
}

public struct AnalysisPhysicalRealAudioParityBridgeResult: Equatable, Sendable {
    public let adjudicationReport: AnalysisAnalysisParityAdjudicationReport
    public let certificate: AnalysisPhysicalRealAudioParityBridgeCertificate

    public init(
        adjudicationReport: AnalysisAnalysisParityAdjudicationReport,
        certificate: AnalysisPhysicalRealAudioParityBridgeCertificate
    ) {
        self.adjudicationReport = adjudicationReport
        self.certificate = certificate
    }
}

struct AnalysisPhysicalRealAudioProjectProvenance: Equatable, Sendable {
    let packageRootSHA256: String
    let packageBytesSHA256: String
    let manifestID: String
    let manifestSHA256: String
    let runtimeBindingSHA256: String
    let physicalSessionID: String
    let projectReportSHA256: String
    let engine: String
    let engineVersion: String
    let platform: String
    let architecture: String
    let sourceRevision: String
    let buildIdentity: String
    let deviceModel: String
    let osVersion: String
}

public enum AnalysisPhysicalRealAudioParityBridge {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: a W48 certificate proves only that one externally pinned W47 Project package was reopened and handed to the exact W46 canonical adjudication binding; it does not promote MOI-P009/P011/P013/P016.",
        "W48 rejects package/root/session/report/binding substitutions and can reject replay only against the prior-consumed package-root inventory supplied and independently retained by HQ; it is not a stateful trusted ledger by itself.",
        "SHA-256 commitments and HQ metadata remain tamper-evident bindings, not Apple attestation, code signing provenance, Secure Enclave proofs or trusted timestamps.",
        "Current-iPhone Moises Reference evidence, rights clearance, reviewer independence, differential tolerances and final PARITY_MATRIX judgment remain external HQ gates."
    ]

    private struct CertificateRootPayload: Codable {
        let schemaVersion: Int
        let status: AnalysisPhysicalRealAudioParityBridgeCertificateStatus
        let bridgeID: String
        let expectationRootSHA256: String
        let w47PackageRootSHA256: String
        let w47PackageBytesSHA256: String
        let manifestID: String
        let manifestSHA256: String
        let runtimeBindingSHA256: String
        let physicalSessionID: String
        let auditedProjectReportSHA256: String
        let w46BindingSHA256: String
        let w46AdjudicationStatus: AnalysisAnalysisParityAdjudicationStatus
        let w46AdjudicationReportRootSHA256: String
        let limitations: [String]
    }

    public static func adjudicate(
        w47PackageBytes: Data,
        manifestBytes: Data,
        expectation: AnalysisPhysicalRealAudioParityBridgeExpectation,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        w46Binding: AnalysisAnalysisParityEvidenceBinding,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        evaluatedAt: Date = Date()
    ) throws -> AnalysisPhysicalRealAudioParityBridgeResult {
        var issues = validateExpectation(expectation)

        let package: AnalysisPhysicalRealAudioCorpusExecutionPackage
        do {
            package = try AnalysisPhysicalRealAudioCorpusCodec.decode(w47PackageBytes)
        } catch {
            issues.append(.init(code: .packageDecodeFailed, detail: "retained W47 package bytes do not decode"))
            throw AnalysisPhysicalRealAudioParityBridgeError.invalid(sorted(issues))
        }

        do {
            guard try AnalysisPhysicalRealAudioCorpusCodec.encode(package) == w47PackageBytes else {
                issues.append(.init(code: .packageNotCanonical, detail: "retained W47 package bytes are not the canonical W47 codec representation"))
                throw AnalysisPhysicalRealAudioParityBridgeError.invalid(sorted(issues))
            }
        } catch let error as AnalysisPhysicalRealAudioParityBridgeError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioParityBridgeError.canonicalEncodingFailed
        }

        let manifest: AnalysisRealAudioBenchmarkManifest
        do {
            manifest = try AnalysisRealAudioBenchmarkCodec.decodeManifest(manifestBytes)
        } catch {
            issues.append(.init(code: .manifestDecodeFailed, detail: "retained canonical manifest bytes do not decode"))
            throw AnalysisPhysicalRealAudioParityBridgeError.invalid(sorted(issues))
        }
        do {
            guard try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest) == manifestBytes else {
                issues.append(.init(code: .manifestNotCanonical, detail: "manifest bytes are not the canonical benchmark manifest representation"))
                throw AnalysisPhysicalRealAudioParityBridgeError.invalid(sorted(issues))
            }
        } catch let error as AnalysisPhysicalRealAudioParityBridgeError {
            throw error
        } catch {
            throw AnalysisPhysicalRealAudioParityBridgeError.canonicalEncodingFailed
        }

        let packageBytesSHA = AnalysisDeviceWorkloadSHA256.hexDigest(w47PackageBytes)
        let manifestSHA = AnalysisDeviceWorkloadSHA256.hexDigest(manifestBytes)
        let computedPackageRoot: String
        let computedRuntimeRoot: String
        let computedW46BindingRoot: String
        do {
            computedPackageRoot = try AnalysisPhysicalRealAudioCorpusCanonical.packageSHA256(package)
            computedRuntimeRoot = try AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(package.runtime)
            computedW46BindingRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(w46Binding)
        } catch {
            throw AnalysisPhysicalRealAudioParityBridgeError.canonicalEncodingFailed
        }

        if computedPackageRoot != package.declaredPackageRootSHA256
            || computedPackageRoot != expectation.expectedW47PackageRootSHA256
            || packageBytesSHA != expectation.expectedW47PackageBytesSHA256 {
            issues.append(.init(code: .packageRootMismatch, detail: "W47 package canonical root and exact retained-byte SHA must both equal the independent HQ expectation"))
        }
        if expectation.previouslyConsumedW47PackageRootSHA256s.contains(computedPackageRoot) {
            issues.append(.init(code: .packageRootReplay, detail: "the exact W47 package root already appears in the HQ-supplied prior-consumed root inventory"))
        }
        if manifest.manifestID != expectation.expectedManifestID
            || manifestSHA != expectation.expectedManifestSHA256
            || package.manifestID != manifest.manifestID
            || package.manifestSHA256 != manifestSHA {
            issues.append(.init(code: .manifestRootMismatch, detail: "W47 package, canonical manifest bytes and HQ expectation do not identify one exact manifest root"))
        }
        if computedRuntimeRoot != package.runtimeBindingSHA256
            || computedRuntimeRoot != expectation.expectedRuntimeBindingSHA256 {
            issues.append(.init(code: .runtimeBindingMismatch, detail: "W47 runtime metadata does not recompute to the exact HQ-pinned runtime root"))
        }
        if package.runtime.physicalSessionID != expectation.expectedPhysicalSessionID {
            issues.append(.init(code: .physicalSessionMismatch, detail: "W47 physical session identity differs from the externally pinned HQ expectation"))
        }
        let rebuiltProjectReportRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(package.auditedProjectReport)
        if rebuiltProjectReportRoot == nil
            || rebuiltProjectReportRoot != package.auditedProjectReportSHA256
            || package.auditedProjectReportSHA256 != expectation.expectedAuditedProjectReportSHA256 {
            issues.append(.init(code: .projectReportMismatch, detail: "audited Project report root does not recompute or differs from the HQ-pinned W47 report root"))
        }
        if computedW46BindingRoot != expectation.expectedW46BindingSHA256 {
            issues.append(.init(code: .w46BindingRootMismatch, detail: "W46 evidence binding object differs from the exact independently pinned binding root"))
        }

        let reopenIssues = AnalysisPhysicalRealAudioCorpusAssembler.reopen(
            package,
            manifest: manifest,
            configuration: configuration,
            evaluatedAt: evaluatedAt
        )
        if !reopenIssues.isEmpty {
            let codes = reopenIssues.map(\.code.rawValue).joined(separator: ",")
            issues.append(.init(code: .w47ReopenFailed, detail: "W47 retained package failed canonical reopen: \(codes)"))
        }

        let provenance = AnalysisPhysicalRealAudioProjectProvenance(
            packageRootSHA256: computedPackageRoot,
            packageBytesSHA256: packageBytesSHA,
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            runtimeBindingSHA256: computedRuntimeRoot,
            physicalSessionID: package.runtime.physicalSessionID,
            projectReportSHA256: package.auditedProjectReportSHA256,
            engine: package.runtime.engine,
            engineVersion: package.runtime.engineVersion,
            platform: package.runtime.platform,
            architecture: package.runtime.architecture,
            sourceRevision: package.runtime.sourceRevision,
            buildIdentity: package.runtime.buildIdentity,
            deviceModel: package.runtime.deviceModel,
            osVersion: package.runtime.osVersion
        )
        issues.append(contentsOf: validateProvenance(provenance, expectation: expectation, binding: w46Binding))
        issues.append(contentsOf: validateW46EvidenceRoots(
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            projectEngine: package.runtime.engine,
            coveragePolicy: coveragePolicy,
            captureSet: captureSet,
            capturePolicy: capturePolicy,
            reviewSet: reviewSet,
            reviewPolicy: reviewPolicy,
            toleranceProfile: toleranceProfile,
            binding: w46Binding
        ))

        guard issues.isEmpty else {
            throw AnalysisPhysicalRealAudioParityBridgeError.invalid(sorted(issues))
        }

        let adjudication: AnalysisAnalysisParityAdjudicationReport
        do {
            adjudication = try AnalysisRealAudioParityCanonicalAdjudicator.adjudicate(
                manifestBytes: manifestBytes,
                coveragePolicy: coveragePolicy,
                captureSet: captureSet,
                capturePolicy: capturePolicy,
                reviewSet: reviewSet,
                reviewPolicy: reviewPolicy,
                projectReport: package.auditedProjectReport,
                toleranceProfile: toleranceProfile,
                binding: w46Binding,
                configuration: configuration,
                evaluatedAt: evaluatedAt
            )
        } catch {
            throw AnalysisPhysicalRealAudioParityBridgeError.invalid([
                .init(code: .w46AdjudicationFailed, detail: "W46 canonical adjudication rejected the pinned W47 handoff")
            ])
        }

        guard AnalysisAnalysisParityAdjudicationReportValidator.validate(adjudication) else {
            throw AnalysisPhysicalRealAudioParityBridgeError.invalid([
                .init(code: .w46AdjudicationFailed, detail: "W46 returned a report that fails its canonical report validator")
            ])
        }

        let expectationRoot: String
        let certificateRoot: String
        do {
            expectationRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(expectation)
            let payload = CertificateRootPayload(
                schemaVersion: 1,
                status: .nonParityBridgeExecuted,
                bridgeID: expectation.bridgeID,
                expectationRootSHA256: expectationRoot,
                w47PackageRootSHA256: computedPackageRoot,
                w47PackageBytesSHA256: packageBytesSHA,
                manifestID: package.manifestID,
                manifestSHA256: package.manifestSHA256,
                runtimeBindingSHA256: computedRuntimeRoot,
                physicalSessionID: package.runtime.physicalSessionID,
                auditedProjectReportSHA256: package.auditedProjectReportSHA256,
                w46BindingSHA256: computedW46BindingRoot,
                w46AdjudicationStatus: adjudication.status,
                w46AdjudicationReportRootSHA256: adjudication.declaredReportRootSHA256,
                limitations: limitations
            )
            certificateRoot = try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(payload)
        } catch {
            throw AnalysisPhysicalRealAudioParityBridgeError.canonicalEncodingFailed
        }

        let certificate = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: expectation.bridgeID,
            expectationRootSHA256: expectationRoot,
            w47PackageRootSHA256: computedPackageRoot,
            w47PackageBytesSHA256: packageBytesSHA,
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            runtimeBindingSHA256: computedRuntimeRoot,
            physicalSessionID: package.runtime.physicalSessionID,
            auditedProjectReportSHA256: package.auditedProjectReportSHA256,
            w46BindingSHA256: computedW46BindingRoot,
            w46AdjudicationStatus: adjudication.status,
            w46AdjudicationReportRootSHA256: adjudication.declaredReportRootSHA256,
            limitations: limitations,
            declaredCertificateRootSHA256: certificateRoot
        )
        return .init(adjudicationReport: adjudication, certificate: certificate)
    }

    static func validateProvenance(
        _ provenance: AnalysisPhysicalRealAudioProjectProvenance,
        expectation: AnalysisPhysicalRealAudioParityBridgeExpectation,
        binding: AnalysisAnalysisParityEvidenceBinding
    ) -> [AnalysisPhysicalRealAudioParityBridgeIssue] {
        var issues: [AnalysisPhysicalRealAudioParityBridgeIssue] = []
        if provenance.packageRootSHA256 != expectation.expectedW47PackageRootSHA256
            || provenance.packageBytesSHA256 != expectation.expectedW47PackageBytesSHA256 {
            issues.append(.init(code: .packageRootMismatch, detail: "observed W47 package root/bytes differ from the independent expectation"))
        }
        if provenance.manifestID != expectation.expectedManifestID
            || provenance.manifestSHA256 != expectation.expectedManifestSHA256
            || binding.manifestID != provenance.manifestID
            || binding.manifestSHA256 != provenance.manifestSHA256 {
            issues.append(.init(code: .manifestRootMismatch, detail: "W47 and W46 do not share one exact manifest identity/root"))
        }
        if provenance.runtimeBindingSHA256 != expectation.expectedRuntimeBindingSHA256 {
            issues.append(.init(code: .runtimeBindingMismatch, detail: "observed runtime root differs from the independent expectation"))
        }
        if provenance.physicalSessionID != expectation.expectedPhysicalSessionID
            || binding.projectCaptureSessionID != provenance.physicalSessionID {
            issues.append(.init(code: .physicalSessionMismatch, detail: "W46 Project capture-session identity is not the W47 physical session"))
        }
        if provenance.projectReportSHA256 != expectation.expectedAuditedProjectReportSHA256
            || binding.expectedProjectReportSHA256 != provenance.projectReportSHA256 {
            issues.append(.init(code: .projectReportMismatch, detail: "W46 Project report root is not the reopened W47 audited Project report root"))
        }

        let exactProjectBinding = binding.expectedProjectEngine == provenance.engine
            && binding.expectedProjectEngineVersion == provenance.engineVersion
            && binding.projectPlatform == provenance.platform
            && binding.projectArchitecture == provenance.architecture
            && binding.projectSourceRevision == provenance.sourceRevision
            && binding.projectBuildIdentity == provenance.buildIdentity
            && binding.projectDeviceModel == provenance.deviceModel
            && binding.projectOSVersion == provenance.osVersion
            && binding.projectCaptureSessionID == provenance.physicalSessionID
        if !exactProjectBinding {
            issues.append(.init(code: .w46ProjectBindingMismatch, detail: "every W46 Project engine/platform/build/device/session field must equal the reopened W47 runtime package"))
        }
        return sorted(issues)
    }

    private static func validateExpectation(
        _ expectation: AnalysisPhysicalRealAudioParityBridgeExpectation
    ) -> [AnalysisPhysicalRealAudioParityBridgeIssue] {
        let strings = [
            expectation.approvalReference,
            expectation.bridgeID,
            expectation.expectedManifestID,
            expectation.expectedPhysicalSessionID
        ]
        let hashes = [
            expectation.expectedW47PackageRootSHA256,
            expectation.expectedW47PackageBytesSHA256,
            expectation.expectedManifestSHA256,
            expectation.expectedRuntimeBindingSHA256,
            expectation.expectedAuditedProjectReportSHA256,
            expectation.expectedW46BindingSHA256
        ] + expectation.previouslyConsumedW47PackageRootSHA256s
        let valid = expectation.schemaVersion == 1
            && expectation.authority == requiredAuthority
            && strings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && hashes.allSatisfy(isSHA256)
            && expectation.previouslyConsumedW47PackageRootSHA256s == expectation.previouslyConsumedW47PackageRootSHA256s.sorted()
            && Set(expectation.previouslyConsumedW47PackageRootSHA256s).count == expectation.previouslyConsumedW47PackageRootSHA256s.count
        return valid ? [] : [.init(code: .invalidExpectation, detail: "HQ W48 expectation must be complete, canonical, unique and SHA-256 pinned")]
    }

    private static func validateW46EvidenceRoots(
        manifestID: String,
        manifestSHA256: String,
        projectEngine: String,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        captureSet: AnalysisReferenceCaptureSet,
        capturePolicy: AnalysisReferenceCapturePolicy,
        reviewSet: AnalysisReferenceReviewSet,
        reviewPolicy: AnalysisReferenceReviewConsensusPolicy,
        toleranceProfile: AnalysisDifferentialToleranceProfile,
        binding: AnalysisAnalysisParityEvidenceBinding
    ) -> [AnalysisPhysicalRealAudioParityBridgeIssue] {
        let coverageRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(coveragePolicy)
        let captureSetRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet)
        let capturePolicyRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(capturePolicy)
        let reviewSetRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewSet)
        let reviewPolicyRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(reviewPolicy)
        let toleranceRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(toleranceProfile)

        let sameManifest = coveragePolicy.expectedManifestID == manifestID
            && coveragePolicy.expectedManifestSHA256 == manifestSHA256
            && capturePolicy.expectedSourceManifestID == manifestID
            && capturePolicy.expectedSourceManifestSHA256 == manifestSHA256
            && reviewSet.sourceManifestID == manifestID
            && reviewSet.sourceManifestSHA256 == manifestSHA256
        let rootsMatch = coverageRoot != nil
            && captureSetRoot != nil
            && capturePolicyRoot != nil
            && reviewSetRoot != nil
            && reviewPolicyRoot != nil
            && toleranceRoot != nil
            && binding.expectedCoveragePolicyID == coveragePolicy.policyID
            && binding.expectedCoveragePolicySHA256 == coverageRoot!
            && binding.expectedCaptureSetID == captureSet.captureSetID
            && binding.expectedCaptureSetSHA256 == captureSetRoot!
            && binding.expectedCapturePolicyID == capturePolicy.policyID
            && binding.expectedCapturePolicySHA256 == capturePolicyRoot!
            && binding.expectedReviewSetID == reviewSet.reviewSetID
            && binding.expectedReviewSetSHA256 == reviewSetRoot!
            && binding.expectedReviewPolicyID == reviewPolicy.policyID
            && binding.expectedReviewPolicySHA256 == reviewPolicyRoot!
            && binding.expectedToleranceProfileID == toleranceProfile.profileID
            && binding.expectedToleranceProfileSHA256 == toleranceRoot!
            && toleranceProfile.expectedProjectEngine == projectEngine
            && toleranceProfile.expectedReferenceEngine == binding.expectedReferenceEngine
        return sameManifest && rootsMatch
            ? []
            : [.init(code: .w46EvidenceRootMismatch, detail: "W46 policy/capture/review/tolerance roots must be the exact objects pinned by the binding and must all reference the W47 manifest")]
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains(Int($0.value)) || (97...102).contains(Int($0.value))
        }
    }

    private static func sorted(
        _ issues: [AnalysisPhysicalRealAudioParityBridgeIssue]
    ) -> [AnalysisPhysicalRealAudioParityBridgeIssue] {
        issues.sorted {
            if $0.code.rawValue != $1.code.rawValue { return $0.code.rawValue < $1.code.rawValue }
            return $0.detail < $1.detail
        }
    }
}
