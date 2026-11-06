import Foundation

@main
struct L2AW10ExportRegistrationSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2AW10-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let journal = Lane2ExportRegistrationJournal(rootURL: root)
        let project = UUID()

        let first = try journal.prepare(projectUUID: project, artifacts: [
            .init(relativePath: "Exports/Batches/a/Vocals.m4a", mediaType: "audio/mp4"),
            .init(relativePath: "Exports/Batches/a/Drums.m4a", mediaType: "audio/mp4")
        ])
        let reopened = Lane2ExportRegistrationJournal(rootURL: root)
        let pending = try reopened.pending()
        try require(pending.count == 1, "reopen count")
        try require(pending[0].id == first.id, "reopen id")
        try require(pending[0].projectUUID == first.projectUUID, "reopen project")
        try require(pending[0].artifacts == first.artifacts, "reopen artifacts")
        try require(Lane2ExportRegistrationJournal.disposition(intent: first, registeredRelativePaths: []) == .unregistered, "unregistered classification")
        try reopened.complete(intentID: first.id)
        let afterComplete = try reopened.pending()
        try require(afterComplete.isEmpty, "complete did not remove intent")

        let second = try reopened.prepare(projectUUID: project, artifacts: [
            .init(relativePath: "Exports/Batches/b/Mix.m4a", mediaType: "audio/mp4")
        ])
        try require(Lane2ExportRegistrationJournal.disposition(
            intent: second,
            registeredRelativePaths: ["Exports/Batches/b/Mix.m4a"]
        ) == .alreadyRegistered, "registered classification")

        let third = try reopened.prepare(projectUUID: project, artifacts: [
            .init(relativePath: "Exports/Batches/c/Vocals.m4a", mediaType: "audio/mp4"),
            .init(relativePath: "Exports/Batches/c/Bass.m4a", mediaType: "audio/mp4")
        ])
        try require(Lane2ExportRegistrationJournal.disposition(
            intent: third,
            registeredRelativePaths: ["Exports/Batches/c/Vocals.m4a"]
        ) == .partial, "partial classification")

        try expectFailure("unsafe path") {
            _ = try reopened.prepare(projectUUID: project, artifacts: [
                .init(relativePath: "Imports/source.m4a", mediaType: "audio/mp4")
            ])
        }
        try expectFailure("duplicate path") {
            _ = try reopened.prepare(projectUUID: project, artifacts: [
                .init(relativePath: "Exports/Batches/d/Mix.m4a", mediaType: "audio/mp4"),
                .init(relativePath: "Exports/Batches/d/Mix.m4a", mediaType: "audio/mp4")
            ])
        }

        let corruptID = UUID()
        let corruptDir = root.appendingPathComponent(".LibraryRecovery/ExportRegistration", isDirectory: true)
        try fm.createDirectory(at: corruptDir, withIntermediateDirectories: true)
        let corruptURL = corruptDir.appendingPathComponent(corruptID.uuidString + ".json")
        try Data("not-json".utf8).write(to: corruptURL)
        try expectFailure("corrupt intent") { _ = try reopened.pending() }
        try require(fm.fileExists(atPath: corruptURL.path), "corrupt intent was destructively removed")
        try fm.removeItem(at: corruptURL)

        let count = 500
        let start = Date()
        var ids: [UUID] = []
        ids.reserveCapacity(count)
        for index in 0..<count {
            let intent = try reopened.prepare(projectUUID: project, artifacts: [
                .init(relativePath: "Exports/Batches/bench-\(index)/Mix.m4a", mediaType: "audio/mp4")
            ])
            ids.append(intent.id)
        }
        let listed = try reopened.pending()
        try require(listed.count >= count, "benchmark pending count")
        for id in ids { try reopened.complete(intentID: id) }
        let elapsed = Date().timeIntervalSince(start)

        print("L2_AW10_SELF_TEST_PASS scenarios=6")
        print("benchmark_intents=\(count) elapsed=\(String(format: "%.6f", elapsed))s")
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "L2AW10", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    static func expectFailure(_ message: String, _ body: () throws -> Void) throws {
        do {
            try body()
            throw NSError(domain: "L2AW10", code: 2, userInfo: [NSLocalizedDescriptionKey: "expected failure: \(message)"])
        } catch let error as NSError where error.domain == "L2AW10" && error.code == 2 {
            throw error
        } catch {
            return
        }
    }
}
