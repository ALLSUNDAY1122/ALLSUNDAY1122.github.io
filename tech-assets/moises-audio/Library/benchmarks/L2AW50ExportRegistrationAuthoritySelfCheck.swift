import Foundation

@main
struct L2AW50ExportRegistrationAuthoritySelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW50-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        var checks = 0
        let journal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)

        let legacyBatch = root.appendingPathComponent("Exports/Batches/legacy", isDirectory: true)
        try fm.createDirectory(at: legacyBatch, withIntermediateDirectories: true)
        let legacyIntent = try journal.prepare(
            projectUUID: UUID(),
            artifacts: [.init(relativePath: "Exports/Batches/legacy/Mix.m4a", mediaType: "audio/mp4")]
        )
        precondition(journal.exists(intentID: legacyIntent.id))
        try journal.complete(intentID: legacyIntent.id)
        checks += 1

        let danglingBatch = root.appendingPathComponent("Exports/Batches/dangling", isDirectory: true)
        try fm.createDirectory(at: danglingBatch, withIntermediateDirectories: true)
        let danglingManifest = danglingBatch.appendingPathComponent(
            IOExportBatchTransaction.integrityManifestFilename
        )
        try fm.createSymbolicLink(
            at: danglingManifest,
            withDestinationURL: external.appendingPathComponent("missing-manifest.json")
        )
        do {
            _ = try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/Batches/dangling/Vocals.m4a", mediaType: "audio/mp4")]
            )
            fatalError("dangling manifest accepted as legacy absence")
        } catch Lane2ExportRegistrationJournalFailure.publicationIntegrityFailed {
            checks += 1
        }

        let recoveryRoot = root.appendingPathComponent(".LibraryRecovery", isDirectory: true)
        try? fm.removeItem(at: recoveryRoot)
        try fm.createDirectory(at: recoveryRoot, withIntermediateDirectories: true)
        let registration = recoveryRoot.appendingPathComponent("ExportRegistration", isDirectory: true)
        try fm.createSymbolicLink(at: registration, withDestinationURL: external)
        do {
            _ = try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/plain.m4a", mediaType: "audio/mp4")]
            )
            fatalError("registration root symlink accepted")
        } catch Lane2ExportRegistrationJournalFailure.corruptIntent {
            checks += 1
        }
        try fm.removeItem(at: registration)

        try fm.createDirectory(at: registration, withIntermediateDirectories: true)
        let fixedID = UUID()
        let externalIntent = external.appendingPathComponent("outside.json")
        try Data("sentinel".utf8).write(to: externalIntent)
        let symlinkIntent = registration.appendingPathComponent(fixedID.uuidString + ".json")
        try fm.createSymbolicLink(at: symlinkIntent, withDestinationURL: externalIntent)
        do {
            _ = try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/plain2.m4a", mediaType: "audio/mp4")],
                id: fixedID
            )
            fatalError("intent symlink overwritten")
        } catch Lane2ExportRegistrationJournalFailure.corruptIntent {
            let bytes = try Data(contentsOf: externalIntent)
            precondition(bytes == Data("sentinel".utf8))
            checks += 1
        }
        try fm.removeItem(at: symlinkIntent)

        let markerBatch = root.appendingPathComponent("Exports/Batches/marker", isDirectory: true)
        try fm.createDirectory(at: markerBatch, withIntermediateDirectories: true)
        let externalMarker = external.appendingPathComponent("marker.txt")
        try Data("outside".utf8).write(to: externalMarker)
        let marker = markerBatch.appendingPathComponent(
            IOExportBatchTransaction.preRegistrationMarkerFilename
        )
        try fm.createSymbolicLink(at: marker, withDestinationURL: externalMarker)
        let markerIntentID = UUID()
        do {
            _ = try journal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/Batches/marker/Mix.m4a", mediaType: "audio/mp4")],
                id: markerIntentID
            )
            fatalError("marker symlink accepted")
        } catch Lane2ExportRegistrationJournalFailure.publicationMarkerClearFailed {
            precondition(journal.exists(intentID: markerIntentID))
            let bytes = try Data(contentsOf: externalMarker)
            precondition(bytes == Data("outside".utf8))
            checks += 1
        }

        try? fm.removeItem(at: root.appendingPathComponent("Exports", isDirectory: true))
        let exports = root.appendingPathComponent("Exports", isDirectory: true)
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        let batchesLink = exports.appendingPathComponent("Batches", isDirectory: true)
        try fm.createSymbolicLink(at: batchesLink, withDestinationURL: external)
        do {
            _ = try journal.recoverPrejournalPublishedBatches()
            fatalError("batch root symlink accepted")
        } catch Lane2ExportRegistrationJournalFailure.publicationMarkerRecoveryFailed {
            checks += 1
        }

        try fm.removeItem(at: batchesLink)
        let benchJournal = Lane2ExportRegistrationJournal(rootURL: root, fileManager: fm)
        let rounds = 1_000
        let start = Date()
        for index in 0..<rounds {
            let intent = try benchJournal.prepare(
                projectUUID: UUID(),
                artifacts: [.init(relativePath: "Exports/bench-\(index).m4a", mediaType: "audio/mp4")]
            )
            guard benchJournal.exists(intentID: intent.id) else { fatalError("missing intent") }
            try benchJournal.complete(intentID: intent.id)
        }
        let ms = Date().timeIntervalSince(start) * 1_000

        print(
            String(
                format: "L2_AW50_SELF_TEST_PASS checks=%d legacy_absent=true dangling_manifest=true registration_symlink=true intent_symlink=true marker_symlink=true batch_root_symlink=true prepare_exists_complete_1000_ms=%.3f per_cycle_us=%.3f",
                checks,
                ms,
                ms * 1000 / Double(rounds)
            )
        )
    }
}
