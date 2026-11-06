import Foundation

@main
struct L2AW17ExportPublicationGuardSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("l2-aw17-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories(fileManager: fm)
        let tx = IOExportBatchTransaction(fileStore: store)
        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        var scenarios = 0

        func makePublished(_ stem: String) throws -> (IOExportBatchTransaction.Plan, [IOFileStore.FinalizedFile]) {
            let plan = try tx.prepare(suggestedFilenameStems: [stem], fileExtension: "m4a", fileManager: fm)
            try Data(repeating: 0x41, count: 1024).write(to: plan.items[0].stagingURL)
            let finalized = try tx.commit(plan, fileManager: fm)
            return (plan, finalized)
        }

        do {
            let (plan, finalized) = try makePublished("guarded")
            let marker = tx.finalizedBatchesURL.appendingPathComponent(plan.id).appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            guard fm.fileExists(atPath: marker.path) else { fatalError("marker missing after publish") }
            let session = String(decoding: try Data(contentsOf: marker), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard session == IOExportBatchTransaction.publicationSessionID else { fatalError("marker session mismatch") }
            guard fm.fileExists(atPath: finalized[0].url.path) else { fatalError("audio missing") }
            try fm.removeItem(at: tx.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true))
            scenarios += 1
        }

        do {
            let (plan, finalized) = try makePublished("adopt")
            let marker = tx.finalizedBatchesURL.appendingPathComponent(plan.id).appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: [Lane2ExportRegistrationArtifact(relativePath: finalized[0].relativePath, mediaType: "audio/mp4")])
            guard journal.exists(intentID: intent.id) else { fatalError("intent missing") }
            guard !fm.fileExists(atPath: marker.path) else { fatalError("marker not cleared after journal durable") }
            try journal.complete(intentID: intent.id)
            scenarios += 1
        }

        do {
            let (plan, _) = try makePublished("current")
            let report = try journal.recoverPrejournalPublishedBatches()
            guard report.retainedCurrentSessionBatchIDs == [plan.id], report.quarantinedBatchIDs.isEmpty else { fatalError("current process marker should be retained") }
            scenarios += 1
        }

        do {
            let (plan, finalized) = try makePublished("previous")
            let batch = tx.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            let marker = batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            try Data("previous-process-session\n".utf8).write(to: marker, options: [.atomic])
            let report = try journal.recoverPrejournalPublishedBatches()
            guard report.quarantinedBatchIDs == [plan.id] else { fatalError("old marker not quarantined") }
            guard !fm.fileExists(atPath: finalized[0].url.path) else { fatalError("old untracked export still published") }
            let preserved = root.appendingPathComponent(".LibraryRecovery/PrejournalExport/" + plan.id + "/" + plan.items[0].filename)
            guard fm.fileExists(atPath: preserved.path) else { fatalError("quarantined bytes not preserved") }
            scenarios += 1
        }

        do {
            let (plan, finalized) = try makePublished("pending-recovery")
            let batch = tx.finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
            try Data("old-session\n".utf8).write(to: batch.appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename), options: [.atomic])
            guard try journal.pending().isEmpty else { fatalError("unexpected intent") }
            guard !fm.fileExists(atPath: finalized[0].url.path) else { fatalError("pending did not quarantine old marker") }
            scenarios += 1
        }

        do {
            let plan = try tx.prepare(suggestedFilenameStems: ["vocals", "drums"], fileExtension: "m4a", fileManager: fm)
            for item in plan.items { try Data(repeating: 0x55, count: 2048).write(to: item.stagingURL) }
            let finalized = try tx.commit(plan, fileManager: fm)
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: finalized.map { Lane2ExportRegistrationArtifact(relativePath: $0.relativePath, mediaType: "audio/mp4") })
            guard finalized.allSatisfy({ fm.fileExists(atPath: $0.url.path) }) else { fatalError("journal adoption touched audio") }
            try journal.complete(intentID: intent.id)
            scenarios += 1
        }

        do {
            var rejected = false
            do {
                _ = try journal.prepare(projectUUID: UUID(), artifacts: [Lane2ExportRegistrationArtifact(relativePath: "Imports/not-export.m4a", mediaType: "audio/mp4")])
            } catch Lane2ExportRegistrationJournalFailure.nonExportPath {
                rejected = true
            }
            guard rejected else { fatalError("non-export path accepted") }
            scenarios += 1
        }

        let clock = ContinuousClock(); let start = clock.now
        for i in 0..<200 {
            let (plan, finalized) = try makePublished("bench-\(i)")
            let intent = try journal.prepare(projectUUID: UUID(), artifacts: [Lane2ExportRegistrationArtifact(relativePath: finalized[0].relativePath, mediaType: "audio/mp4")])
            let marker = tx.finalizedBatchesURL.appendingPathComponent(plan.id).appendingPathComponent(IOExportBatchTransaction.preRegistrationMarkerFilename)
            guard !fm.fileExists(atPath: marker.path) else { fatalError("benchmark marker remained") }
            try journal.complete(intentID: intent.id)
        }
        let elapsed = start.duration(to: clock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        scenarios += 1
        print(String(format: "L2_AW17_SELF_TEST_PASS scenarios=%d batches=200 elapsed_seconds=%.6f", scenarios, seconds))
    }
}
