import Foundation
import XCTest

final class SplatStrongCompletionEvidenceFileTypeTests: XCTestCase {
    func testRejectsSymlinkResultEvenWhenTargetBytesMatchCommitEvidence() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("strong-evidence-file-type-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let external = root.appendingPathComponent("external.bin")
        let bytes = Data(repeating: 0x5A, count: 64)
        try bytes.write(to: external, options: .atomic)

        let project = root.appendingPathComponent("project.scanproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let result = project.appendingPathComponent(ScanProjectStore.splatResultFileName)
        try FileManager.default.createSymbolicLink(at: result, withDestinationURL: external)

        let evidence = SplatCommitEvidence(
            fileName: ScanProjectStore.splatResultFileName,
            byteCount: Int64(bytes.count),
            completedAt: Date().addingTimeInterval(60)
        )

        XCTAssertThrowsError(
            try SplatStrongCompletionEvidence.verifyOrSeal(sourceURL: result, evidence: evidence)
        ) { error in
            guard case SplatStrongCompletionEvidence.IntegrityError.sourceMissing = error else {
                return XCTFail("Expected sourceMissing for non-regular result, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: project.appendingPathComponent(SplatStrongCompletionEvidence.fileName).path
        ))
    }
}
