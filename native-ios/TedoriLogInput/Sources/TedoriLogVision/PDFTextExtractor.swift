#if canImport(PDFKit)
import Foundation
import PDFKit
import TedoriLogCore

/// PDFの埋め込みテキストを位置つきトークンとして取り出す（第一経路）。
/// テキストを持たないPDF（スキャン）はここでは何も返さず、呼び出し側がOCRへ切り替える。
public enum PDFTextExtractor {

    /// これ未満なら「テキストを持たないPDF」とみなす
    public static let minimumTokens = 8

    public struct Extraction {
        public var tokens: [TextToken]
        public var pageCount: Int
        public var pageSizes: [CGSize]
        public var hasText: Bool { tokens.count >= minimumTokens }
    }

    public static func extract(url: URL) -> Extraction? {
        guard let document = PDFDocument(url: url) else { return nil }
        return extract(document: document)
    }

    public static func extract(document: PDFDocument) -> Extraction {
        var tokens: [TextToken] = []
        var sizes: [CGSize] = []
        var yOffset = 0.0

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            sizes.append(bounds.size)
            guard let text = page.string, !text.isEmpty else {
                yOffset += bounds.height
                continue
            }
            // 空白・改行で区切った語ごとに位置を取る
            var index = 0
            let characters = Array(text)
            while index < characters.count {
                if characters[index].isWhitespace { index += 1; continue }
                var end = index
                while end < characters.count && !characters[end].isWhitespace { end += 1 }
                let range = NSRange(location: index, length: end - index)
                if let selection = page.selection(for: range) {
                    let rect = selection.bounds(for: page)
                    let word = String(characters[index..<end])
                    if !rect.isNull, rect.width > 0 || rect.height > 0 {
                        tokens.append(TextToken(
                            text: word,
                            x: Double(rect.minX),
                            // PDFは左下原点なので左上原点へ変換し、ページを縦に積む
                            y: Double(bounds.height - rect.maxY) + yOffset,
                            w: Double(rect.width),
                            h: Double(rect.height),
                            conf: 1,
                            page: pageIndex + 1))
                    }
                }
                index = end
            }
            yOffset += bounds.height
        }
        return Extraction(tokens: tokens, pageCount: document.pageCount, pageSizes: sizes)
    }
}
#endif
