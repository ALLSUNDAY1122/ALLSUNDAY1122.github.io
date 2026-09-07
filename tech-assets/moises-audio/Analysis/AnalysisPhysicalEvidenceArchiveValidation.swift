import Foundation

public enum AnalysisPhysicalEvidenceArchiveValidator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "The deterministic root detects replacement only after the root has been independently fixed or compared; an attacker who can replace both artifacts and the unanchored manifest can recompute a new internally consistent root.",
        "W27 provides no secret-key signature, Secure Enclave proof, Apple attestation, trusted timestamp, or hardware-origin guarantee.",
        "Build/device corroboration is consistency evidence, not cryptographic device attestation; HQ must independently archive and anchor the final bundle."
    ]

    public static func validate(
        manifest: AnalysisPhysicalEvidenceArchiveManifest,
        policy: AnalysisPhysicalEvidenceArchivePolicy,
        artifactBytesByPath: [String: Data],
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy
    ) -> AnalysisPhysicalEvidenceArchiveReport {
        var issues = validatePolicy(
            policy,
            coveragePolicy: coveragePolicy,
            selectionPolicy: selectionPolicy,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy
        )
        if issues.contains(where: { $0.code == .invalidPolicy }) {
            return report(manifest, policy, status: .invalidPolicy, computedRoot: nil, issues: issues)
        }

        if manifest.schemaVersion != 1 || trimmed(manifest.archiveID).isEmpty || manifest.archiveID != policy.expectedArchiveID || manifest.policyID != policy.policyID {
            issues.append(.init(code: .invalidManifest, detail: "archive manifest must use schema 1 and match the approved archive/policy identifiers"))
        }
        if manifest.binding != policy.binding {
            issues.append(.init(code: .bindingMismatch, detail: "archive binding must exactly match the HQ-approved binding"))
        }
        if !isSHA256(manifest.declaredRootSHA256) {
            issues.append(.init(code: .invalidManifest, detail: "declared archive root must be a SHA-256 hex digest"))
        }

        validateEntries(manifest.entries, requiredRunIDs: policy.requiredRunIDs, issues: &issues)
        validateArtifactBytes(manifest.entries, artifactBytesByPath: artifactBytesByPath, issues: &issues)
        AnalysisPhysicalEvidenceArchiveContentValidator.validate(
            entries: manifest.entries,
            bytesByPath: artifactBytesByPath,
            policy: policy,
            coveragePolicy: coveragePolicy,
            selectionPolicy: selectionPolicy,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy,
            issues: &issues
        )

        let computedRoot = try? AnalysisPhysicalEvidenceArchiveRoot.compute(manifest)
        if computedRoot == nil || computedRoot != manifest.declaredRootSHA256.lowercased() {
            issues.append(.init(code: .archiveRootMismatch, detail: "declared archive root does not match the deterministic canonical root"))
        }

        issues.sort(by: issueOrder)
        let status: AnalysisPhysicalEvidenceArchiveStatus = issues.isEmpty ? .rootConsistentPendingHQ : .incompleteOrTampered
        return report(manifest, policy, status: status, computedRoot: computedRoot, issues: issues)
    }

    private static func validatePolicy(
        _ p: AnalysisPhysicalEvidenceArchivePolicy,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy
    ) -> [AnalysisPhysicalEvidenceArchiveIssue] {
        var issues: [AnalysisPhysicalEvidenceArchiveIssue] = []
        let text = [p.policyID, p.approvalReference, p.expectedArchiveID, p.binding.manifestID,
                    p.binding.coveragePolicyID, p.binding.selectionPolicyID, p.binding.performanceProfileID,
                    p.binding.batchID, p.binding.workloadApprovalReference, p.binding.buildIdentity,
                    p.binding.deviceModel, p.binding.osVersion]
        if p.schemaVersion != 1 || p.authority != requiredAuthority || text.contains(where: { trimmed($0).isEmpty }) || !isSHA256(p.binding.manifestSHA256) {
            issues.append(.init(code: .invalidPolicy, detail: "archive policy requires schema 1, HQ authority, nonempty bindings and a valid manifest SHA-256"))
        }
        let runs = Set(p.requiredRunIDs)
        if p.requiredRunIDs.isEmpty || runs.count != p.requiredRunIDs.count || p.requiredRunIDs.contains(where: { trimmed($0).isEmpty }) {
            issues.append(.init(code: .invalidRunInventory, detail: "required run IDs must be nonempty and unique"))
        }
        let planned = Set(performanceProfile.plannedRuns.map(\.runID))
        if runs != planned || planned.count != performanceProfile.plannedRuns.count {
            issues.append(.init(code: .invalidRunInventory, detail: "archive run inventory must exactly equal the W24 predeclared run inventory"))
        }
        let b = p.binding
        if b.manifestID != coveragePolicy.expectedManifestID || b.manifestID != selectionPolicy.expectedManifestID || b.manifestID != performanceProfile.expectedManifestID || b.manifestID != workloadPolicy.manifestID ||
            b.manifestSHA256 != coveragePolicy.expectedManifestSHA256 || b.manifestSHA256 != selectionPolicy.expectedManifestSHA256 || b.manifestSHA256 != performanceProfile.expectedManifestSHA256 || b.manifestSHA256 != workloadPolicy.manifestSHA256 ||
            b.coveragePolicyID != coveragePolicy.policyID || b.selectionPolicyID != selectionPolicy.policyID ||
            b.performanceProfileID != performanceProfile.profileID || b.batchID != performanceProfile.expectedBatchID ||
            b.workloadApprovalReference != workloadPolicy.approvalReference || b.buildIdentity != workloadPolicy.identity.buildIdentity ||
            b.deviceModel != performanceProfile.expectedDeviceModel || b.osVersion != performanceProfile.expectedOSVersion {
            issues.append(.init(code: .bindingMismatch, detail: "archive binding must agree with W22/W26/W24/W25 canonical policy bindings"))
        }
        return issues
    }

    private static func validateEntries(
        _ entries: [AnalysisPhysicalEvidenceArchiveEntry],
        requiredRunIDs: [String],
        issues: inout [AnalysisPhysicalEvidenceArchiveIssue]
    ) {
        var paths = Set<String>()
        var singletonCounts: [AnalysisPhysicalEvidenceArtifactRole: Int] = [:]
        var perRunCounts: [String: [AnalysisPhysicalEvidenceArtifactRole: Int]] = [:]
        let requiredRuns = Set(requiredRunIDs)

        for entry in entries {
            if !safeRelativePath(entry.relativePath) {
                issues.append(.init(code: .unsafePath, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "archive paths must be normalized relative paths without traversal"))
            }
            if !paths.insert(entry.relativePath).inserted {
                issues.append(.init(code: .duplicatePath, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "archive path appears more than once"))
            }
            if !isSHA256(entry.sha256) || entry.byteLength == 0 {
                issues.append(.init(code: .invalidEntry, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "artifact entries require nonzero byte length and valid SHA-256"))
            }
            if entry.role.isPerRun {
                guard let runID = entry.runID, !trimmed(runID).isEmpty else {
                    issues.append(.init(code: .invalidEntry, role: entry.role, relativePath: entry.relativePath, detail: "per-run artifact role requires runID")); continue
                }
                if !requiredRuns.contains(runID) {
                    issues.append(.init(code: .unexpectedRunArtifact, role: entry.role, relativePath: entry.relativePath, runID: runID, detail: "artifact run ID is not in the W24 predeclared inventory"))
                }
                var counts = perRunCounts[runID] ?? [:]
                counts[entry.role, default: 0] += 1
                perRunCounts[runID] = counts
            } else {
                if entry.runID != nil {
                    issues.append(.init(code: .invalidEntry, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "singleton artifact role must not carry runID"))
                }
                singletonCounts[entry.role, default: 0] += 1
            }
        }

        for role in AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.sorted(by: { $0.rawValue < $1.rawValue }) {
            let count = singletonCounts[role] ?? 0
            if count == 0 {
                issues.append(.init(code: .missingSingletonRole, role: role, detail: "required singleton archive artifact is missing"))
            } else if count > 1 {
                issues.append(.init(code: .duplicateSingletonRole, role: role, detail: "singleton archive role appears more than once"))
            }
        }
        for runID in requiredRunIDs.sorted() {
            let counts = perRunCounts[runID] ?? [:]
            for role in AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles.sorted(by: { $0.rawValue < $1.rawValue }) {
                let count = counts[role] ?? 0
                if count == 0 {
                    issues.append(.init(code: .missingRunArtifact, role: role, runID: runID, detail: "required per-run archive artifact is missing"))
                } else if count > 1 {
                    issues.append(.init(code: .duplicateRunArtifact, role: role, runID: runID, detail: "per-run archive role appears more than once"))
                }
            }
        }
    }

    private static func validateArtifactBytes(
        _ entries: [AnalysisPhysicalEvidenceArchiveEntry],
        artifactBytesByPath: [String: Data],
        issues: inout [AnalysisPhysicalEvidenceArchiveIssue]
    ) {
        let declared = Set(entries.map(\.relativePath))
        let observed = Set(artifactBytesByPath.keys)
        for path in declared.subtracting(observed).sorted() {
            issues.append(.init(code: .missingArtifactBytes, relativePath: path, detail: "declared artifact bytes are missing from the verification input"))
        }
        for path in observed.subtracting(declared).sorted() {
            issues.append(.init(code: .unexpectedArtifactBytes, relativePath: path, detail: "verification input contains an unmanifested artifact"))
        }
        for entry in entries {
            guard let bytes = artifactBytesByPath[entry.relativePath] else { continue }
            if UInt64(bytes.count) != entry.byteLength {
                issues.append(.init(code: .artifactLengthMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "artifact byte length no longer matches the archived entry"))
            }
            if AnalysisDeviceWorkloadSHA256.hexDigest(bytes) != entry.sha256.lowercased() {
                issues.append(.init(code: .artifactHashMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "artifact SHA-256 no longer matches the archived entry"))
            }
        }
    }

    private static func report(
        _ manifest: AnalysisPhysicalEvidenceArchiveManifest,
        _ policy: AnalysisPhysicalEvidenceArchivePolicy,
        status: AnalysisPhysicalEvidenceArchiveStatus,
        computedRoot: String?,
        issues: [AnalysisPhysicalEvidenceArchiveIssue]
    ) -> AnalysisPhysicalEvidenceArchiveReport {
        .init(
            archiveID: manifest.archiveID,
            status: status,
            computedRootSHA256: computedRoot,
            entryCount: manifest.entries.count,
            runCount: Set(policy.requiredRunIDs).count,
            issues: issues.sorted(by: issueOrder),
            limitations: limitations
        )
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        let trimmedValue = trimmed(value)
        guard !trimmedValue.isEmpty, trimmedValue == value, !value.hasPrefix("/"), !value.hasPrefix("\\") else { return false }
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        guard normalized == value, !normalized.contains("//") else { return false }
        return normalized.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { part in
            part != "." && part != ".." && !part.isEmpty
        }
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

    private static func issueOrder(_ lhs: AnalysisPhysicalEvidenceArchiveIssue, _ rhs: AnalysisPhysicalEvidenceArchiveIssue) -> Bool {
        let l = "\(lhs.code.rawValue)|\(lhs.role?.rawValue ?? "")|\(lhs.runID ?? "")|\(lhs.relativePath ?? "")|\(lhs.detail)"
        let r = "\(rhs.code.rawValue)|\(rhs.role?.rawValue ?? "")|\(rhs.runID ?? "")|\(rhs.relativePath ?? "")|\(rhs.detail)"
        return l < r
    }
}

public enum AnalysisPhysicalEvidenceArchiveCodec {
    public static func encodePolicy(_ value: AnalysisPhysicalEvidenceArchivePolicy) throws -> Data { try encoder().encode(value) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisPhysicalEvidenceArchivePolicy { try decoder().decode(AnalysisPhysicalEvidenceArchivePolicy.self, from: data) }
    public static func encodeManifest(_ value: AnalysisPhysicalEvidenceArchiveManifest) throws -> Data { try encoder().encode(value) }
    public static func decodeManifest(_ data: Data) throws -> AnalysisPhysicalEvidenceArchiveManifest { try decoder().decode(AnalysisPhysicalEvidenceArchiveManifest.self, from: data) }
    public static func encodeReport(_ value: AnalysisPhysicalEvidenceArchiveReport) throws -> Data { try encoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisPhysicalEvidenceArchiveReport { try decoder().decode(AnalysisPhysicalEvidenceArchiveReport.self, from: data) }
    public static func encodeBuildCorroboration(_ value: AnalysisPhysicalEvidenceBuildCorroboration) throws -> Data { try encoder().encode(value) }
    public static func encodeDeviceCorroboration(_ value: AnalysisPhysicalEvidenceDeviceCorroboration) throws -> Data { try encoder().encode(value) }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
