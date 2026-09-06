import Foundation

@main
struct L2AW29ManagedArtifactInventorySelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "L2AW29-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)

        func write(_ relativePath: String) throws {
            let url = root.appendingPathComponent(relativePath)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("artifact".utf8).write(to: url)
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        }

        let first = "Imports/000-first.m4a"
        try write(first)
        try lifecycle.requireReady(relativePath: first)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        precondition(inventory.isAuthoritative)

        var paths = [first]
        for index in 1..<512 {
            let rootName = index.isMultiple(of: 3) ? "Stems" : (index.isMultiple(of: 5) ? "Exports" : "Imports")
            let path = "\(rootName)/artifact-\(String(format: "%04d", index)).m4a"
            try write(path)
            try lifecycle.requireReady(relativePath: path)
            paths.append(path)
        }

        let referenced = Set(paths.enumerated().compactMap { offset, path in
            offset.isMultiple(of: 16) ? path : nil
        })
        let expectedRemoved = paths.count - referenced.count
        var removed = Set<String>()
        var passes = 0
        var maxVisitedShards = 0
        var maxCandidateCount = 0

        while removed.count < expectedRemoved && passes < 4096 {
            let slice = try inventory.prepareOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                candidateLimit: 16,
                shardVisitLimit: 4
            )
            precondition(slice.visitedShards <= 4)
            precondition(slice.candidates.count <= 16)
            maxVisitedShards = max(maxVisitedShards, slice.visitedShards)
            maxCandidateCount = max(maxCandidateCount, slice.candidates.count)
            let result = try inventory.applyOrphanCandidateSlice(
                slice,
                referencedRelativePaths: referenced,
                gracePeriod: 3600,
                now: now
            )
            removed.formUnion(result.removed)
            try inventory.persistTraversal(after: slice)
            passes += 1
        }

        precondition(removed.count == expectedRemoved)
        precondition(referenced.allSatisfy { fm.fileExists(atPath: root.appendingPathComponent($0).path) })
        precondition(paths.filter { !referenced.contains($0) }.allSatisfy {
            !fm.fileExists(atPath: root.appendingPathComponent($0).path)
        })

        let upgradeRoot = fm.temporaryDirectory.appendingPathComponent(
            "L2AW29Upgrade-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fm.removeItem(at: upgradeRoot) }
        try fm.createDirectory(at: upgradeRoot, withIntermediateDirectories: true)
        let a = upgradeRoot.appendingPathComponent("Imports/a.m4a")
        let b = upgradeRoot.appendingPathComponent("Stems/b.m4a")
        try fm.createDirectory(at: a.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: b.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let upgradeInventory = Lane2ManagedArtifactInventory(rootURL: upgradeRoot)
        let upgradeActivated = try upgradeInventory.activateForFirstManagedArtifactIfSafe(
            relativePath: "Imports/a.m4a"
        )
        precondition(!upgradeActivated)
        precondition(!upgradeInventory.isAuthoritative)

        print(
            "L2_AW29_SELF_TEST_PASS files=512 referenced=\(referenced.count) removed=\(removed.count) passes=\(passes) shard_count=\(Lane2ManagedArtifactInventory.shardCount) max_shards_per_pass=\(maxVisitedShards) max_candidates_per_pass=\(maxCandidateCount) upgrade_fail_closed=true"
        )
    }
}
