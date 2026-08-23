import Foundation

public enum SearchablePDFWriter {
    public static func writeIfSupported(pages: [OCRPageArtifact], outputURL: URL) throws -> URL? {
        #if canImport(UIKit) && canImport(CoreText)
        try writeUIKitPDF(pages: pages, outputURL: outputURL)
        return outputURL
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit) && canImport(CoreText)
import CoreText
import UIKit

private extension SearchablePDFWriter {
    static func writeUIKitPDF(pages: [OCRPageArtifact], outputURL: URL) throws {
        let defaultBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: defaultBounds)
        try renderer.writePDF(to: outputURL) { context in
            for artifact in pages.sorted(by: { $0.sequence < $1.sequence }) {
                guard let image = UIImage(contentsOfFile: artifact.imageURL.path), image.size.width > 0 else { continue }
                let width: CGFloat = 612
                let height = width * image.size.height / image.size.width
                let pageBounds = CGRect(x: 0, y: 0, width: width, height: height)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                image.draw(in: pageBounds)

                let cg = context.cgContext
                cg.saveGState()
                cg.setTextDrawingMode(.invisible)
                cg.textMatrix = .identity
                for block in artifact.ocrPage.blocks where !block.text.isEmpty {
                    let rect = CGRect(
                        x: CGFloat(block.boundingBox.x) * width,
                        y: CGFloat(block.boundingBox.y) * height,
                        width: max(1, CGFloat(block.boundingBox.width) * width),
                        height: max(1, CGFloat(block.boundingBox.height) * height)
                    )
                    let fontSize = max(4, min(24, rect.height * 0.8))
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize),
                        .foregroundColor: UIColor.black
                    ]
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: block.text, attributes: attributes))
                    cg.textPosition = CGPoint(x: rect.minX, y: rect.minY + max(fontSize, rect.height * 0.15))
                    CTLineDraw(line, cg)
                }
                cg.restoreGState()
            }
        }
    }
}
#endif
