import CoreGraphics
import CryptoKit
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
    case unreadableReferenceCorpusManifest(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadablePDF(let url): return "Cannot open reference PDF: \(url.lastPathComponent)"
        case .unreadableImage(let url): return "Cannot open output image: \(url.lastPathComponent)"
        case .renderFailed(let index): return "Cannot render reference PDF page \(index + 1)"
        case .featurePrintFailed: return "Vision feature-print generation failed."
        case .emptyReference: return "Reference PDF has no pages."
        case .unreadableReferenceCorpusManifest(let url):
            return "Cannot read configured reference-corpus manifest: \(url.lastPathComponent)"
        }
    }
}

public enum ReferenceFeatureMatcher {
    public static let referenceCorpusManifestEnvironmentKey = "SCANNER_GOLDEN_REFERENCE_MANIFEST"

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

        let corpus = try configuredReferenceCorpus(
            referencePDFURL: referencePDFURL,
            referencePDFPageCount: document.pageCount
        )

        return try outputImageURLs.enumerated().map { outputIndex, url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw ReferenceFeatureMatcherError.unreadableImage(url)
            }
            let outputPrint = try featurePrint(image)
            var rawDistances: [(referenceIndex: Int, distance: Float)] = []
            rawDistances.reserveCapacity(referencePrints.count)
            for (referenceIndex, referencePrint) in referencePrints.enumerated() {
                var distance: Float = 0
                try outputPrint.computeDistance(&distance, to: referencePrint)
                rawDistances.append((referenceIndex, distance))
            }

            guard let corpus else {
                let distances = rawDistances.sorted { $0.distance < $1.distance }
                guard let nearest = distances.first else { throw ReferenceFeatureMatcherError.emptyReference }
                return ReferenceNearestMatch(
                    outputIndex: outputIndex,
                    referenceIndex: nearest.referenceIndex,
                    distance: nearest.distance,
                    secondBestDistance: distances.dropFirst().first?.distance
                )
            }

            let distanceByReference = Dictionary(uniqueKeysWithValues: rawDistances.map { ($0.referenceIndex, $0.distance) })
            let groupDistances: [(groupIndex: Int, groupID: String, sourceReferenceIndex: Int, distance: Float)] = corpus.manifest.groups.enumerated().compactMap { groupIndex, group in
                let candidates = group.referencePageNumbers.compactMap { pageNumber -> (Int, Float)? in
                    let rawIndex = pageNumber - 1
                    guard let distance = distanceByReference[rawIndex] else { return nil }
                    return (rawIndex, distance)
                }
                guard let nearest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
                return (groupIndex, group.id, nearest.0, nearest.1)
            }.sorted { $0.distance < $1.distance }

            guard let nearestGroup = groupDistances.first else {
                throw ReferenceFeatureMatcherError.emptyReference
            }

            let nearestNegative: (Int, Float)? = corpus.manifest.negativeReferencePageNumbers
                .compactMap { pageNumber -> (Int, Float)? in
                    let rawIndex = pageNumber - 1
                    guard let distance = distanceByReference[rawIndex] else { return nil }
                    return (rawIndex, distance)
                }
                .min(by: { $0.1 < $1.1 })

            return ReferenceNearestMatch(
                outputIndex: outputIndex,
                referenceIndex: nearestGroup.sourceReferenceIndex,
                distance: nearestGroup.distance,
                secondBestDistance: groupDistances.dropFirst().first?.distance,
                canonicalReferenceIndex: nearestGroup.groupIndex,
                referenceCorpusPageCount: corpus.manifest.groups.count,
                referenceCorpusGroupID: nearestGroup.groupID,
                nearestNegativeReferenceIndex: nearestNegative?.0,
                nearestNegativeDistance: nearestNegative?.1,
                referenceCorpusManifestSHA256: corpus.manifestSHA256
            )
        }
    }

    private struct ConfiguredReferenceCorpus {
        let manifest: ReferenceCorpusManifest
        let manifestSHA256: String
    }

    private static func configuredReferenceCorpus(
        referencePDFURL: URL,
        referencePDFPageCount: Int
    ) throws -> ConfiguredReferenceCorpus? {
        guard let rawPath = ProcessInfo.processInfo.environment[referenceCorpusManifestEnvironmentKey],
              !rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let manifestURL = URL(fileURLWithPath: rawPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ReferenceCorpusManifest.self, from: data) else {
            throw ReferenceFeatureMatcherError.unreadableReferenceCorpusManifest(manifestURL)
        }

        let pdfSHA = try sha256File(referencePDFURL)
        try manifest.validate(
            actualPDFPageCount: referencePDFPageCount,
            actualPDFSHA256: pdfSHA
        )
        return ConfiguredReferenceCorpus(
            manifest: manifest,
            manifestSHA256: sha256(data)
        )
    }

    private static func sha256File(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 4 * 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
