import Foundation

@main
struct L2AW28BoundedOrphanSweepSelfCheck {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "L2AW28-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fm.removeItem(at: root) }
        let lifecycle = LibraryArtifactLifecycle(rootURL: root)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)
        let young = now.addingTimeInterval(-60)
        try fm.createDirectory(at: root.appendingPathComponent("Imports"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Stems"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Exports"), withIntermediateDirectories: true)

        func write(_ relative: String, date: Date) throws {
            let url = root.appendingPathComponent(relative)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: url)
            try fm.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }

        try write("Imports/a.m4a", date: old)
        try write("Imports/b.m4a", date: old)
        try write("Stems/c.m4a", date: old)
        try write("Stems/d.m4a", date: old)
        try write("Exports/e.m4a", date: old)
        try write("Exports/young.m4a", date: young)
        let outside = root.appendingPathComponent("outside.txt")
        try Data("outside".utf8).write(to: outside)
        try fm.createSymbolicLink(
            at: root.appendingPathComponent("Imports/link.m4a"),
            withDestinationURL: outside
        )

        var scenarios = 0
        let first = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 2
        )
        precondition(first.candidates.map(\.relativePath) == ["Exports/e.m4a", "Imports/a.m4a"])
        let firstResult = try lifecycle.applyBoundedOrphanCandidateSlice(
            first,
            referencedRelativePaths: ["Exports/e.m4a", "Imports/a.m4a"],
            gracePeriod: 3600,
            now: now
        )
        precondition(firstResult.removed.isEmpty)
        precondition(firstResult.retainedReferenced == 2)
        precondition(firstResult.retainedYoung == 1)
        try lifecycle.persistBoundedOrphanSweepCursor(after: first)
        scenarios += 1

        let second = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 2
        )
        precondition(second.candidates.map(\.relativePath) == ["Imports/b.m4a", "Stems/c.m4a"])
        let secondResult = try lifecycle.applyBoundedOrphanCandidateSlice(
            second,
            referencedRelativePaths: [],
            gracePeriod: 3600,
            now: now
        )
        precondition(secondResult.removed == ["Imports/b.m4a", "Stems/c.m4a"])
        try lifecycle.persistBoundedOrphanSweepCursor(after: second)
        scenarios += 1

        let third = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 2
        )
        precondition(third.candidates.map(\.relativePath) == ["Stems/d.m4a"])
        try fm.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: root.appendingPathComponent("Stems/d.m4a").path
        )
        let thirdResult = try lifecycle.applyBoundedOrphanCandidateSlice(
            third,
            referencedRelativePaths: [],
            gracePeriod: 3600,
            now: now
        )
        precondition(thirdResult.removed.isEmpty)
        precondition(thirdResult.retainedYoung >= 2)
        try lifecycle.persistBoundedOrphanSweepCursor(after: third)
        scenarios += 1

        let wrapped = try lifecycle.prepareBoundedOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            limit: 2
        )
        precondition(wrapped.wrappedToStart)
        precondition(wrapped.candidates.map(\.relativePath) == ["Exports/e.m4a", "Imports/a.m4a"])
        precondition(fm.fileExists(atPath: outside.path))
        scenarios += 1

        print(
            "L2_AW28_SELF_TEST_PASS scenarios=\(scenarios) limit=2 scanned=\(first.scannedRegularFiles) first_referenced=\(firstResult.retainedReferenced) second_removed=\(secondResult.removed.count) wrapped=\(wrapped.wrappedToStart)"
        )
    }
}
