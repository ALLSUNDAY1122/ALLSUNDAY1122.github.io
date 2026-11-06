import Foundation

/// AW36 revalidation seam used after durable registration intent creation.
///
/// AW35 validates canonical export batches before the registration intent is persisted. This helper
/// deliberately repeats that verification at later commit/recovery boundaries so content drift
/// cannot silently convert a previously verified batch into registered Library metadata.
public extension Lane2ExportRegistrationJournal {
    func revalidatePublishedBatchIntegrityIfPresent(
        intent: Lane2ExportRegistrationIntent
    ) throws {
        try revalidatePublishedBatchIntegrityIfPresent(artifacts: intent.artifacts)
    }

    func revalidatePublishedBatchIntegrityIfPresent(
        artifacts: [Lane2ExportRegistrationArtifact]
    ) throws {
        guard !artifacts.isEmpty else {
            throw Lane2ExportRegistrationJournalFailure.emptyArtifacts
        }

        let grouped = Dictionary(grouping: artifacts.compactMap { artifact -> (String, Lane2ExportRegistrationArtifact)? in
            let parts = artifact.relativePath.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 4,
                  parts[0] == "Exports",
                  parts[1] == "Batches",
                  !parts[2].isEmpty,
                  !parts[3].isEmpty else {
                return nil
            }
            return (String(parts[2]), artifact)
        }, by: { $0.0 })

        let finalizedBatchesURL = rootURL
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent("Batches", isDirectory: true)
        let transaction = IOExportBatchTransaction(fileStore: IOFileStore(rootURL: rootURL))

        for (batchID, members) in grouped {
            let directory = finalizedBatchesURL.appendingPathComponent(batchID, isDirectory: true)
            let manifest = directory.appendingPathComponent(IOExportBatchTransaction.integrityManifestFilename)
            guard FileManager.default.fileExists(atPath: manifest.path) else {
                // Compatibility: batches produced before AW35 never had a manifest.
                continue
            }

            do {
                let verified = try transaction.verifyPublishedBatch(batchID: batchID)
                let verifiedPaths = Set(verified.map(\.relativePath))
                let intendedPaths = Set(members.map { $0.1.relativePath })
                guard verifiedPaths == intendedPaths else {
                    throw Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed(batchID)
                }
            } catch let failure as Lane2ExportRegistrationJournalFailure {
                throw failure
            } catch {
                throw Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed(batchID)
            }
        }
    }
}
