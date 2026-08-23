import XCTest
@testable import ScannerRuntime

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(PDFKit) && canImport(UniformTypeIdentifiers)
import CoreGraphics
import ImageIO
import PDFKit
import UniformTypeIdentifiers

final class SearchablePDFWriterTests: XCTestCase {
    func testWritesSearchablePDFOnMacOS() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = root.appendingPathComponent("page.jpg")
        try writeFixtureJPEG(to: imageURL)

        let page = OCRPage(
            pageID: "page-0001",
            layout: .horizontal,
            text: "Golden searchable text 日本語",
            blocks: [
                OCRBlock(
                    text: "Golden searchable text 日本語",
                    confidence: 0.99,
                    boundingBox: OCRRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
                    sourceIndex: 0
                )
            ],
            ocrConfidence: 0.99,
            engine: "fixture",
            engineVersion: "1",
            needsReview: false
        )
        let artifact = OCRPageArtifact(sequence: 1, imageURL: imageURL, ocrPage: page)
        let pdfURL = root.appendingPathComponent("book_searchable.pdf")

        let written = try SearchablePDFWriter.writeIfSupported(pages: [artifact], outputURL: pdfURL)
        XCTAssertEqual(written, pdfURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path))

        let document = try XCTUnwrap(PDFDocument(url: pdfURL))
        XCTAssertEqual(document.pageCount, 1)
        let extracted = document.page(at: 0)?.string ?? ""
        XCTAssertTrue(extracted.contains("Golden searchable text"), "PDF text layer was not extractable: \(extracted)")
    }

    private func writeFixtureJPEG(to url: URL) throws {
        let width = 400
        let height = 600
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
#endif
