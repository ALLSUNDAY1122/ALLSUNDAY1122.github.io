import Foundation

@main
struct L2AW49LifecycleBoundarySelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW49-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let boundary = LibraryManagedPathBoundary(rootURL: root)
        let lifecycle = root.appendingPathComponent(".LibraryLifecycle", isDirectory: true)
        try boundary.ensureDirectory(lifecycle, fileManager: fm)

        var checks = 0
        let missing = lifecycle.appendingPathComponent("missing.json")
        let missingExists = try boundary.requireRegularFileOrMissing(
            missing,
            within: lifecycle,
            fileManager: fm
        )
        precondition(missingExists == false)
        checks += 1

        let dangling = lifecycle.appendingPathComponent("dangling.json")
        try fm.createSymbolicLink(
            at: dangling,
            withDestinationURL: external.appendingPathComponent("missing-target.json")
        )
        do {
            _ = try boundary.requireRegularFileOrMissing(
                dangling,
                within: lifecycle,
                fileManager: fm
            )
            fatalError("dangling symlink was accepted")
        } catch {
            checks += 1
        }
        try fm.removeItem(at: dangling)

        let regular = lifecycle.appendingPathComponent("regular.json")
        try Data([1]).write(to: regular)
        try boundary.requireExistingRegularFile(regular, within: lifecycle, fileManager: fm)
        checks += 1

        let quarantine = lifecycle.appendingPathComponent("Quarantine", isDirectory: true)
        try fm.createSymbolicLink(at: quarantine, withDestinationURL: external)
        do {
            try boundary.ensureDirectory(quarantine, fileManager: fm)
            fatalError("directory symlink was accepted")
        } catch {
            checks += 1
        }
        try fm.removeItem(at: quarantine)

        let v2 = lifecycle.appendingPathComponent("v2", isDirectory: true)
        try fm.createSymbolicLink(at: v2, withDestinationURL: external)
        do {
            try boundary.requireDirectory(v2, fileManager: fm)
            fatalError("v2 symlink was accepted")
        } catch {
            checks += 1
        }
        try fm.removeItem(at: v2)

        let safe = lifecycle.appendingPathComponent("safe", isDirectory: true)
        try boundary.ensureDirectory(safe, fileManager: fm)
        let future = safe.appendingPathComponent("future.json")
        try boundary.requireSafeDestination(future, within: safe, fileManager: fm)
        checks += 1

        let start = Date()
        for index in 0..<10_000 {
            let candidate = safe.appendingPathComponent("probe-\(index).json")
            let exists = try boundary.nodeExists(candidate, fileManager: fm)
            precondition(exists == false)
        }
        let elapsedMS = Date().timeIntervalSince(start) * 1_000

        print(
            String(
                format: "L2_AW49_BOUNDARY_SELF_TEST_PASS checks=%d dangling=true directory_symlink=true missing=true regular=true node_probe_10000_ms=%.3f",
                checks,
                elapsedMS
            )
        )
    }
}
