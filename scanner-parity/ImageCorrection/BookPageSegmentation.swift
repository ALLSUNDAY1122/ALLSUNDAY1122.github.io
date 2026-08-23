import Foundation

public enum BookPageSegmentRole: String, Codable, Sendable {
    case single
    case left
    case right
}

public struct BookPageQuadCandidate: Sendable, Equatable {
    public let quad: PageQuad
    public let confidence: Double
    public let role: BookPageSegmentRole

    public init(quad: PageQuad, confidence: Double, role: BookPageSegmentRole = .single) {
        self.quad = quad
        self.confidence = max(0, min(1, confidence))
        self.role = role
    }
}

/// Geometry-only policy kept outside Vision so the page/spread decision is
/// deterministic and testable. It rejects near-full-frame UI rectangles,
/// prefers two portrait pages in an open spread, and only falls back to a
/// landscape split when the detected book region itself is plausible.
public struct BookPageSegmentationPolicy: Sendable {
    public init() {}

    public func select(from candidates: [BookPageQuadCandidate]) -> [BookPageQuadCandidate] {
        let usable = candidates.filter { candidate in
            let b = bounds(candidate.quad)
            guard candidate.quad.isPlausible(minimumArea: 0.12),
                  candidate.quad.area <= 0.72,
                  candidate.confidence >= 0.55,
                  b.width > 0.08,
                  b.height > 0.20 else { return false }
            return true
        }
        guard !usable.isEmpty else { return [] }

        let portraits = usable.filter { aspectHeightOverWidth($0.quad) >= 1.03 }
        var bestPair: (BookPageQuadCandidate, BookPageQuadCandidate, Double)?
        for i in portraits.indices {
            for j in portraits.indices where j > i {
                let a = portraits[i]
                let b = portraits[j]
                let ab = bounds(a.quad)
                let bb = bounds(b.quad)
                let separation = abs(ab.midX - bb.midX)
                let verticalOverlap = overlap(ab.minY, ab.maxY, bb.minY, bb.maxY) / max(0.000_001, min(ab.height, bb.height))
                let horizontalOverlap = overlap(ab.minX, ab.maxX, bb.minX, bb.maxX) / max(0.000_001, min(ab.width, bb.width))
                guard separation >= 0.18,
                      verticalOverlap >= 0.55,
                      horizontalOverlap <= 0.28,
                      a.quad.area + b.quad.area >= 0.26 else { continue }
                let score = a.confidence + b.confidence + a.quad.area + b.quad.area + verticalOverlap * 0.2
                if bestPair == nil || score > bestPair!.2 { bestPair = (a, b, score) }
            }
        }

        if let pair = bestPair {
            let ordered = [pair.0, pair.1].sorted { bounds($0.quad).midX < bounds($1.quad).midX }
            return [
                .init(quad: ordered[0].quad, confidence: ordered[0].confidence, role: .left),
                .init(quad: ordered[1].quad, confidence: ordered[1].confidence, role: .right)
            ]
        }

        if let portrait = portraits.max(by: { quality($0) < quality($1) }), portrait.quad.area >= 0.16 {
            return [.init(quad: portrait.quad, confidence: portrait.confidence, role: .single)]
        }

        if let spread = usable
            .filter({ aspectWidthOverHeight($0.quad) >= 1.25 && $0.quad.area >= 0.28 && $0.confidence >= 0.72 })
            .max(by: { quality($0) < quality($1) }) {
            let halves = splitVertically(spread.quad)
            return [
                .init(quad: halves.0, confidence: spread.confidence * 0.94, role: .left),
                .init(quad: halves.1, confidence: spread.confidence * 0.94, role: .right)
            ]
        }

        return []
    }

    private func quality(_ candidate: BookPageQuadCandidate) -> Double {
        candidate.confidence * 0.7 + min(0.72, candidate.quad.area) * 0.3
    }

    private func aspectHeightOverWidth(_ quad: PageQuad) -> Double {
        let b = bounds(quad)
        return b.height / max(0.000_001, b.width)
    }

    private func aspectWidthOverHeight(_ quad: PageQuad) -> Double {
        let b = bounds(quad)
        return b.width / max(0.000_001, b.height)
    }

    private func splitVertically(_ quad: PageQuad) -> (PageQuad, PageQuad) {
        let topMid = midpoint(quad.topLeft, quad.topRight)
        let bottomMid = midpoint(quad.bottomLeft, quad.bottomRight)
        let left = PageQuad(
            topLeft: quad.topLeft,
            topRight: topMid,
            bottomRight: bottomMid,
            bottomLeft: quad.bottomLeft
        )
        let right = PageQuad(
            topLeft: topMid,
            topRight: quad.topRight,
            bottomRight: quad.bottomRight,
            bottomLeft: bottomMid
        )
        return (left, right)
    }

    private func midpoint(_ a: NormalizedPoint, _ b: NormalizedPoint) -> NormalizedPoint {
        .init(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private struct Bounds {
        let minX: Double
        let maxX: Double
        let minY: Double
        let maxY: Double
        var width: Double { maxX - minX }
        var height: Double { maxY - minY }
        var midX: Double { (minX + maxX) / 2 }
    }

    private func bounds(_ quad: PageQuad) -> Bounds {
        let xs = [quad.topLeft.x, quad.topRight.x, quad.bottomRight.x, quad.bottomLeft.x]
        let ys = [quad.topLeft.y, quad.topRight.y, quad.bottomRight.y, quad.bottomLeft.y]
        return .init(minX: xs.min() ?? 0, maxX: xs.max() ?? 0, minY: ys.min() ?? 0, maxY: ys.max() ?? 0)
    }

    private func overlap(_ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double) -> Double {
        max(0, min(a1, b1) - max(a0, b0))
    }
}

#if canImport(CoreGraphics) && canImport(CoreImage) && canImport(Vision)
import CoreGraphics
import CoreImage
import Vision

public struct BookPageSegment {
    public let image: CGImage
    public let role: BookPageSegmentRole
    public let confidence: Double

    public init(image: CGImage, role: BookPageSegmentRole, confidence: Double) {
        self.image = image
        self.role = role
        self.confidence = confidence
    }
}

public enum BookPageSegmentationError: Error {
    case cropFailed
}

public final class BookPageSegmentationEngine {
    private let context: CIContext
    private let policy: BookPageSegmentationPolicy

    public init(context: CIContext = CIContext(options: nil), policy: BookPageSegmentationPolicy = .init()) {
        self.context = context
        self.policy = policy
    }

    public func segment(cgImage: CGImage) throws -> [BookPageSegment] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 10
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.18
        request.minimumSize = 0.15
        request.quadratureTolerance = 30
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        let candidates = (request.results ?? []).compactMap { observation -> BookPageQuadCandidate? in
            let quad = PageQuad(
                topLeft: .init(x: Double(observation.topLeft.x), y: Double(observation.topLeft.y)),
                topRight: .init(x: Double(observation.topRight.x), y: Double(observation.topRight.y)),
                bottomRight: .init(x: Double(observation.bottomRight.x), y: Double(observation.bottomRight.y)),
                bottomLeft: .init(x: Double(observation.bottomLeft.x), y: Double(observation.bottomLeft.y))
            )
            guard quad.isPlausible(minimumArea: 0.12) else { return nil }
            return .init(quad: quad, confidence: Double(observation.confidence))
        }

        return try policy.select(from: candidates).map { selected in
            .init(image: try perspectiveCrop(cgImage, quad: selected.quad), role: selected.role, confidence: selected.confidence)
        }
    }

    private func perspectiveCrop(_ cgImage: CGImage, quad: PageQuad) throws -> CGImage {
        let source = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { throw BookPageSegmentationError.cropFailed }
        let extent = source.extent
        func point(_ value: NormalizedPoint) -> CGPoint {
            CGPoint(x: extent.minX + value.x * extent.width, y: extent.minY + value.y * extent.height)
        }
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: point(quad.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: point(quad.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: point(quad.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: point(quad.bottomLeft)), forKey: "inputBottomLeft")
        guard let output = filter.outputImage,
              let rendered = context.createCGImage(output, from: output.extent.integral) else {
            throw BookPageSegmentationError.cropFailed
        }
        return rendered
    }
}
#endif
