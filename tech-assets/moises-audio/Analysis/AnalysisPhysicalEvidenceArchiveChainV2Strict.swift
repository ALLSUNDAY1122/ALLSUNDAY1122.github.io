import Foundation

public extension AnalysisPhysicalEvidenceArchiveChainValidator {
    /// Canonical W38 entrypoint. In addition to the chain checks performed by
    /// `validate`, this recomputes the parent W27 manifest root locally and
    /// rejects malformed W24 run inventories before the inner validator builds
    /// its exact-run lookup table.
    static func validateStrict(
        manifest: AnalysisPhysicalEvidenceArchiveChainManifest,
        policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        legacyManifest: AnalysisPhysicalEvidenceArchiveManifest,
        legacyPolicy: AnalysisPhysicalEvidenceArchivePolicy,
        legacyReport: AnalysisPhysicalEvidenceArchiveReport,
        artifactBytesByPath: [String: Data],
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy
    ) -> AnalysisPhysicalEvidenceArchiveChainReport {
        let plannedIDs = performanceProfile.plannedRuns.map(\.runID)
        let uniquePlannedIDs = Set(plannedIDs)
        let requiredIDs = Set(policy.requiredRunIDs)
        let runInventoryValid = !plannedIDs.isEmpty
            && plannedIDs.count == uniquePlannedIDs.count
            && policy.requiredRunIDs.count == requiredIDs.count
            && !policy.requiredRunIDs.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && uniquePlannedIDs == requiredIDs

        guard runInventoryValid else {
            let issue = AnalysisPhysicalEvidenceArchiveChainIssue(
                code: .invalidRunInventory,
                detail: "W38 strict validation requires one unique W24 planned record for every and only every required archive run ID"
            )
            return .init(
                archiveID: manifest.archiveID,
                status: .invalidPolicy,
                computedRootSHA256: nil,
                entryCount: manifest.entries.count,
                runCount: requiredIDs.count,
                issues: [issue],
                limitations: limitations
            )
        }

        let recomputedLegacyRoot = try? AnalysisPhysicalEvidenceArchiveRoot.compute(legacyManifest)
        let expected = policy.legacyW27RootSHA256.lowercased()
        let reportRoot = legacyReport.computedRootSHA256?.lowercased()
        let declared = legacyManifest.declaredRootSHA256.lowercased()
        let legacyAnchorValid = recomputedLegacyRoot == expected
            && declared == expected
            && reportRoot == expected
            && legacyReport.status == .rootConsistentPendingHQ
            && legacyReport.archiveID == legacyManifest.archiveID
            && legacyReport.entryCount == legacyManifest.entries.count
            && legacyReport.runCount == Set(legacyPolicy.requiredRunIDs).count
            && legacyReport.issues.isEmpty

        guard legacyAnchorValid else {
            let issue = AnalysisPhysicalEvidenceArchiveChainIssue(
                code: .legacyArchiveNotReady,
                detail: "W38 strict validation recomputed the W27 manifest root and it did not exactly match the independently supplied parent root/report inventory"
            )
            return .init(
                archiveID: manifest.archiveID,
                status: .legacyArchiveNotReady,
                computedRootSHA256: nil,
                entryCount: manifest.entries.count,
                runCount: requiredIDs.count,
                issues: [issue],
                limitations: limitations
            )
        }

        return validate(
            manifest: manifest,
            policy: policy,
            legacyManifest: legacyManifest,
            legacyPolicy: legacyPolicy,
            legacyReport: legacyReport,
            artifactBytesByPath: artifactBytesByPath,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy
        )
    }
}
