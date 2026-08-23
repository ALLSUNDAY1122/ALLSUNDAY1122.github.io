import Foundation

public enum SearchablePDFWriterError: Error, LocalizedError {
    case unsupported
    case imageDecodeFailed(URL)
    case consumerCreateFailed(URL)
    case contextCreateFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Searchable PDF generation is unsupported on this platform."
        case .imageDecodeFailed(let url):
            return "Could not decode page image: \(url.lastPathComponent)"
        case .consumerCreateFailed(let url):
            return "Could not create PDF data consumer: \(url.lastPathComponent)"
        case .contextCreateFailed(let url):
            return "Could not create PDF context: \(url.lastPathComponent)"
        }
    }
}

public enum SearchablePDFWriter {
    public static func writeIfSupported(pages: [OCRPageArtifact], outputURL: URL) throws -> URL? {
        #if canImport(CoreGraphics) && canImport(CoreText) && canImport(ImageIO)
        try writeCoreGraphicsPDF(pages: pages, outputURL: outputURL)
        return outputURL
        #else
        return nil
        #endif
    }
}

#if canImport(CoreGraphics) && canImport(CoreText) && canImport(ImageIO)
import CoreGraphics
import CoreText
import ImageIO

private extension SearchablePDFWriter {
    static func writeCoreGraphicsPDF(pages: [OCRPageArtifact], outputURL: URL) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw SearchablePDFWriterError.consumerCreateFailed(outputURL)
        }
        var initialBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &initialBox, nil) else {
            throw SearchablePDFWriterError.contextCreateFailed(outputURL)
        }

        for artifact in pages.sorted(by: { $0.sequence < $1.sequence }) {
            guard let source = CGImageSourceCreateWithURL(artifact.imageURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  image.width > 0,
                  image.height > 0 else {
                throw SearchablePDFWriterError.imageDecodeFailed(artifact.imageURL)
            }

            let width: CGFloat = 612
            let height = width * CGFloat(image.height) / CGFloat(image.width)
            let pageBounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.beginPDFPage([
                kCGPDFContextMediaBox as String: pageBounds
            ] as CFDictionary)
            context.draw(image, in: pageBounds)

            context.saveGState()
            context.setTextDrawingMode(.invisible)
            context.textMatrix = .identity
            for block in artifact.ocrPage.blocks where !block.text.isEmpty {
                let rect = CGRect(
                    x: CGFloat(block.boundingBox.x) * width,
                    y: CGFloat(block.boundingBox.y) * height,
                    width: max(1, CGFloat(block.boundingBox.width) * width),
                    height: max(1, CGFloat(block.boundingBox.height) * height)
                )
                let fontSize = max(4, min(24, rect.height * 0.8))
                let font = CTFontCreateUIFontForLanguage(.system, fontSize, "ja" as CFString)
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key(kCTFontAttributeName as String): font
                ]
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: block.text, attributes: attributes))
                context.textPosition = CGPoint(x: rect.minX, y: rect.minY + max(fontSize, rect.height * 0.15))
                CTLineDraw(line, context)
            }
            context.restoreGState()
            context.endPDFPage()
        }
        context.closePDF()
    }
}
#endif
