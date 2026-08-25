import XCTest
@testable import HQGoldenSupport

final class ReferenceCorpusManifestTests: XCTestCase {
    private let pdfSHA = String(repeating: "a", count: 64)

    func testValidManifestRequiresCompleteSingleAssignment() throws {
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: pdfSHA,
            referencePDFPageCount: 6,
            negativeReferencePageNumbers: [1, 2],
            groups: [
                .init(id: "g1", referencePageNumbers: [4, 6]),
                .init(id: "g2", referencePageNumbers: [3, 5])
            ]
        )
        XCTAssertNoThrow(try manifest.validate(actualPDFPageCount: 6, actualPDFSHA256: pdfSHA))
    }

    func testOverlapFailsClosed() {
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: pdfSHA,
            referencePDFPageCount: 3,
            negativeReferencePageNumbers: [1],
            groups: [
                .init(id: "g1", referencePageNumbers: [1, 2]),
                .init(id: "g2", referencePageNumbers: [3])
            ]
        )
        XCTAssertThrowsError(try manifest.validate(actualPDFPageCount: 3, actualPDFSHA256: pdfSHA))
    }

    func testUnassignedPageFailsClosed() {
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: pdfSHA,
            referencePDFPageCount: 4,
            negativeReferencePageNumbers: [1],
            groups: [
                .init(id: "g1", referencePageNumbers: [2]),
                .init(id: "g2", referencePageNumbers: [4])
            ]
        )
        XCTAssertThrowsError(try manifest.validate(actualPDFPageCount: 4, actualPDFSHA256: pdfSHA))
    }

    func testWrongPDFIdentityFailsClosed() {
        let manifest = ReferenceCorpusManifest(
            datasetID: "golden-v3",
            referencePDFSHA256: pdfSHA,
            referencePDFPageCount: 2,
            negativeReferencePageNumbers: [],
            groups: [
                .init(id: "g1", referencePageNumbers: [1]),
                .init(id: "g2", referencePageNumbers: [2])
            ]
        )
        XCTAssertThrowsError(
            try manifest.validate(
                actualPDFPageCount: 2,
                actualPDFSHA256: String(repeating: "b", count: 64)
            )
        )
    }
}
