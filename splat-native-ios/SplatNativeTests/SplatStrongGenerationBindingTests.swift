import XCTest

final class SplatStrongGenerationBindingTests: XCTestCase {
    func testStrongSealRejectsMultiplyLinkedSourceGeneration() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("c2-strong-generation-link-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let alias = root.appendingPathComponent("same-inode.splat")
        try Data(repeating: 0x5a, count: 64).write(to: source, options: .atomic)
        try fileManager.linkItem(at: source, to: alias)

        let evidence = SplatCommitEvidence(
            fileName: ScanProjectStore.splatResultFileName,
            byteCount: 64,
            completedAt: Date().addingTimeInterval(1)
        )
        XCTAssertThrowsError(
            try SplatStrongCompletionEvidence.verifyOrSeal(
                sourceURL: source,
                evidence: evidence,
                fileManager: fileManager
            )
        )
        XCTAssertFalse(fileManager.fileExists(
            atPath: root.appendingPathComponent(SplatStrongCompletionEvidence.fileName).path
        ))
    }
}
