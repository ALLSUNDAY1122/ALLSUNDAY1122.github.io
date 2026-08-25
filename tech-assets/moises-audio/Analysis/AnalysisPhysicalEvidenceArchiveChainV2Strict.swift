import Foundation

public extension AnalysisPhysicalEvidenceArchiveChainValidator {
    /// Canonical W38 entrypoint. In addition to the chain checks performed by
    /// `validate`, this recomputes the parent W27 manifest root locally so a
    /// forged/root-consistent-looking W27 report cannot be accepted by itself.
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
                runCount: Set(policy.requiredRunIDs).count,
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
