import Foundation

public enum AnalysisPhysicalEvidenceBatchAssemblyValidator {
    public static func validate(_ value: AnalysisPhysicalEvidenceBatchAssembly) -> Bool {
        guard value.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(value.publicationID),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value.batchRootSHA256),
              value.w27Report.status == .rootConsistentPendingHQ,
              value.w27Report.issues.isEmpty,
              value.w38Report.status == .rootConsistentPendingHQ,
              value.w38Report.issues.isEmpty,
              value.w38Policy.legacyW27RootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w38Manifest.legacyW27RootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w27Report.computedRootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w38Report.computedRootSHA256 == value.w38Manifest.declaredRootSHA256.lowercased(),
              (try? AnalysisPhysicalEvidenceArchiveRoot.compute(value.w27Manifest)) == value.w27Manifest.declaredRootSHA256.lowercased(),
              (try? AnalysisPhysicalEvidenceArchiveChainRoot.compute(value.w38Manifest)) == value.w38Manifest.declaredRootSHA256.lowercased() else {
            return false
        }

        let runIDs = value.runSummaries.map(\.runID)
        let executionIDs = value.runSummaries.map(\.workloadExecutionID)
        guard !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count,
              Set(runIDs) == Set(value.w27Policy.requiredRunIDs),
              Set(runIDs) == Set(value.w38Policy.requiredRunIDs),
              value.runSummaries.allSatisfy {
                  AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.runID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.workloadExecutionID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0.w39BundleRootSHA256)
              } else {
            return false
        }

        let requiredSingletons = AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles
        guard value.singletons.count == requiredSingletons.count,
              Set(value.singletons.map(\.role)) == requiredSingletons,
              Set(value.singletons.map(\.relativePath)).count == value.singletons.count else {
            return false
        }
        for singleton in value.singletons {
            guard !singleton.role.isPerRun,
                  !singleton.bytes.isEmpty,
                  singleton.byteLength == UInt64(singleton.bytes.count),
                  AnalysisDeviceWorkloadSHA256.hexDigest(singleton.bytes) == singleton.sha256,
                  singleton.relativePath.hasPrefix("batches/\(value.publicationID)/singletons/") else {
                return false
            }
        }

        let declaredSingletonEntries = value.w27Manifest.entries.filter { !$0.role.isPerRun }
        guard declaredSingletonEntries.count == value.singletons.count else { return false }
        for singleton in value.singletons {
            guard declaredSingletonEntries.contains(where: {
                $0.role == singleton.role
                    && $0.relativePath == singleton.relativePath
                    && $0.sha256 == singleton.sha256
                    && $0.byteLength == singleton.byteLength
                    && $0.runID == nil
            }) else { return false }
        }

        let root = try? AnalysisPhysicalEvidenceBatchAssembler.computeBatchRoot(
            publicationID: value.publicationID,
            runs: value.runSummaries,
            singletons: value.singletons,
            w27Root: value.w27Manifest.declaredRootSHA256,
            w38Root: value.w38Manifest.declaredRootSHA256
        )
        return root == value.batchRootSHA256.lowercased()
    }
}
