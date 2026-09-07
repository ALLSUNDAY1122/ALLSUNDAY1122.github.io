import Foundation

@main
struct L2AW50AncestorAuthoritySelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW50-ANCESTOR-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let boundary = LibraryManagedPathBoundary(rootURL: root)
        var checks = 0

        let safeParent = root.appendingPathComponent("safe", isDirectory: true)
        try fm.createDirectory(at: safeParent, withIntermediateDirectories: true)
        let missing = safeParent.appendingPathComponent("missing.json")
        let safeMissing = try boundary.nodeExists(missing, fileManager: fm)
        precondition(safeMissing == false)
        checks += 1

        let linkedParent = root.appendingPathComponent("linked", isDirectory: true)
        try fm.createSymbolicLink(at: linkedParent, withDestinationURL: external)
        let missingThroughLink = linkedParent.appendingPathComponent("missing.json")
        do {
            _ = try boundary.nodeExists(missingThroughLink, fileManager: fm)
            fatalError("missing leaf through symlink ancestor was accepted")
        } catch {
            checks += 1
        }

        let start = Date()
        for index in 0..<10_000 {
            let candidate = safeParent.appendingPathComponent("probe-\(index).json")
            let exists = try boundary.nodeExists(candidate, fileManager: fm)
            precondition(exists == false)
        }
        let elapsedMS = Date().timeIntervalSince(start) * 1_000

        print(
            String(
                format: "L2_AW50_ANCESTOR_SELF_TEST_PASS checks=%d safe_missing=true symlink_ancestor=true node_probe_10000_ms=%.3f",
                checks,
                elapsedMS
            )
        )
    }
}
