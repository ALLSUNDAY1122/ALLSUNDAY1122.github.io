import Foundation

@main
struct L2AW09ExportCompensationSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("L2-AW09-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)

        func write(_ relative: String, _ bytes: Int = 16) throws {
            let url = try lifecycle.absoluteURL(for: relative)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 7, count: bytes).write(to: url)
        }
        func exists(_ relative: String) throws -> Bool {
            fm.fileExists(atPath: try lifecycle.absoluteURL(for: relative).path)
        }
        func expect(_ condition: Bool, _ message: String) throws {
            if !condition {
                throw NSError(domain: "L2-AW09", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        let batch = UUID().uuidString
        let vocals = "Exports/Batches/\(batch)/Vocals.m4a"
        let drums = "Exports/Batches/\(batch)/Drums.m4a"
        try write(vocals)
        try write(drums)
        let removed = try lifecycle.discardUncommittedExportArtifacts(
            relativePaths: [vocals, drums],
            fileManager: fm
        )
        try expect(removed.removed.count == 2 && removed.failed.isEmpty, "batch compensation")
        try expect(try !exists(vocals) && !exists(drums), "artifacts removed")
        try expect(
            !fm.fileExists(atPath: root.appendingPathComponent("Exports/Batches/\(batch)").path),
            "empty batch directory pruned"
        )

        let missing = try lifecycle.discardUncommittedExportArtifacts(relativePaths: [vocals], fileManager: fm)
        try expect(missing.alreadyMissing == [vocals] && missing.isComplete, "missing idempotency")

        let safe = "Exports/Batches/\(UUID().uuidString)/Mix.m4a"
        let importPath = "Imports/source.m4a"
        try write(safe)
        try write(importPath)
        do {
            _ = try lifecycle.discardUncommittedExportArtifacts(
                relativePaths: [safe, importPath],
                fileManager: fm
            )
            throw NSError(domain: "L2-AW09", code: 2)
        } catch LibraryUncommittedExportRecoveryFailure.unsafeLocation {}
        try expect(try exists(safe) && exists(importPath), "set prevalidation")

        do {
            _ = try lifecycle.discardUncommittedExportArtifacts(
                relativePaths: ["Exports/../Imports/source.m4a"],
                fileManager: fm
            )
            throw NSError(domain: "L2-AW09", code: 3)
        } catch LibraryArtifactFailure.invalidRelativePath {}
        try expect(try exists(importPath), "traversal preserved source")

        let directoryRelative = "Exports/Batches/\(UUID().uuidString)"
        let directoryURL = try lifecycle.absoluteURL(for: directoryRelative)
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try write(directoryRelative + "/keep.m4a")
        do {
            _ = try lifecycle.discardUncommittedExportArtifacts(
                relativePaths: [directoryRelative],
                fileManager: fm
            )
            throw NSError(domain: "L2-AW09", code: 4)
        } catch LibraryUncommittedExportRecoveryFailure.directoryCandidate {}
        try expect(try exists(directoryRelative + "/keep.m4a"), "directory preserved")

        let duplicate = "Exports/Batches/\(UUID().uuidString)/Bass.m4a"
        try write(duplicate)
        let deduplicated = try lifecycle.discardUncommittedExportArtifacts(
            relativePaths: [duplicate, duplicate],
            fileManager: fm
        )
        try expect(deduplicated.removed == [duplicate], "duplicate paths deduplicated")

        let benchmarkStart = Date()
        var benchmarkPaths: [String] = []
        for index in 0..<500 {
            let path = "Exports/Batches/bench-\(index)/Mix.m4a"
            try write(path, 64)
            benchmarkPaths.append(path)
        }
        let benchmark = try lifecycle.discardUncommittedExportArtifacts(
            relativePaths: benchmarkPaths,
            fileManager: fm
        )
        try expect(benchmark.removed.count == 500 && benchmark.failed.isEmpty, "benchmark cleanup")
        let elapsed = Date().timeIntervalSince(benchmarkStart)

        print(
            "L2_AW09_SELF_TEST_PASS scenarios=6 benchmark_files=500 elapsed_seconds=\(String(format: \"%.6f\", elapsed))"
        )
    }
}
