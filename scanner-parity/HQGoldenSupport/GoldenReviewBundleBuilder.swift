import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public struct GoldenReviewOCRPage: Codable, Sendable, Equatable {
    public let sequence: Int
    public let text: String
    public let confidence: Double
    public let layout: String
    public let needsReview: Bool

    public init(sequence: Int, text: String, confidence: Double, layout: String, needsReview: Bool) {
        self.sequence = sequence
        self.text = text
        self.confidence = confidence
        self.layout = layout
        self.needsReview = needsReview
    }
}

public struct GoldenReviewBundlePage: Codable, Sendable, Equatable {
    public let sequence: Int
    public let outputImagePath: String
    public let referenceImagePath: String?
    public let ocrTextPath: String
    public let referencePageNumber: Int?
    public let referenceDistance: Float?
    public let secondBestDistance: Float?
    public let ocrConfidence: Double
    public let ocrLayout: String
    public let ocrNeedsReview: Bool
}

public struct GoldenReviewBundleManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let referencePDFFileName: String
    public let pageCount: Int
    public let pages: [GoldenReviewBundlePage]

    public init(schemaVersion: Int = 1, referencePDFFileName: String, pageCount: Int, pages: [GoldenReviewBundlePage]) {
        self.schemaVersion = schemaVersion
        self.referencePDFFileName = referencePDFFileName
        self.pageCount = pageCount
        self.pages = pages
    }
}

public enum GoldenReviewBundleError: Error, LocalizedError {
    case unreadableReferencePDF
    case outputOCRCountMismatch(output: Int, ocr: Int)
    case missingReferencePage(Int)
    case referenceRenderFailed(Int)
    case outputImageCopyFailed(String)
    case imageWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableReferencePDF:
            return "Cannot open the Golden reference PDF."
        case .outputOCRCountMismatch(let output, let ocr):
            return "Golden review bundle output/OCR count mismatch: output=\(output), ocr=\(ocr)."
        case .missingReferencePage(let page):
            return "Golden review bundle cannot resolve reference page \(page)."
        case .referenceRenderFailed(let page):
            return "Golden review bundle cannot render reference page \(page)."
        case .outputImageCopyFailed(let file):
            return "Golden review bundle cannot copy output image \(file)."
        case .imageWriteFailed(let file):
            return "Golden review bundle cannot write image \(file)."
        }
    }
}

/// Creates a local-only, self-contained review surface for the real Golden run.
/// The bundle intentionally contains rendered book pages and OCR text, so it is
/// suitable for local/HQ review only and must not be committed or uploaded as
/// repository evidence. The manifest stores filenames/relative paths only.
public enum GoldenReviewBundleBuilder {
    public static func write(
        referencePDFURL: URL,
        outputImageURLs: [URL],
        referenceMatches: [ReferenceNearestMatch],
        ocrPages: [GoldenReviewOCRPage],
        destinationURL: URL
    ) throws -> GoldenReviewBundleManifest {
        guard let document = PDFDocument(url: referencePDFURL), document.pageCount > 0 else {
            throw GoldenReviewBundleError.unreadableReferencePDF
        }
        guard outputImageURLs.count == ocrPages.count else {
            throw GoldenReviewBundleError.outputOCRCountMismatch(output: outputImageURLs.count, ocr: ocrPages.count)
        }

        try resetDirectory(destinationURL)
        let outputDirectory = destinationURL.appendingPathComponent("images/output", isDirectory: true)
        let referenceDirectory = destinationURL.appendingPathComponent("images/reference", isDirectory: true)
        let textDirectory = destinationURL.appendingPathComponent("text", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: referenceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: textDirectory, withIntermediateDirectories: true)

        let matchByOutput = Dictionary(uniqueKeysWithValues: referenceMatches.map { ($0.outputIndex, $0) })
        let ocrBySequence = Dictionary(uniqueKeysWithValues: ocrPages.map { ($0.sequence, $0) })

        var pages: [GoldenReviewBundlePage] = []
        pages.reserveCapacity(outputImageURLs.count)

        for (outputIndex, sourceURL) in outputImageURLs.enumerated() {
            let sequence = outputIndex + 1
            guard let ocr = ocrBySequence[sequence] else {
                throw GoldenReviewBundleError.outputOCRCountMismatch(output: outputImageURLs.count, ocr: ocrPages.count)
            }

            let outputName = String(format: "%04d.%@", sequence, normalizedExtension(sourceURL.pathExtension))
            let outputDestination = outputDirectory.appendingPathComponent(outputName)
            do {
                try FileManager.default.copyItem(at: sourceURL, to: outputDestination)
            } catch {
                throw GoldenReviewBundleError.outputImageCopyFailed(sourceURL.lastPathComponent)
            }

            let textName = String(format: "%04d.txt", sequence)
            let textDestination = textDirectory.appendingPathComponent(textName)
            try ocr.text.write(to: textDestination, atomically: true, encoding: .utf8)

            let match = matchByOutput[outputIndex]
            var referencePath: String?
            var referencePageNumber: Int?
            if let match {
                let pageNumber = match.referenceIndex + 1
                guard match.referenceIndex >= 0,
                      match.referenceIndex < document.pageCount,
                      let page = document.page(at: match.referenceIndex) else {
                    throw GoldenReviewBundleError.missingReferencePage(pageNumber)
                }
                guard let image = render(page: page) else {
                    throw GoldenReviewBundleError.referenceRenderFailed(pageNumber)
                }
                let referenceName = String(format: "%04d-ref-%04d.jpg", sequence, pageNumber)
                let referenceDestination = referenceDirectory.appendingPathComponent(referenceName)
                try writeJPEG(image, to: referenceDestination)
                referencePath = "images/reference/\(referenceName)"
                referencePageNumber = pageNumber
            }

            pages.append(.init(
                sequence: sequence,
                outputImagePath: "images/output/\(outputName)",
                referenceImagePath: referencePath,
                ocrTextPath: "text/\(textName)",
                referencePageNumber: referencePageNumber,
                referenceDistance: match?.distance,
                secondBestDistance: match?.secondBestDistance,
                ocrConfidence: ocr.confidence,
                ocrLayout: ocr.layout,
                ocrNeedsReview: ocr.needsReview
            ))
        }

        let manifest = GoldenReviewBundleManifest(
            referencePDFFileName: referencePDFURL.lastPathComponent,
            pageCount: pages.count,
            pages: pages
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: destinationURL.appendingPathComponent("review-manifest.json"), options: .atomic)
        try html(manifest: manifest, ocrPages: ocrBySequence).write(
            to: destinationURL.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        return manifest
    }

    private static func html(manifest: GoldenReviewBundleManifest, ocrPages: [Int: GoldenReviewOCRPage]) -> String {
        let cards = manifest.pages.map { page -> String in
            let ocr = ocrPages[page.sequence]
            let refNumber = page.referencePageNumber.map(String.init) ?? "unmatched"
            let distance = page.referenceDistance.map { String(format: "%.5f", $0) } ?? "n/a"
            let second = page.secondBestDistance.map { String(format: "%.5f", $0) } ?? "n/a"
            let referenceImage = page.referenceImagePath.map {
                "<img loading=\"lazy\" src=\"\(htmlEscape($0))\" alt=\"reference page \(refNumber)\">"
            } ?? "<div class=\"missing\">No reference match</div>"
            let reviewClass = page.ocrNeedsReview ? " review" : ""
            return """
            <section class="page\(reviewClass)">
              <h2>Output \(page.sequence) → Reference \(refNumber)</h2>
              <div class="meta">distance \(distance) · second-best \(second) · OCR confidence \(String(format: "%.3f", page.ocrConfidence)) · layout \(htmlEscape(page.ocrLayout)) · OCR review \(page.ocrNeedsReview ? "required" : "not flagged")</div>
              <div class="compare">
                <figure><figcaption>Reference</figcaption>\(referenceImage)</figure>
                <figure><figcaption>Scanner output</figcaption><img loading="lazy" src="\(htmlEscape(page.outputImagePath))" alt="scanner output \(page.sequence)"></figure>
              </div>
              <details open><summary>OCR text</summary><pre>\(htmlEscape(ocr?.text ?? ""))</pre></details>
              <div class="links"><a href="\(htmlEscape(page.ocrTextPath))">OCR TXT</a></div>
            </section>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>HQ Formal Golden Visual/OCR Review</title>
          <style>
            body{font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;margin:24px;background:#f5f5f5;color:#111}
            header,.page{max-width:1500px;margin:0 auto 24px;background:white;border:1px solid #ddd;border-radius:12px;padding:18px}
            .page.review{border:3px solid #b45309}.compare{display:grid;grid-template-columns:1fr 1fr;gap:16px}.compare img{width:100%;height:auto;border:1px solid #bbb;background:#eee}.meta{font-family:ui-monospace,monospace;font-size:13px;margin-bottom:12px}.missing{min-height:260px;display:grid;place-items:center;background:#eee;color:#666}pre{white-space:pre-wrap;word-break:break-word;background:#f7f7f7;padding:12px;border-radius:8px}.links{margin-top:8px}@media(max-width:800px){.compare{grid-template-columns:1fr}}
          </style>
        </head>
        <body>
          <header>
            <h1>HQ Formal Golden Visual/OCR Review</h1>
            <p>Reference: \(htmlEscape(manifest.referencePDFFileName)) · output pages: \(manifest.pageCount)</p>
            <p>This local bundle is review material derived from the Golden book. Do not commit or upload the bundle as repository evidence.</p>
          </header>
          \(cards)
        </body>
        </html>
        """
    }

    private static func normalizedExtension(_ ext: String) -> String {
        let lowered = ext.lowercased()
        return ["jpg", "jpeg", "png"].contains(lowered) ? lowered : "jpg"
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func render(page: PDFPage, maximumDimension: CGFloat = 1400) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = maximumDimension / max(bounds.width, bounds.height)
        let width = max(1, Int(ceil(bounds.width * scale)))
        let height = max(1, Int(ceil(bounds.height * scale)))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return context.makeImage()
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw GoldenReviewBundleError.imageWriteFailed(url.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw GoldenReviewBundleError.imageWriteFailed(url.lastPathComponent)
        }
    }

    private static func resetDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
