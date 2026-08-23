import Foundation
import XCTest
import PackageValidation
@testable import PackageQuality

private struct StubPDFTextInspector: PDFTextLayerInspecting {
    let texts: [String]
    func pageTexts(at url: URL) throws -> [String] { texts }
}

final class BookPackageQualityAuditorTests: XCTestCase {
    func testValidVerticalHorizontalMixedPackagePasses() throws {
        let root = try makePackage(sequences: [1, 2, 3])
        let ocr = [
            qualityPage(1, "p1", .vertical, fixtureText(1)),
            qualityPage(2, "p2", .horizontal, fixtureText(2)),
            qualityPage(3, "p3", .mixed, fixtureText(3))
        ]
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1), fixtureText(2), fixtureText(3)])).audit(rootURL: root, ocrPages: ocr)
        XCTAssertTrue(report.valid)
        XCTAssertEqual(report.metrics.pdfTextLayerCoverage, 1)
        XCTAssertEqual(report.metrics.pdfTextOrderAccuracy, 1)
        XCTAssertEqual(report.metrics.markdownBoundaryAccuracy, 1)
        XCTAssertEqual(report.metrics.textBoundaryAccuracy, 1)
        XCTAssertEqual(report.metrics.lineageCoverage, 1)
        XCTAssertEqual(report.ingestionRecords.map(\.pageID), ["p1", "p2", "p3"])
    }

    func testEmptyPDFTextLayerFails() throws {
        let root = try makePackage(sequences: [1, 2])
        let ocr = [qualityPage(1, "p1", .vertical, fixtureText(1)), qualityPage(2, "p2", .horizontal, fixtureText(2))]
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: ["", ""])).audit(rootURL: root, ocrPages: ocr)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .pdfTextLayerMissing })
    }

    func testSwappedPDFTextOrderFails() throws {
        let root = try makePackage(sequences: [1, 2])
        let one = qualityPage(1, "p1", .horizontal, fixtureText(1))
        let two = qualityPage(2, "p2", .horizontal, fixtureText(2))
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(2), fixtureText(1)])).audit(rootURL: root, ocrPages: [one, two])
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .pdfTextOrderMismatch })
    }

    func testMarkdownAndTextBoundaryMismatchFail() throws {
        let root = try makePackage(sequences: [1, 2, 3])
        try "# Book\n## Page 1\na\n## Page 3\nc".data(using: .utf8)!.write(to: root.appendingPathComponent("book.md"))
        try "=== PAGE 1 ===\na\n=== PAGE 3 ===\nc".data(using: .utf8)!.write(to: root.appendingPathComponent("book.txt"))
        let ocr = [1, 2, 3].map { qualityPage($0, "p\($0)", .horizontal, fixtureText($0)) }
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1), fixtureText(2), fixtureText(3)])).audit(rootURL: root, ocrPages: ocr)
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .markdownBoundaryMismatch })
        XCTAssertTrue(report.issues.contains { $0.code == .textBoundaryMismatch })
    }

    func testMissingSourceTimeFailsAIIngestionLineage() throws {
        let root = try makePackage(sequences: [1, 2], missingSourceTimeSequence: 2)
        let ocr = [qualityPage(1, "p1", .horizontal, fixtureText(1)), qualityPage(2, "p2", .horizontal, fixtureText(2))]
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1), fixtureText(2)])).audit(rootURL: root, ocrPages: ocr)
        XCTAssertFalse(report.valid)
        XCTAssertEqual(report.metrics.lineageCoverage, 0.5)
        XCTAssertTrue(report.issues.contains { $0.code == .manifestLineageMissing && $0.pageID == "p2" })
        XCTAssertEqual(report.ingestionRecords.map(\.pageID), ["p1"])
    }

    func testLowQualityOCRMustBeMarkedForReview() throws {
        let root = try makePackage(sequences: [1])
        let bad = PackageOCRQualityPage(pageID: "p1", sequence: 1, layout: .unknown, text: "短", confidence: 0.2, needsReview: false, sourceTimeMS: 1000)
        let failed = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1)])).audit(rootURL: root, ocrPages: [bad])
        XCTAssertFalse(failed.valid)
        XCTAssertTrue(failed.issues.contains { $0.code == .ocrLowQualityUnreviewed })
        XCTAssertTrue(failed.issues.contains { $0.code == .ocrUnknownLayoutUnreviewed })

        let reviewed = PackageOCRQualityPage(pageID: "p1", sequence: 1, layout: .unknown, text: "短", confidence: 0.2, needsReview: true, sourceTimeMS: 1000)
        let accepted = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1)])).audit(rootURL: root, ocrPages: [reviewed])
        XCTAssertTrue(accepted.valid)
        XCTAssertTrue(accepted.issues.contains { $0.code == .ocrReviewRequired && $0.severity == .warning })
        XCTAssertEqual(accepted.metrics.ocrReviewedOrAcceptedRatio, 1)
    }

    func testJSONAndMarkdownQualityReportRoundTrip() throws {
        let root = try makePackage(sequences: [1])
        let page = qualityPage(1, "p1", .horizontal, fixtureText(1))
        let report = BookPackageQualityAuditor(pdfTextInspector: StubPDFTextInspector(texts: [fixtureText(1)])).audit(rootURL: root, ocrPages: [page])
        let data = try BookPackageQualityAuditor.jsonData(report)
        XCTAssertEqual(try JSONDecoder().decode(PackageQualityReport.self, from: data), report)
        XCTAssertTrue(BookPackageQualityAuditor.markdown(report).contains("Package Quality Report"))
    }

    private func qualityPage(_ sequence: Int, _ pageID: String, _ layout: PackageTextLayout, _ text: String) -> PackageOCRQualityPage {
        .init(pageID: pageID, sequence: sequence, layout: layout, text: text, confidence: 0.95, needsReview: false, sourceTimeMS: Int64(sequence * 1000))
    }

    private func fixtureText(_ sequence: Int) -> String {
        switch sequence {
        case 1: return "第一ページ固有の日本語本文をここに記録します。"
        case 2: return "第二ページだけに存在する異なる日本語本文です。"
        default: return "第三ページの日本語本文で他と識別できます。"
        }
    }

    private func makePackage(sequences: [Int], missingSourceTimeSequence: Int? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("pages"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("text"), withIntermediateDirectories: true)
        var pages: [PackageManifestSnapshot.Page] = []
        var markdown = ["# Book fixture"]
        var bookText: [String] = []
        for sequence in sequences {
            let stem = String(format: "%04d", sequence)
            let text = fixtureText(sequence)
            try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: root.appendingPathComponent("pages/\(stem).jpg"))
            try text.data(using: .utf8)!.write(to: root.appendingPathComponent("text/\(stem).txt"))
            markdown.append("## Page \(sequence)\n\(text)")
            bookText.append("=== PAGE \(sequence) ===\n\(text)")
            pages.append(.init(sequence: sequence, pageID: "p\(sequence)", imagePath: "pages/\(stem).jpg", textPath: "text/\(stem).txt", sourceTimeMS: sequence == missingSourceTimeSequence ? nil : Int64(sequence * 1000), needsReview: false))
        }
        try markdown.joined(separator: "\n").data(using: .utf8)!.write(to: root.appendingPathComponent("book.md"))
        try bookText.joined(separator: "\n").data(using: .utf8)!.write(to: root.appendingPathComponent("book.txt"))
        try Data("%PDF-fixture".utf8).write(to: root.appendingPathComponent("book_searchable.pdf"))
        let manifest = PackageManifestSnapshot(schemaVersion: 1, bookID: "fixture", pages: pages)
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
        return root
    }
}
