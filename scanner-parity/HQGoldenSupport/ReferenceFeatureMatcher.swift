import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Vision

public enum ReferenceFeatureMatcherError: Error, LocalizedError {
    case unreadablePDF(URL)
    case unreadableImage(URL)
    case renderFailed(Int)
    case featurePrintFailed
    case emptyReference

    public var errorDescription: String? {
        switch self {
        case .unreadablePDF(let url): return "Cannot open reference PDF: \(url.lastPathComponent)"
        case .unreadableImage(let url): return "Cannot open output image: \(url.lastPathComponent)"
        case .renderFailed(let index): return "Cannot render reference PDF page \(index + 1)"
        case .featurePrintFailed: return "Vision feature-print generation failed."
        case .emptyReference: return "Reference PDF has no pages."
        }
    }
}

public enum ReferenceFeatureMatcher {
    public static func compare(referencePDFURL: URL, outputImageURLs: [URL]) throws -> [ReferenceNearestMatch] {
        guard let document = PDFDocument(url: referencePDFURL) else {
            throw ReferenceFeatureMatcherError.unreadablePDF(referencePDFURL)
        }
        guard document.pageCount > 0 else { throw ReferenceFeatureMatcherError.emptyReference }

        let referencePrints: [VNFeaturePrintObservation] = try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index), let image = render(page: page) else {
                throw ReferenceFeatureMatcherError.renderFailed(index)
            }
            return try featurePrint(image)
        }

        return try outputImageURLs.enumerated().map { outputIndex, url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ReferenceFeatureMatcherError.unreadableImage(url)
            }
            let outputPrint = try featurePrint(image)
            var distances: [(Int, Float)] = []
            distances.reserveCapacity(referencePrints.count)
            for (referenceIndex, referencePrint) in referencePrints.enumerated() {
                var distance: Float = 0
                try outputPrint.computeDistance(&distance, to: referencePrint)
                distances.append((referenceIndex, distance))
            }
            distances.sort { $0.1 < $1.1 }
            guard let nearest = distances.first else { throw ReferenceFeatureMatcherError.emptyReference }
            return ReferenceNearestMatch(
                outputIndex: outputIndex,
                referenceIndex: nearest.0,
                distance: nearest.1,
                secondBestDistance: distances.dropFirst().first?.1
            )
        }
    }

    private static func featurePrint(_ image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        guard let result = request.results?.first as? VNFeaturePrintObservation else {
            throw ReferenceFeatureMatcherError.featurePrintFailed
        }
        return result
    }

    private static func render(page: PDFPage, maximumDimension: CGFloat = 1200) -> CGImage? {
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
}
