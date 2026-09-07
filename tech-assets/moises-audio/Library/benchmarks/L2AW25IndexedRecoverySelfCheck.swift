import Foundation

@main
struct L2AW25IndexedRecoverySelfCheck {
    static func main() throws {
        var scenarios = 0
        let budget = Lane2IndexedRecoveryBudget(ownershipOnlyPerPass: 64)
        precondition(budget.ownershipOnlyPerPass == 64)
        precondition(budget.passCount(forOwnershipOnlyRecordCount: 100_000) == 1_563)
        scenarios += 1

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("L2AW25SelfCheck-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let index = Lane2DeletionOwnershipIndex(rootURL: root)
        let actualRecords = 2_048
        let startWrite = Date()
        for value in 0..<actualRecords {
            let project = try makeUUID(value)
            try index.persist(
                Lane2DeletionOwnershipRecord(
                    projectUUID: project,
                    sourceAssetUUID: try makeUUID(100_000 + value),
                    artifactRelativePaths: [
                        "Imports/\(value)/source.m4a",
                        "Stems/\(value)/vocals.m4a"
                    ],
                    createdAt: Date(timeIntervalSince1970: 100)
                )
            )
        }
        let writeElapsed = Date().timeIntervalSince(startWrite)
        scenarios += 1

        let journalIDs = Set(try (0..<16).map(makeUUID))
        let first = try index.pendingRecordSlice(limit: 64, excludingProjectUUIDs: journalIDs)
        precondition(first.records.count == 64)
        precondition(first.hasMore)
        precondition(first.records.allSatisfy { !journalIDs.contains($0.projectUUID) })
        scenarios += 1

        let startDrain = Date()
        var drained = 0
        var passes = 0
        while true {
            let slice = try index.pendingRecordSlice(limit: 64, excludingProjectUUIDs: journalIDs)
            for record in slice.records {
                try index.remove(projectUUID: record.projectUUID)
                drained += 1
            }
            passes += 1
            if !slice.hasMore { break }
        }
        precondition(drained == actualRecords - journalIDs.count)
        precondition(passes == 32)
        let drainElapsed = Date().timeIntervalSince(startDrain)
        scenarios += 1

        for id in journalIDs { try index.remove(projectUUID: id) }
        let empty = try index.pendingRecordSlice(limit: 64)
        precondition(empty.records.isEmpty && !empty.hasMore)
        scenarios += 1

        let mismatchFilename = try makeUUID(300_000)
        let mismatchPayload = try Lane2DeletionOwnershipRecord(
            projectUUID: try makeUUID(300_001),
            sourceAssetUUID: try makeUUID(300_002),
            artifactRelativePaths: ["Imports/mismatch/source.m4a"]
        )
        let directory = root
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("DeleteOwnership", isDirectory: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(mismatchPayload).write(
            to: directory.appendingPathComponent(mismatchFilename.uuidString + ".json")
        )
        do {
            _ = try index.pendingRecordSlice(limit: 64)
            fatalError("identity mismatch accepted")
        } catch Lane2DeletionOwnershipIndexFailure.recordIdentityMismatch {
            scenarios += 1
        }

        print(String(
            format: "L2_AW25_SELF_TEST_PASS scenarios=%d records=%d budget=%d passes=%d prioritized_journal_ids=%d write_seconds=%.6f drain_seconds=%.6f",
            scenarios,
            actualRecords,
            budget.ownershipOnlyPerPass,
            passes,
            journalIDs.count,
            writeElapsed,
            drainElapsed
        ))
    }

    private static func makeUUID(_ value: Int) throws -> UUID {
        let suffix = String(format: "%012X", value)
        guard let id = UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") else {
            throw NSError(domain: "aw25", code: 1)
        }
        return id
    }
}
