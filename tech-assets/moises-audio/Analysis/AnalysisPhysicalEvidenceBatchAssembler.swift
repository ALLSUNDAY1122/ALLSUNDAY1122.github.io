import Foundation

public enum AnalysisPhysicalEvidenceBatchAssembler {
    public static func assemble(
        publicationID: String,
        archiveRootURL: URL,
        singletonArtifacts: [AnalysisPhysicalEvidenceBatchSingletonArtifact],
        w27Policy: AnalysisPhysicalEvidenceArchivePolicy,
        chainTemplate: AnalysisPhysicalEvidenceBatchChainPolicyTemplate,
        coveragePolicy: AnalysisCorpusCoveragePolicy,
        selectionPolicy: AnalysisDeviceCorpusSelectionPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceBatchAssembly {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(publicationID) else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.unsafePublicationID
        }

        let plannedRunIDs = performanceProfile.plannedRuns.map(\.runID)
        let plannedSet = Set(plannedRunIDs)
        guard !plannedRunIDs.isEmpty,
              plannedSet.count == plannedRunIDs.count,
              plannedRunIDs.allSatisfy(AnalysisPhysicalEvidenceW39BatchLoader.safeComponent),
              Set(w27Policy.requiredRunIDs) == plannedSet,
              w27Policy.requiredRunIDs.count == plannedRunIDs.count,
              Set(chainTemplate.requiredRunIDs) == plannedSet,
              chainTemplate.requiredRunIDs.count == plannedRunIDs.count else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.invalidRunInventory
        }

        guard w27Policy.schemaVersion == 1,
              w27Policy.authority == AnalysisPhysicalEvidenceArchiveValidator.requiredAuthority,
              w27Policy.binding.performanceProfileID == performanceProfile.profileID,
              w27Policy.binding.batchID == performanceProfile.expectedBatchID,
              w27Policy.binding.manifestID == performanceProfile.expectedManifestID,
              w27Policy.binding.manifestSHA256 == performanceProfile.expectedManifestSHA256.lowercased(),
              w27Policy.binding.workloadApprovalReference == workloadPolicy.approvalReference,
              w27Policy.binding.buildIdentity == workloadPolicy.identity.buildIdentity else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.invalidW27Policy
        }

        guard chainTemplate.schemaVersion == 1,
              chainTemplate.authority == AnalysisPhysicalEvidenceArchiveChainValidator.requiredAuthority,
              chainTemplate.legacyW27PolicyID == w27Policy.policyID,
              chainTemplate.legacyW27ArchiveID == w27Policy.expectedArchiveID,
              chainTemplate.binding == w27Policy.binding else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.invalidW38Template
        }

        let requiredSingletonRoles = AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles
        let suppliedRoles = singletonArtifacts.map(\.role)
        guard singletonArtifacts.count == requiredSingletonRoles.count,
              Set(suppliedRoles).count == singletonArtifacts.count,
              Set(suppliedRoles) == requiredSingletonRoles else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.invalidSingletonInventory
        }

        let singletonPrefix = "batches/\(publicationID)/singletons"
        let storedSingletons: [AnalysisPhysicalEvidenceBatchStoredSingleton] = try singletonArtifacts.map { value in
            guard !value.role.isPerRun, !value.bytes.isEmpty else {
                throw AnalysisPhysicalEvidenceBatchAssemblyError.invalidSingletonArtifact
            }
            let filename = value.role.rawValue.lowercased().replacingOccurrences(of: "_", with: "-") + ".json"
            return .init(
                role: value.role,
                relativePath: "\(singletonPrefix)/\(filename)",
                bytes: value.bytes
            )
        }.sorted { $0.relativePath < $1.relativePath }

        var runBundles: [AnalysisPhysicalCaptureArtifactBundle] = []
        var executionOwners: [String: String] = [:]
        for runID in plannedRunIDs.sorted() {
            let bundle = try AnalysisPhysicalEvidenceW39BatchLoader.load(
                runID: runID,
                archiveRootURL: archiveRootURL,
                fileManager: fileManager
            )
            if executionOwners[bundle.workloadExecutionID] != nil {
                throw AnalysisPhysicalEvidenceBatchAssemblyError.reusedExecutionID
            }
            executionOwners[bundle.workloadExecutionID] = runID
            runBundles.append(bundle)
        }

        var w27Entries = storedSingletons.map {
            AnalysisPhysicalEvidenceArchiveBuilder.entry(role: $0.role, relativePath: $0.relativePath, bytes: $0.bytes)
        }
        var w27Bytes = Dictionary(uniqueKeysWithValues: storedSingletons.map { ($0.relativePath, $0.bytes) })
        for bundle in runBundles {
            w27Entries.append(contentsOf: bundle.legacyW27Entries)
            let declaredPaths = Set(bundle.legacyW27Entries.map(\.relativePath))
            for artifact in bundle.artifacts where declaredPaths.contains(artifact.relativePath) {
                guard w27Bytes[artifact.relativePath] == nil else {
                    throw AnalysisPhysicalEvidenceBatchAssemblyError.w27ValidationFailed
                }
                w27Bytes[artifact.relativePath] = artifact.bytes
            }
        }

        let w27Manifest: AnalysisPhysicalEvidenceArchiveManifest
        do {
            w27Manifest = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
                archiveID: w27Policy.expectedArchiveID,
                policyID: w27Policy.policyID,
                binding: w27Policy.binding,
                entries: w27Entries
            )
        } catch {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.w27ValidationFailed
        }
        let w27Report = AnalysisPhysicalEvidenceArchiveValidator.validate(
            manifest: w27Manifest,
            policy: w27Policy,
            artifactBytesByPath: w27Bytes,
            coveragePolicy: coveragePolicy,
            selectionPolicy: selectionPolicy,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy
        )
        guard w27Report.status == .rootConsistentPendingHQ,
              w27Report.issues.isEmpty,
              w27Report.computedRootSHA256 == w27Manifest.declaredRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.w27ValidationFailed
        }

        let w38Policy = AnalysisPhysicalEvidenceArchiveChainPolicy(
            policyID: chainTemplate.policyID,
            authority: chainTemplate.authority,
            approvalReference: chainTemplate.approvalReference,
            expectedArchiveID: chainTemplate.expectedArchiveID,
            legacyW27PolicyID: chainTemplate.legacyW27PolicyID,
            legacyW27ArchiveID: chainTemplate.legacyW27ArchiveID,
            legacyW27RootSHA256: w27Manifest.declaredRootSHA256,
            binding: chainTemplate.binding,
            requiredRunIDs: chainTemplate.requiredRunIDs
        )

        var w38Entries: [AnalysisPhysicalEvidenceChainEntry] = []
        var w38Bytes: [String: Data] = [:]
        for bundle in runBundles {
            w38Entries.append(contentsOf: bundle.w38Entries)
            let declaredPaths = Set(bundle.w38Entries.map(\.relativePath))
            for artifact in bundle.artifacts where declaredPaths.contains(artifact.relativePath) {
                guard w38Bytes[artifact.relativePath] == nil else {
                    throw AnalysisPhysicalEvidenceBatchAssemblyError.w38ValidationFailed
                }
                w38Bytes[artifact.relativePath] = artifact.bytes
            }
        }

        let w38Manifest: AnalysisPhysicalEvidenceArchiveChainManifest
        do {
            w38Manifest = try AnalysisPhysicalEvidenceArchiveChainBuilder.manifest(
                archiveID: w38Policy.expectedArchiveID,
                policyID: w38Policy.policyID,
                legacyW27ArchiveID: w38Policy.legacyW27ArchiveID,
                legacyW27RootSHA256: w38Policy.legacyW27RootSHA256,
                binding: w38Policy.binding,
                entries: w38Entries
            )
        } catch {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.w38ValidationFailed
        }
        let w38Report = AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict(
            manifest: w38Manifest,
            policy: w38Policy,
            legacyManifest: w27Manifest,
            legacyPolicy: w27Policy,
            legacyReport: w27Report,
            artifactBytesByPath: w38Bytes,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy
        )
        guard w38Report.status == .rootConsistentPendingHQ,
              w38Report.issues.isEmpty,
              w38Report.computedRootSHA256 == w38Manifest.declaredRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.w38ValidationFailed
        }

        let summaries = runBundles.map {
            AnalysisPhysicalEvidenceBatchRunSummary(
                runID: $0.runID,
                workloadExecutionID: $0.workloadExecutionID,
                w39BundleRootSHA256: $0.bundleRootSHA256
            )
        }.sorted { $0.runID < $1.runID }

        let root: String
        do {
            root = try computeBatchRoot(
                publicationID: publicationID,
                runs: summaries,
                singletons: storedSingletons,
                w27Root: w27Manifest.declaredRootSHA256,
                w38Root: w38Manifest.declaredRootSHA256
            )
        } catch {
            throw AnalysisPhysicalEvidenceBatchAssemblyError.batchRootFailure
        }

        return .init(
            publicationID: publicationID,
            batchRootSHA256: root,
            runSummaries: summaries,
            singletons: storedSingletons,
            w27Policy: w27Policy,
            w27Manifest: w27Manifest,
            w27Report: w27Report,
            w38Policy: w38Policy,
            w38Manifest: w38Manifest,
            w38Report: w38Report
        )
    }

    static func computeBatchRoot(
        publicationID: String,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary],
        singletons: [AnalysisPhysicalEvidenceBatchStoredSingleton],
        w27Root: String,
        w38Root: String
    ) throws -> String {
        struct SingletonRecord: Codable {
            let role: AnalysisPhysicalEvidenceArtifactRole
            let relativePath: String
            let sha256: String
            let byteLength: UInt64
        }
        struct Payload: Codable {
            let schemaVersion: Int
            let publicationID: String
            let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
            let singletons: [SingletonRecord]
            let w27RootSHA256: String
            let w38RootSHA256: String
        }
        let payload = Payload(
            schemaVersion: 1,
            publicationID: publicationID,
            runs: runs.sorted { $0.runID < $1.runID },
            singletons: singletons.map {
                SingletonRecord(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
            }.sorted { $0.relativePath < $1.relativePath },
            w27RootSHA256: w27Root.lowercased(),
            w38RootSHA256: w38Root.lowercased()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}
