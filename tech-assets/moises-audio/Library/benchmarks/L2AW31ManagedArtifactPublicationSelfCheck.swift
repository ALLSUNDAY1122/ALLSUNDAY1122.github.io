import Foundation

@main
struct L2AW31ManagedArtifactPublicationSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2AW31-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let old = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "old")
        let current = Lane2ManagedArtifactPublicationJournal(rootURL: root, sessionID: "new")
        var published = Set<String>()
        var missing = Set<String>()
        for i in 0..<256 {
            let path = "Imports/item-\(String(format: "%04d", i)).m4a"
            _ = try old.begin(relativePath: path)
            if i.isMultiple(of: 2) {
                let url = root.appendingPathComponent(path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data("audio".utf8).write(to: url)
                published.insert(path)
            } else {
                missing.insert(path)
            }
        }
        var currentPaths = Set<String>()
        for i in 0..<16 {
            let path = "Exports/current-\(String(format: "%02d", i)).m4a"
            _ = try current.begin(relativePath: path)
            currentPaths.insert(path)
        }

        let recovery = Lane2ManagedArtifactPublicationRecovery(rootURL: root, sessionID: "new")
        var recovered = Set<String>()
        var discarded = Set<String>()
        var passes = 0
        var maxCandidates = 0
        var maxVisitedRecords = 0
        var maxVisitedShards = 0
        while recovered.count + discarded.count < 256 && passes < 1024 {
            let report = try recovery.recoverPreviousSessionPublications(candidateLimit: 8, recordVisitLimit: 16, shardVisitLimit: 4)
            recovered.formUnion(report.recoveredPublished)
            discarded.formUnion(report.discardedMissing)
            maxCandidates = max(maxCandidates, report.recoveredPublished.count + report.discardedMissing.count + report.retainedUnsafe.count)
            maxVisitedRecords = max(maxVisitedRecords, report.visitedRecords)
            maxVisitedShards = max(maxVisitedShards, report.visitedShards)
            passes += 1
        }
        precondition(recovered == published)
        precondition(discarded == missing)
        precondition(maxCandidates <= 8)
        precondition(maxVisitedRecords <= 16)
        precondition(maxVisitedShards <= 4)
        precondition(currentPaths.allSatisfy { (try? current.contains(relativePath: $0)) == true })

        let conflictPath = "Stems/conflict.m4a"
        _ = try old.begin(relativePath: conflictPath)
        do {
            _ = try current.begin(relativePath: conflictPath)
            preconditionFailure("prior-session publication must conflict")
        } catch Lane2ManagedArtifactPublicationJournalFailure.priorSessionIntentExists(let path) {
            precondition(path == conflictPath)
        }

        let unsafeRoot = fm.temporaryDirectory.appendingPathComponent("L2AW31Unsafe-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: unsafeRoot) }
        try fm.createDirectory(at: unsafeRoot, withIntermediateDirectories: true)
        let unsafeOld = Lane2ManagedArtifactPublicationJournal(rootURL: unsafeRoot, sessionID: "old")
        let unsafePath = "Imports/link.m4a"
        _ = try unsafeOld.begin(relativePath: unsafePath)
        let outside = unsafeRoot.appendingPathComponent("outside")
        try Data("outside".utf8).write(to: outside)
        let link = unsafeRoot.appendingPathComponent(unsafePath)
        try fm.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: link, withDestinationURL: outside)
        let unsafeReport = try Lane2ManagedArtifactPublicationRecovery(rootURL: unsafeRoot, sessionID: "new")
            .recoverPreviousSessionPublications(candidateLimit: 8, recordVisitLimit: 16, shardVisitLimit: 256)
        precondition(unsafeReport.retainedUnsafe == [unsafePath])
        precondition((try? unsafeOld.contains(relativePath: unsafePath)) == true)
        precondition(fm.fileExists(atPath: outside.path))

        print("L2_AW31_SELF_TEST_PASS prior_intents=256 published=\(recovered.count) missing=\(discarded.count) current_preserved=\(currentPaths.count) passes=\(passes) max_candidates=\(maxCandidates) max_records=\(maxVisitedRecords) max_shards=\(maxVisitedShards) conflict_fail_closed=true symlink_fail_closed=true")
    }
}
