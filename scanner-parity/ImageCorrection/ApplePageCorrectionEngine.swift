#if canImport(CoreGraphics) && canImport(CoreImage) && canImport(Vision)
import CoreGraphics
import CoreImage
import Foundation
import Vision

public enum PageCorrectionError: Error {
    case invalidImageExtent
    case perspectiveFilterUnavailable
}

public struct PageCorrectionConfiguration: Sendable {
    public var minimumRectangleConfidence: Float
    public var minimumRectangleAspectRatio: Float
    public var minimumRectangleSize: Float
    public var orientationPolicy: PageOrientationPolicy

    public init(
        minimumRectangleConfidence: Float = 0.60,
        minimumRectangleAspectRatio: Float = 0.30,
        minimumRectangleSize: Float = 0.30,
        orientationPolicy: PageOrientationPolicy = .preferPortrait
    ) {
        self.minimumRectangleConfidence = minimumRectangleConfidence
        self.minimumRectangleAspectRatio = minimumRectangleAspectRatio
        self.minimumRectangleSize = minimumRectangleSize
        self.orientationPolicy = orientationPolicy
    }
}

public struct CorrectedPageAssetSet {
    public let images: [CorrectionProfile: CIImage]
    public let metadata: [CorrectionProfile: CorrectedPageMetadata]
}

public final class PageCorrectionEngine {
    private let configuration: PageCorrectionConfiguration
    private let context: CIContext

    public init(configuration: PageCorrectionConfiguration = .init(), context: CIContext = CIContext(options: nil)) {
        self.configuration = configuration
        self.context = context
    }

    public func correct(cgImage: CGImage, candidateID: String, pageID: String) throws -> CorrectedPageAssetSet {
        let source = CIImage(cgImage: cgImage)
        guard source.extent.width > 0, source.extent.height > 0 else {
            throw PageCorrectionError.invalidImageExtent
        }

        let detection = try detectBestRectangle(cgImage: cgImage)
        let quad = detection?.quad ?? .fullFrame
        let boundaryConfidence = detection?.confidence ?? 0
        let perspectiveApplied = detection != nil && quad != .fullFrame

        var working = source
        var flags: [CorrectionFlag] = [.dewarpPendingGoldenEvaluation]
        if let detected = detection {
            working = try applyPerspectiveCorrection(source, quad: detected.quad)
            flags.append(.perspectiveApplied)
            if detected.confidence < 0.72 {
                flags.append(.lowBoundaryConfidence)
            }
        } else {
            flags.append(.boundaryFallback)
        }

        let rotation = OrientationEstimator.rotationDegrees(
            width: working.extent.width,
            height: working.extent.height,
            policy: configuration.orientationPolicy
        )
        if rotation != 0 {
            working = rotateClockwise(working, degrees: rotation)
            flags.append(.rotationApplied)
        }

        let reading = readingProfile(working)
        let ocr = ocrProfile(working)
        let sourceMetrics = luminanceMetrics(for: source)

        let baseQuality = CorrectionQualityScores(
            boundaryConfidence: boundaryConfidence,
            perspectiveSeverity: quad.perspectiveSeverity,
            residualSkewDegrees: quad.residualSkewDegrees,
            sourceLuminance: sourceMetrics,
            correctedLuminance: nil
        )

        var metadata: [CorrectionProfile: CorrectedPageMetadata] = [:]
        metadata[.archive] = .init(
            pageID: pageID,
            candidateID: candidateID,
            cropQuad: quad,
            rotationDegrees: 0,
            perspectiveApplied: false,
            dewarpApplied: false,
            colorProfile: .archive,
            qualityScores: baseQuality,
            flags: flags.filter { $0 != .perspectiveApplied && $0 != .rotationApplied }
        )
        metadata[.reading] = makeMetadata(
            profile: .reading,
            image: reading,
            pageID: pageID,
            candidateID: candidateID,
            quad: quad,
            rotation: rotation,
            perspectiveApplied: perspectiveApplied,
            boundaryConfidence: boundaryConfidence,
            sourceMetrics: sourceMetrics,
            flags: flags
        )
        metadata[.ocr] = makeMetadata(
            profile: .ocr,
            image: ocr,
            pageID: pageID,
            candidateID: candidateID,
            quad: quad,
            rotation: rotation,
            perspectiveApplied: perspectiveApplied,
            boundaryConfidence: boundaryConfidence,
            sourceMetrics: sourceMetrics,
            flags: flags + [.aggressiveBinarizationRejected]
        )

        return .init(images: [.archive: source, .reading: reading, .ocr: ocr], metadata: metadata)
    }

    private func detectBestRectangle(cgImage: CGImage) throws -> (quad: PageQuad, confidence: Double)? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 6
        request.minimumConfidence = configuration.minimumRectangleConfidence
        request.minimumAspectRatio = configuration.minimumRectangleAspectRatio
        request.minimumSize = configuration.minimumRectangleSize
        request.quadratureTolerance = 28

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        let candidates = (request.results ?? []).compactMap { observation -> (PageQuad, Double)? in
            let quad = PageQuad(
                topLeft: .init(x: Double(observation.topLeft.x), y: Double(observation.topLeft.y)),
                topRight: .init(x: Double(observation.topRight.x), y: Double(observation.topRight.y)),
                bottomRight: .init(x: Double(observation.bottomRight.x), y: Double(observation.bottomRight.y)),
                bottomLeft: .init(x: Double(observation.bottomLeft.x), y: Double(observation.bottomLeft.y))
            )
            guard quad.isPlausible() else { return nil }
            return (quad, Double(observation.confidence))
        }

        return candidates.max { lhs, rhs in
            (lhs.1 * lhs.0.area) < (rhs.1 * rhs.0.area)
        }
    }

    private func applyPerspectiveCorrection(_ image: CIImage, quad: PageQuad) throws -> CIImage {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw PageCorrectionError.perspectiveFilterUnavailable
        }
        let extent = image.extent
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: imagePoint(quad.topLeft, extent: extent)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: imagePoint(quad.topRight, extent: extent)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: imagePoint(quad.bottomRight, extent: extent)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: imagePoint(quad.bottomLeft, extent: extent)), forKey: "inputBottomLeft")
        return filter.outputImage ?? image
    }

    private func imagePoint(_ point: NormalizedPoint, extent: CGRect) -> CGPoint {
        CGPoint(x: extent.minX + point.x * extent.width, y: extent.minY + point.y * extent.height)
    }

    private func rotateClockwise(_ image: CIImage, degrees: Int) -> CIImage {
        guard degrees % 360 != 0 else { return image }
        let radians = -CGFloat(degrees) * .pi / 180
        let center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: radians)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        let rotated = image.transformed(by: transform)
        return rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX, y: -rotated.extent.minY))
    }

    private func readingProfile(_ image: CIImage) -> CIImage {
        let shadowBalanced = applyFilter(
            name: "CIHighlightShadowAdjust",
            image: image,
            values: ["inputShadowAmount": 0.35, "inputHighlightAmount": 0.92]
        )
        return applyFilter(
            name: "CIColorControls",
            image: shadowBalanced,
            values: [kCIInputBrightnessKey: 0.01, kCIInputContrastKey: 1.08, kCIInputSaturationKey: 0.98]
        )
    }

    private func ocrProfile(_ image: CIImage) -> CIImage {
        let gray = applyFilter(
            name: "CIColorControls",
            image: image,
            values: [kCIInputBrightnessKey: 0.015, kCIInputContrastKey: 1.28, kCIInputSaturationKey: 0.0]
        )
        return applyFilter(name: "CISharpenLuminance", image: gray, values: [kCIInputSharpnessKey: 0.32])
    }

    private func applyFilter(name: String, image: CIImage, values: [String: Any]) -> CIImage {
        guard let filter = CIFilter(name: name) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        for (key, value) in values { filter.setValue(value, forKey: key) }
        return filter.outputImage ?? image
    }

    private func makeMetadata(
        profile: CorrectionProfile,
        image: CIImage,
        pageID: String,
        candidateID: String,
        quad: PageQuad,
        rotation: Int,
        perspectiveApplied: Bool,
        boundaryConfidence: Double,
        sourceMetrics: LuminanceMetrics?,
        flags: [CorrectionFlag]
    ) -> CorrectedPageMetadata {
        let quality = CorrectionQualityScores(
            boundaryConfidence: boundaryConfidence,
            perspectiveSeverity: quad.perspectiveSeverity,
            residualSkewDegrees: quad.residualSkewDegrees,
            sourceLuminance: sourceMetrics,
            correctedLuminance: luminanceMetrics(for: image)
        )
        return .init(
            pageID: pageID,
            candidateID: candidateID,
            cropQuad: quad,
            rotationDegrees: rotation,
            perspectiveApplied: perspectiveApplied,
            dewarpApplied: false,
            colorProfile: profile,
            qualityScores: quality,
            flags: flags
        )
    }

    private func luminanceMetrics(for image: CIImage, maximumDimension: CGFloat = 384) -> LuminanceMetrics? {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scale = min(1, maximumDimension / max(extent.width, extent.height))
        let sampled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let sampledExtent = sampled.extent.integral
        guard let cgImage = context.createCGImage(sampled, from: sampledExtent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let drew = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let base = rawBuffer.baseAddress,
                  let bitmap = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        var histogram = [Int](repeating: 0, count: 256)
        for value in pixels { histogram[Int(value)] += 1 }
        return LuminanceMetrics.from(histogram: histogram)
    }
}
#endif
