import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import HQGoldenSupport

final class GoldenReviewBundleBuilderTests: XCTestCase {
    func testWritesRelativeSelfContainedReviewBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let referencePDF = root.appendingPathComponent("reference.pdf")
        let outputImage = root.appendingPathComponent("output.jpg")
        try makePDF(at: referencePDF)
        try makeJPEG(at: outputImage)

        let destination = root.appendingPathComponent("review", isDirectory: true)
        let manifest = try GoldenReviewBundleBuilder.write(
            referencePDFURL: referencePDF,
            outputImageURLs: [outputImage],
            referenceMatches: [
                ReferenceNearestMatch(outputIndex: 0, referenceIndex: 0, distance: 0.12, secondBestDistance: 0.44)
            ],
            ocrPages: [
                GoldenReviewOCRPage(sequence: 1, text: "日本語 <unsafe> & review", confidence: 0.91, layout: "vertical", needsReview: true)
            ],
            destinationURL: destination
        )

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.pageCount, 1)
        XCTAssertEqual(manifest.referencePDFFileName, "reference.pdf")
        XCTAssertEqual(manifest.pages.first?.referencePageNumber, 1)
        XCTAssertEqual(manifest.pages.first?.outputImagePath, "images/output/0001.jpg")
        XCTAssertEqual(manifest.pages.first?.referenceImagePath, "images/reference/0001-ref-0001.jpg")
        XCTAssertEqual(manifest.pages.first?.ocrTextPath, "text/0001.txt")

        let required = [
            "index.html",
            "review-manifest.json",
            "images/output/0001.jpg",
            "images/reference/0001-ref-0001.jpg",
            "text/0001.txt",
        ]
        for relativePath in required {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent(relativePath).path), "missing \(relativePath)")
        }

        let html = try String(contentsOf: destination.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertTrue(html.contains("日本語 &lt;unsafe&gt; &amp; review"))
        XCTAssertTrue(html.contains("Output 1 → Reference 1"))
        XCTAssertTrue(html.contains("OCR review required"))
        XCTAssertFalse(html.contains(root.path), "review HTML must not persist absolute local paths")

        let json = try String(contentsOf: destination.appendingPathComponent("review-manifest.json"), encoding: .utf8)
        XCTAssertFalse(json.contains(root.path), "review manifest must not persist absolute local paths")
        XCTAssertFalse(json.contains("file://"), "review manifest must stay relative")
    }

    func testRejectsOutputOCRCountMismatch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let referencePDF = root.appendingPathComponent("reference.pdf")
        let outputImage = root.appendingPathComponent("output.jpg")
        try makePDF(at: referencePDF)
        try makeJPEG(at: outputImage)

        XCTAssertThrowsError(try GoldenReviewBundleBuilder.write(
            referencePDFURL: referencePDF,
            outputImageURLs: [outputImage],
            referenceMatches: [],
            ocrPages: [],
            destinationURL: root.appendingPathComponent("review", isDirectory: true)
        )) { error in
            guard case GoldenReviewBundleError.outputOCRCountMismatch(let output, let ocr) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(output, 1)
            XCTAssertEqual(ocr, 0)
        }
    }

    private func makePDF(at url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 300, height: 400)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return XCTFail("cannot create PDF context")
        }
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(mediaBox)
        context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 40, y: 60, width: 220, height: 280))
        context.endPDFPage()
        context.closePDF()
    }

    private func makeJPEG(at url: URL) throws {
        guard let context = CGContext(
            data: nil,
            width: 120,
            height: 160,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return XCTFail("cannot create bitmap context")
        }
        context.setFillColor(CGColor(gray: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 160))
        context.setFillColor(CGColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 15, y: 20, width: 90, height: 120))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return XCTFail("cannot create JPEG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
