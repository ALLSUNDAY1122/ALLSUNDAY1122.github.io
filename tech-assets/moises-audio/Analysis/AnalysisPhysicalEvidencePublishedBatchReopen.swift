import Foundation

public enum AnalysisPhysicalEvidencePublishedBatchReopener {
    public static func reopen(
        publicationID: String,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceReopenedBatch {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(publicationID) else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafePublicationID
        }
        let batchPrefix = "batches/\(publicationID)"
        let batchDirectory = archiveRootURL.appendingPathComponent(batchPrefix, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: batchDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.missingBatchDirectory
        }

        let controlPath = "\(batchPrefix)/\(AnalysisPhysicalEvidenceBatchStager.publicationManifestFileName)"
        let controlBytes = try readStrict(controlPath, root: archiveRootURL, fileManager: fileManager)
        let control: AnalysisPhysicalEvidenceBatchStagingManifest
        do { control = try JSONDecoder().decode(AnalysisPhysicalEvidenceBatchStagingManifest.self, from: controlBytes) }
        catch { throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidW40Control }

        let runIDs = control.runs.map(\.runID)
        let executionIDs = control.runs.map(\.workloadExecutionID)
        guard control.schemaVersion == 1,
              control.state == .readyToPublish,
              control.publicationID == publicationID,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.batchRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w27RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w38RootSHA256),
              !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count,
              control.runs.allSatisfy {
                  AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.runID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.workloadExecutionID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0.w39BundleRootSHA256)
              } else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidW40Control
        }

        let requiredSingletons = AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles
        guard control.singletons.count == requiredSingletons.count,
              Set(control.singletons.map(\.role)) == requiredSingletons,
              Set(control.singletons.map(\.relativePath)).count == control.singletons.count else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidSingletonInventory
        }

        let fixed: [(AnalysisPhysicalEvidenceTransferItemKind, String)] = [
            (.w27Policy, "\(batchPrefix)/w27-policy.json"),
            (.w27Manifest, "\(batchPrefix)/w27-manifest.json"),
            (.w27Report, "\(batchPrefix)/w27-report.json"),
            (.w38Policy, "\(batchPrefix)/w38-policy.json"),
            (.w38Manifest, "\(batchPrefix)/w38-manifest.json"),
            (.w38Report, "\(batchPrefix)/w38-report.json")
        ]
        var fixedBytes: [AnalysisPhysicalEvidenceTransferItemKind: Data] = [:]
        var items: [AnalysisPhysicalEvidenceReopenedItem] = [
            .init(kind: .w40Control, sourceRelativePath: controlPath, bytes: controlBytes)
        ]
        for (kind, path) in fixed {
            let bytes = try readStrict(path, root: archiveRootURL, fileManager: fileManager)
            fixedBytes[kind] = bytes
            items.append(.init(kind: kind, sourceRelativePath: path, bytes: bytes))
        }

        let w27Policy: AnalysisPhysicalEvidenceArchivePolicy
        let w27Manifest: AnalysisPhysicalEvidenceArchiveManifest
        let cachedW27Report: AnalysisPhysicalEvidenceArchiveReport
        let w38Policy: AnalysisPhysicalEvidenceArchiveChainPolicy
        let w38Manifest: AnalysisPhysicalEvidenceArchiveChainManifest
        let cachedW38Report: AnalysisPhysicalEvidenceArchiveChainReport
        do {
            w27Policy = try AnalysisPhysicalEvidenceArchiveCodec.decodePolicy(fixedBytes[.w27Policy]!)
            w27Manifest = try AnalysisPhysicalEvidenceArchiveCodec.decodeManifest(fixedBytes[.w27Manifest]!)
            cachedW27Report = try AnalysisPhysicalEvidenceArchiveCodec.decodeReport(fixedBytes[.w27Report]!)
            w38Policy = try AnalysisPhysicalEvidenceArchiveChainCodec.decodePolicy(fixedBytes[.w38Policy]!)
            w38Manifest = try AnalysisPhysicalEvidenceArchiveChainCodec.decodeManifest(fixedBytes[.w38Manifest]!)
            cachedW38Report = try AnalysisPhysicalEvidenceArchiveChainCodec.decodeReport(fixedBytes[.w38Report]!)
        } catch {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidArchiveDocuments
        }

        let runSet = Set(runIDs)
        guard w27Policy.schemaVersion == 1,
              w27Policy.authority == AnalysisPhysicalEvidenceArchiveValidator.requiredAuthority,
              w27Policy.expectedArchiveID == control.w27ArchiveID,
              Set(w27Policy.requiredRunIDs) == runSet,
              w27Policy.requiredRunIDs.count == runIDs.count,
              w27Manifest.schemaVersion == 1,
              w27Manifest.archiveID == w27Policy.expectedArchiveID,
              w27Manifest.policyID == w27Policy.policyID,
              w27Manifest.binding == w27Policy.binding,
              w38Policy.schemaVersion == 2,
              w38Policy.authority == AnalysisPhysicalEvidenceArchiveChainValidator.requiredAuthority,
              w38Policy.expectedArchiveID == control.w38ArchiveID,
              Set(w38Policy.requiredRunIDs) == runSet,
              w38Policy.requiredRunIDs.count == runIDs.count,
              w38Policy.legacyW27PolicyID == w27Policy.policyID,
              w38Policy.legacyW27ArchiveID == w27Manifest.archiveID,
              w38Manifest.schemaVersion == 2,
              w38Manifest.archiveID == w38Policy.expectedArchiveID,
              w38Manifest.policyID == w38Policy.policyID,
              w38Manifest.binding == w38Policy.binding,
              w38Manifest.legacyW27ArchiveID == w27Manifest.archiveID else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidArchiveDocuments
        }

        var storedSingletons: [AnalysisPhysicalEvidenceBatchStoredSingleton] = []
        let singletonPrefix = "\(batchPrefix)/singletons/"
        for record in control.singletons.sorted(by: { $0.relativePath < $1.relativePath }) {
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(record.relativePath),
                  record.relativePath.hasPrefix(singletonPrefix),
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(record.sha256),
                  record.byteLength > 0 else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidSingletonInventory
            }
            let bytes = try readStrict(record.relativePath, root: archiveRootURL, fileManager: fileManager)
            guard UInt64(bytes.count) == record.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == record.sha256.lowercased() else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.singletonMismatch(record.relativePath)
            }
            storedSingletons.append(.init(role: record.role, relativePath: record.relativePath, bytes: bytes))
            items.append(.init(kind: .singleton, sourceRelativePath: record.relativePath, role: record.role.rawValue, bytes: bytes))
        }

        var bundles: [AnalysisPhysicalCaptureArtifactBundle] = []
        for summary in control.runs.sorted(by: { $0.runID < $1.runID }) {
            let bundle: AnalysisPhysicalCaptureArtifactBundle
            do {
                bundle = try AnalysisPhysicalEvidenceW39BatchLoader.load(
                    runID: summary.runID,
                    archiveRootURL: archiveRootURL,
                    fileManager: fileManager
                )
            } catch {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidW39Run(summary.runID)
            }
            guard bundle.workloadExecutionID == summary.workloadExecutionID,
                  bundle.bundleRootSHA256 == summary.w39BundleRootSHA256.lowercased() else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.invalidW39Run(summary.runID)
            }
            bundles.append(bundle)
            let w39ControlPath = "runs/\(summary.runID)/\(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName)"
            let w39ControlBytes = try readStrict(w39ControlPath, root: archiveRootURL, fileManager: fileManager)
            items.append(.init(kind: .w39Control, sourceRelativePath: w39ControlPath, runID: summary.runID, bytes: w39ControlBytes))
            for artifact in bundle.artifacts {
                items.append(.init(
                    kind: .w39Artifact,
                    sourceRelativePath: artifact.relativePath,
                    runID: summary.runID,
                    role: artifact.role.rawValue,
                    bytes: artifact.bytes
                ))
            }
        }

        let recomputedW27Root = try AnalysisPhysicalEvidenceArchiveRoot.compute(w27Manifest)
        guard recomputedW27Root == w27Manifest.declaredRootSHA256.lowercased(),
              recomputedW27Root == control.w27RootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.w27RootDrift
        }
        let expectedW27Report = AnalysisPhysicalEvidenceArchiveReport(
            archiveID: w27Manifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: recomputedW27Root,
            entryCount: w27Manifest.entries.count,
            runCount: runSet.count,
            issues: [],
            limitations: AnalysisPhysicalEvidenceArchiveValidator.limitations
        )
        guard cachedW27Report == expectedW27Report else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.staleW27Report
        }

        guard w38Policy.legacyW27RootSHA256.lowercased() == recomputedW27Root,
              w38Manifest.legacyW27RootSHA256.lowercased() == recomputedW27Root else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.w38RootDrift
        }
        let recomputedW38Root = try AnalysisPhysicalEvidenceArchiveChainRoot.compute(w38Manifest)
        guard recomputedW38Root == w38Manifest.declaredRootSHA256.lowercased(),
              recomputedW38Root == control.w38RootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.w38RootDrift
        }
        let expectedW38Report = AnalysisPhysicalEvidenceArchiveChainReport(
            archiveID: w38Manifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: recomputedW38Root,
            entryCount: w38Manifest.entries.count,
            runCount: runSet.count,
            issues: [],
            limitations: AnalysisPhysicalEvidenceArchiveChainValidator.limitations
        )
        guard cachedW38Report == expectedW38Report else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.staleW38Report
        }

        let recomputedW40Root = try AnalysisPhysicalEvidenceBatchAssembler.computeBatchRoot(
            publicationID: publicationID,
            runs: control.runs,
            singletons: storedSingletons,
            w27Root: recomputedW27Root,
            w38Root: recomputedW38Root
        )
        guard recomputedW40Root == control.batchRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.w40RootDrift
        }

        let reopenedAssembly = AnalysisPhysicalEvidenceBatchAssembly(
            publicationID: publicationID,
            batchRootSHA256: recomputedW40Root,
            runSummaries: control.runs,
            singletons: storedSingletons,
            w27Policy: w27Policy,
            w27Manifest: w27Manifest,
            w27Report: expectedW27Report,
            w38Policy: w38Policy,
            w38Manifest: w38Manifest,
            w38Report: expectedW38Report
        )
        guard AnalysisPhysicalEvidenceBatchAssemblyValidator.validate(reopenedAssembly) else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.reopenedAssemblyInvalid
        }

        try validateManifestEntries(
            w27Manifest: w27Manifest,
            w38Manifest: w38Manifest,
            singletons: storedSingletons,
            bundles: bundles
        )

        let sourcePaths = items.map(\.sourceRelativePath)
        guard Set(sourcePaths).count == sourcePaths.count,
              items.count == 18 + (10 * runIDs.count) else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.duplicateTransferSourcePath
        }

        return .init(
            publicationID: publicationID,
            w40RootSHA256: recomputedW40Root,
            w27RootSHA256: recomputedW27Root,
            w38RootSHA256: recomputedW38Root,
            runSummaries: control.runs,
            items: items
        )
    }

    private static func validateManifestEntries(
        w27Manifest: AnalysisPhysicalEvidenceArchiveManifest,
        w38Manifest: AnalysisPhysicalEvidenceArchiveChainManifest,
        singletons: [AnalysisPhysicalEvidenceBatchStoredSingleton],
        bundles: [AnalysisPhysicalCaptureArtifactBundle]
    ) throws {
        var expectedW27: [String: (String, UInt64, String, String?)] = [:]
        for value in singletons {
            expectedW27[value.relativePath] = (value.sha256, value.byteLength, value.role.rawValue, nil)
        }
        for bundle in bundles {
            for value in bundle.legacyW27Entries {
                expectedW27[value.relativePath] = (value.sha256, value.byteLength, value.role.rawValue, value.runID)
            }
        }
        guard w27Manifest.entries.count == expectedW27.count else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.reopenedAssemblyInvalid
        }
        for entry in w27Manifest.entries {
            guard let expected = expectedW27[entry.relativePath],
                  expected.0 == entry.sha256,
                  expected.1 == entry.byteLength,
                  expected.2 == entry.role.rawValue,
                  expected.3 == entry.runID else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.reopenedAssemblyInvalid
            }
        }

        var expectedW38: [String: (String, UInt64, String, String)] = [:]
        for bundle in bundles {
            for value in bundle.w38Entries {
                expectedW38[value.relativePath] = (value.sha256, value.byteLength, value.role.rawValue, value.runID)
            }
        }
        guard w38Manifest.entries.count == expectedW38.count else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.reopenedAssemblyInvalid
        }
        for entry in w38Manifest.entries {
            guard let expected = expectedW38[entry.relativePath],
                  expected.0 == entry.sha256,
                  expected.1 == entry.byteLength,
                  expected.2 == entry.role.rawValue,
                  expected.3 == entry.runID else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.reopenedAssemblyInvalid
            }
        }
    }

    static func readStrict(
        _ relativePath: String,
        root: URL,
        fileManager: FileManager
    ) throws -> Data {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(relativePath) else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafeOrMissingFile(relativePath)
        }
        let standardizedRoot = root.standardizedFileURL
        let url = standardizedRoot.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let rootPath = standardizedRoot.path.hasSuffix("/") ? standardizedRoot.path : standardizedRoot.path + "/"
        guard url.path.hasPrefix(rootPath) else {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafeOrMissingFile(relativePath)
        }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafeOrMissingFile(relativePath)
            }
            let resolvedRoot = standardizedRoot.resolvingSymlinksInPath().path
            let resolved = url.resolvingSymlinksInPath().path
            let resolvedPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
            guard resolved.hasPrefix(resolvedPrefix) else {
                throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafeOrMissingFile(relativePath)
            }
            return try Data(contentsOf: url)
        } catch let error as AnalysisPhysicalEvidencePublishedBatchReopenError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidencePublishedBatchReopenError.unsafeOrMissingFile(relativePath)
        }
    }
}
