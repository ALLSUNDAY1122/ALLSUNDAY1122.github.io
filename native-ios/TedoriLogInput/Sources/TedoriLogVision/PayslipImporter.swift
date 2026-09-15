#if canImport(Vision) && canImport(PDFKit)
import Foundation
import CoreImage
import PDFKit
import Vision
import TedoriLogCore

/// 入力（PDF・画像）から解析結果までをまとめる層。
///
/// 経路の優先順位:
///   1. PDFの埋め込みテキスト（最も正確・速い）
///   2. 端末内Apple VisionによるOCR
/// OCRの二重実行は常時行わず、1回目の結果が怪しいときだけ条件を変えて再実行する。
public enum PayslipImporter {

    public struct ImportResult {
        public var result: PayslipResult
        public var route: Route
        public var pageImages: [CGImage]
        public var ocrPasses: Int
        public var quality: CaptureQuality.Assessment?
        public var elapsedMs: Double
    }

    public enum Route: String {
        case pdfText = "pdf_text"
        case ocr
        case pdfFallbackOcr = "pdf_fallback_ocr"
    }

    /// 1回目の読み取りがこの自己評価を下回ったら条件を変えて再OCRする
    public static let reOcrThreshold = 8.0
    /// 平均読み取り信頼度がこれ未満でも再OCRする
    public static let reOcrConfidence = 0.55

    // MARK: - PDF

    public static func importPDF(url: URL) throws -> ImportResult {
        let started = Date()
        guard let document = PDFDocument(url: url) else {
            return ImportResult(result: emptyResult(route: .pdfText, message: "PDFを開けませんでした"),
                                route: .pdfText, pageImages: [], ocrPasses: 0, quality: nil,
                                elapsedMs: Date().timeIntervalSince(started) * 1000)
        }
        let extraction = PDFTextExtractor.extract(document: document)
        if extraction.hasText {
            let result = PayslipExtractor.extract(tokens: extraction.tokens, route: Route.pdfText.rawValue)
            return ImportResult(result: result, route: .pdfText, pageImages: renderPages(document),
                                ocrPasses: 0, quality: nil,
                                elapsedMs: Date().timeIntervalSince(started) * 1000)
        }
        // テキストを持たないPDF（スキャン）はOCRへ切り替える
        let images = renderPages(document)
        var imported = try importImages(images, route: .pdfFallbackOcr)
        imported.elapsedMs = Date().timeIntervalSince(started) * 1000
        return imported
    }

    // MARK: - 画像

    public static func importImage(_ image: CGImage) throws -> ImportResult {
        try importImages([image], route: .ocr)
    }

    public static func importImages(_ images: [CGImage], route: Route = .ocr) throws -> ImportResult {
        let started = Date()
        guard !images.isEmpty else {
            return ImportResult(result: emptyResult(route: route, message: "画像がありません"),
                                route: route, pageImages: [], ocrPasses: 0, quality: nil, elapsedMs: 0)
        }
        let quality = CaptureQuality.assess(images[0])

        // 1回目: そのまま読む
        var passes = 1
        var firstTokens: [TextToken] = []
        var meanConfidence = 0.0
        var offset = 0.0
        for (index, image) in images.enumerated() {
            let reading = try VisionTextRecognizer.recognize(cgImage: image, pageOffsetY: offset, page: index + 1)
            firstTokens.append(contentsOf: reading.tokens)
            meanConfidence += reading.meanConfidence
            offset += 842 // ページを縦に積む（A4ポイント相当）
        }
        meanConfidence /= Double(images.count)

        let first = PayslipExtractor.extract(tokens: firstTokens, route: Route.ocr.rawValue)
        let firstScore = PayslipExtractor.selfAssessment(first)

        // 2回目は「怪しいときだけ」。常時2回走らせない（処理時間と電力のため）
        var variants = [PayslipExtractor.Variant(name: "vision", tokens: firstTokens)]
        if firstScore < reOcrThreshold || meanConfidence < reOcrConfidence {
            passes = 2
            var enhancedTokens: [TextToken] = []
            var enhancedOffset = 0.0
            for (index, image) in images.enumerated() {
                let enhanced = ImagePreprocessor.enhanceForOCR(image) ?? image
                let reading = try VisionTextRecognizer.recognize(cgImage: enhanced,
                                                                pageOffsetY: enhancedOffset, page: index + 1)
                enhancedTokens.append(contentsOf: reading.tokens)
                enhancedOffset += 842
            }
            variants.append(PayslipExtractor.Variant(name: "vision_enhanced", tokens: enhancedTokens))
        }

        let result = variants.count == 1
            ? { var r = first; r.variant = "vision"; return r }()
            : PayslipExtractor.extractBest(variants: variants, route: Route.ocr.rawValue)

        return ImportResult(result: result, route: route, pageImages: images, ocrPasses: passes,
                            quality: quality, elapsedMs: Date().timeIntervalSince(started) * 1000)
    }

    // MARK: - 補助

    static func renderPages(_ document: PDFDocument, scale: CGFloat = 2.0) -> [CGImage] {
        var images: [CGImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            guard width > 0, height > 0,
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            if let image = context.makeImage() { images.append(image) }
        }
        return images
    }

    private static func emptyResult(route: Route, message: String) -> PayslipResult {
        var result = PayslipExtractor.extract(tokens: [], route: route.rawValue)
        result.message = message
        return result
    }
}
#endif
