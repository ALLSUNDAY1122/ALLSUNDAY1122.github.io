import Foundation
import XCTest
@testable import PackageValidation

private struct StubPDFInspector: PackagePDFInspecting {
    let count: Int
    func pageCount(at url: URL) throws -> Int { count }
}

final class PackageIntegrityVerifierTests: XCTestCase {
    func testValidSyntheticPackagePasses() throws {
        let root = try makePackage(pages: [page(1, "p1"), page(2, "p2"), page(3, "p3")])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 3)).verify(rootURL: root)
        XCTAssertTrue(report.valid)
        XCTAssertEqual(report.summary.manifestPageCount, 3)
        XCTAssertEqual(report.summary.imageReferenceCount, 3)
        XCTAssertEqual(report.summary.textReferenceCount, 3)
        XCTAssertEqual(report.summary.pdfPageCount, 3)
        XCTAssertEqual(report.summary.errorCount, 0)
    }

    func testDuplicateSequenceAndPageIDFail() throws {
        let root = try makePackage(pages: [page(1, "same"), page(1, "same")])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 2)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateSequence })
        XCTAssertTrue(report.issues.contains { $0.code == .duplicatePageID })
    }

    func testDuplicateImageAndTextReferencesFail() throws {
        let first = page(1, "p1")
        let second = PackageManifestSnapshot.Page(sequence: 2, pageID: "p2", imagePath: first.imagePath, textPath: first.textPath, sourceTimeMS: 2000, needsReview: false)
        let root = try makePackage(pages: [first, second])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 2)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateImagePath })
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateTextPath })
    }

    func testMissingAndBrokenReferencesAreReviewable() throws {
        let root = try makePackage(pages: [page(1, "p1"), page(2, "p2")])
        try FileManager.default.removeItem(at: root.appendingPathComponent("pages/0002.jpg"))
        try Data([0xff, 0xfe]).write(to: root.appendingPathComponent("text/0001.txt"))
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 2)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .missingImageFile && $0.pageID == "p2" })
        XCTAssertTrue(report.issues.contains { $0.code == .unreadableTextFile && $0.pageID == "p1" })
        XCTAssertEqual(Set(report.summary.reviewPageIDs), Set(["p1", "p2"]))
    }

    func testManifestOrderAndGapFail() throws {
        let root = try makePackage(pages: [page(1, "p1"), page(3, "p3"), page(2, "p2")])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 3)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .manifestOrderMismatch })
        XCTAssertFalse(report.issues.contains { $0.code == .nonContiguousSequence })

        let gapRoot = try makePackage(pages: [page(1, "a"), page(3, "c")])
        let gap = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 2)).verify(rootURL: gapRoot)
        XCTAssertTrue(gap.issues.contains { $0.code == .nonContiguousSequence })
    }

    func testPDFPageCountMismatchFails() throws {
        let root = try makePackage(pages: [page(1, "p1"), page(2, "p2"), page(3, "p3")])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 2)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .pdfPageCountMismatch })
    }

    func testMissingFinalArtifactsFail() throws {
        let root = try makePackage(pages: [page(1, "p1")])
        try FileManager.default.removeItem(at: root.appendingPathComponent("book_searchable.pdf"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("book.md"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("book.txt"))
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 1)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .searchablePDFMissing })
        XCTAssertTrue(report.issues.contains { $0.code == .aggregateMarkdownMissing })
        XCTAssertTrue(report.issues.contains { $0.code == .aggregateTextMissing })
    }

    func testPathTraversalIsRejected() throws {
        let bad = PackageManifestSnapshot.Page(sequence: 1, pageID: "p1", imagePath: "../secret.jpg", textPath: "text/0001.txt", sourceTimeMS: nil, needsReview: false)
        let root = try makePackage(pages: [bad], createReferencedFiles: false)
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 1)).verify(rootURL: root)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .unsafeRelativePath })
    }

    func testJSONAndMarkdownReportsAreStable() throws {
        let root = try makePackage(pages: [page(1, "p1")])
        let report = PackageIntegrityVerifier(pdfInspector: StubPDFInspector(count: 1)).verify(rootURL: root)
        let json = try PackageIntegrityVerifier.jsonData(report)
        let decoded = try JSONDecoder().decode(PackageIntegrityReport.self, from: json)
        XCTAssertEqual(decoded, report)
        let markdown = PackageIntegrityVerifier.markdown(report)
        XCTAssertTrue(markdown.contains("BookPackage Integrity Report"))
        XCTAssertTrue(markdown.contains("manifest_pages: 1"))
    }

    private func page(_ sequence: Int, _ pageID: String) -> PackageManifestSnapshot.Page {
        let stem = String(format: "%04d", sequence)
        return .init(sequence: sequence, pageID: pageID, imagePath: "pages/\(stem).jpg", textPath: "text/\(stem).txt", sourceTimeMS: Int64(sequence * 1000), needsReview: false)
    }

    private func makePackage(pages: [PackageManifestSnapshot.Page], createReferencedFiles: Bool = true) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("pages"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("text"), withIntermediateDirectories: true)
        if createReferencedFiles {
            for item in pages {
                if !item.imagePath.hasPrefix("../") {
                    let url = root.appendingPathComponent(item.imagePath)
                    if !FileManager.default.fileExists(atPath: url.path) {
                        try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: url)
                    }
                }
                if !item.textPath.hasPrefix("../") {
                    let url = root.appendingPathComponent(item.textPath)
                    if !FileManager.default.fileExists(atPath: url.path) {
                        try "text \(item.pageID)".data(using: .utf8)!.write(to: url)
                    }
                }
            }
        }
        try "# Book".data(using: .utf8)!.write(to: root.appendingPathComponent("book.md"))
        try "Book text".data(using: .utf8)!.write(to: root.appendingPathComponent("book.txt"))
        try Data("%PDF-fixture".utf8).write(to: root.appendingPathComponent("book_searchable.pdf"))
        let manifest = PackageManifestSnapshot(schemaVersion: 1, bookID: "fixture-book", pages: pages)
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
        return root
    }
}
