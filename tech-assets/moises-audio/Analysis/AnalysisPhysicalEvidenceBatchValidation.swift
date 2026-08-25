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
              value.w27Manifest.archiveID == value.w27Policy.expectedArchiveID,
              value.w27Manifest.policyID == value.w27Policy.policyID,
              value.w27Manifest.binding == value.w27Policy.binding,
              value.w38Manifest.archiveID == value.w38Policy.expectedArchiveID,
              value.w38Manifest.policyID == value.w38Policy.policyID,
              value.w38Manifest.binding == value.w38Policy.binding,
              value.w38Manifest.legacyW27ArchiveID == value.w27Policy.expectedArchiveID,
              value.w38Policy.legacyW27PolicyID == value.w27Policy.policyID,
              value.w38Policy.legacyW27ArchiveID == value.w27Policy.expectedArchiveID,
              value.w38Policy.legacyW27RootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w38Manifest.legacyW27RootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w27Report.computedRootSHA256 == value.w27Manifest.declaredRootSHA256.lowercased(),
              value.w38Report.computedRootSHA256 == value.w38Manifest.declaredRootSHA256.lowercased(),
              value.w27Report.archiveID == value.w27Manifest.archiveID,
              value.w38Report.archiveID == value.w38Manifest.archiveID,
              value.w27Report.entryCount == value.w27Manifest.entries.count,
              value.w38Report.entryCount == value.w38Manifest.entries.count,
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
              value.w27Policy.requiredRunIDs.count == runIDs.count,
              value.w38Policy.requiredRunIDs.count == runIDs.count,
              value.w27Report.runCount == runIDs.count,
              value.w38Report.runCount == runIDs.count,
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
                  AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(singleton.relativePath),
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

        let requiredRunSet = Set(runIDs)
        for entry in value.w27Manifest.entries {
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(entry.relativePath),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(entry.sha256),
                  entry.byteLength > 0 else { return false }
            if entry.role.isPerRun {
                guard let runID = entry.runID,
                      requiredRunSet.contains(runID),
                      entry.relativePath.hasPrefix("runs/\(runID)/") else { return false }
            } else {
                guard entry.runID == nil,
                      entry.relativePath.hasPrefix("batches/\(value.publicationID)/singletons/") else { return false }
            }
        }
        for entry in value.w38Manifest.entries {
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(entry.relativePath),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(entry.sha256),
                  entry.byteLength > 0,
                  requiredRunSet.contains(entry.runID),
                  entry.relativePath.hasPrefix("runs/\(entry.runID)/") else { return false }
        }

        for runID in runIDs {
            let w27RunEntries = value.w27Manifest.entries.filter { $0.runID == runID }
            guard w27RunEntries.count == AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles.count,
                  Set(w27RunEntries.map(\.role)) == AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles else {
                return false
            }
            let w38RunEntries = value.w38Manifest.entries.filter { $0.runID == runID }
            guard w38RunEntries.count == AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.count,
                  Set(w38RunEntries.map(\.role)) == AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles else {
                return false
            }
        }
        let expectedW27Count = requiredSingletons.count + runIDs.count * AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles.count
        let expectedW38Count = runIDs.count * AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.count
        guard value.w27Manifest.entries.count == expectedW27Count,
              value.w38Manifest.entries.count == expectedW38Count,
              Set(value.w27Manifest.entries.map(\.relativePath)).count == expectedW27Count,
              Set(value.w38Manifest.entries.map(\.relativePath)).count == expectedW38Count else {
            return false
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
