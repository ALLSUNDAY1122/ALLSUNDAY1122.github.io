import Foundation

@main
struct L2AW07ExportBatchSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("l2-aw07-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: base) }
        try fm.createDirectory(at: base, withIntermediateDirectories: true)

        let store = IOFileStore(rootURL: base.appendingPathComponent("sandbox", isDirectory: true))
        try store.prepareDirectories(fileManager: fm)
        let transaction = IOExportBatchTransaction(fileStore: store)

        // 1) clean naming + duplicate disambiguation + atomic publication.
        let plan = try transaction.prepare(
            suggestedFilenameStems: ["Vocals", "vocals", "Drums / FX"],
            fileExtension: ".M4A",
            fileManager: fm
        )
        precondition(plan.items.map(\.filename) == ["Vocals.m4a", "vocals (2).m4a", "Drums _ FX.m4a"])
        for (index, item) in plan.items.enumerated() {
            try Data(repeating: UInt8(index + 1), count: 128).write(to: item.stagingURL)
        }
        let finalized = try transaction.commit(plan, fileManager: fm)
        precondition(finalized.count == 3)
        precondition(finalized.allSatisfy { $0.relativePath.hasPrefix("Exports/Batches/") })
        precondition(finalized.map { $0.url.lastPathComponent } == plan.items.map(\.filename))
        precondition(finalized.allSatisfy { !$0.url.lastPathComponent.contains(plan.id) })
        precondition(!fm.fileExists(atPath: plan.stagingDirectoryURL.path))

        // 2) incomplete batch fails closed and is removable without any publication.
        let incomplete = try transaction.prepare(
            suggestedFilenameStems: ["Bass", "Other"],
            fileExtension: "m4a",
            fileManager: fm
        )
        try Data([1, 2, 3]).write(to: incomplete.items[0].stagingURL)
        do {
            _ = try transaction.commit(incomplete, fileManager: fm)
            preconditionFailure("incomplete batch unexpectedly committed")
        } catch IOExportBatchTransaction.BatchError.outputMissing {
            // expected
        }
        let incompleteFinal = transaction.finalizedBatchesURL.appendingPathComponent(incomplete.id, isDirectory: true)
        precondition(!fm.fileExists(atPath: incompleteFinal.path))
        transaction.abort(incomplete, fileManager: fm)
        precondition(!fm.fileExists(atPath: incomplete.stagingDirectoryURL.path))

        // 3) zero-byte output is rejected.
        let empty = try transaction.prepare(
            suggestedFilenameStems: ["Empty"],
            fileExtension: "m4a",
            fileManager: fm
        )
        _ = fm.createFile(atPath: empty.items[0].stagingURL.path, contents: Data())
        do {
            _ = try transaction.commit(empty, fileManager: fm)
            preconditionFailure("zero-byte output unexpectedly committed")
        } catch IOExportBatchTransaction.BatchError.outputEmpty {
            // expected
        }
        transaction.abort(empty, fileManager: fm)

        // 4) abandoned staging batches are recovered while committed batches survive.
        let abandoned1 = try transaction.prepare(suggestedFilenameStems: ["A"], fileExtension: "m4a", fileManager: fm)
        let abandoned2 = try transaction.prepare(suggestedFilenameStems: ["B"], fileExtension: "m4a", fileManager: fm)
        try Data([7]).write(to: abandoned1.items[0].stagingURL)
        try Data([8]).write(to: abandoned2.items[0].stagingURL)
        let removed = try transaction.recoverAbandonedBatches(fileManager: fm)
        precondition(removed == 2)
        precondition(fm.fileExists(atPath: finalized[0].url.path))

        // 5) basic transaction overhead benchmark: 200 2-stem batches.
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for index in 0..<200 {
                let batch = try transaction.prepare(
                    suggestedFilenameStems: ["Vocals \(index)", "Drums \(index)"],
                    fileExtension: "m4a",
                    fileManager: fm
                )
                for item in batch.items { try Data([1, 2, 3, 4]).write(to: item.stagingURL) }
                _ = try transaction.commit(batch, fileManager: fm)
            }
        }

        print("L2-AW07 SELF-CHECK PASS")
        print("functional_cases=4")
        print("benchmark_batches=200 stems_per_batch=2 elapsed=\(elapsed)")
    }
}
