import Foundation
import Testing
@testable import OCRExport

@Test func horizontalReadingOrderIsTopToBottomThenLeftToRight() {
    let blocks = [
        OCRBlock(text: "B", confidence: 0.9, boundingBox: .init(x: 0.6, y: 0.8, width: 0.2, height: 0.05), sourceIndex: 0),
        OCRBlock(text: "C", confidence: 0.9, boundingBox: .init(x: 0.1, y: 0.6, width: 0.2, height: 0.05), sourceIndex: 1),
        OCRBlock(text: "A", confidence: 0.9, boundingBox: .init(x: 0.1, y: 0.8, width: 0.2, height: 0.05), sourceIndex: 2)
    ]
    #expect(OCRReadingOrder.ordered(blocks, layout: .horizontal).map(\.text) == ["A", "B", "C"])
}

@Test func verticalReadingOrderIsRightToLeftThenTopToBottom() {
    let blocks = [
        OCRBlock(text: "左上", confidence: 0.9, boundingBox: .init(x: 0.2, y: 0.8, width: 0.04, height: 0.15), sourceIndex: 0),
        OCRBlock(text: "右下", confidence: 0.9, boundingBox: .init(x: 0.8, y: 0.4, width: 0.04, height: 0.15), sourceIndex: 1),
        OCRBlock(text: "右上", confidence: 0.9, boundingBox: .init(x: 0.8, y: 0.8, width: 0.04, height: 0.15), sourceIndex: 2)
    ]
    #expect(OCRReadingOrder.ordered(blocks, layout: .vertical).map(\.text) == ["右上", "右下", "左上"])
}

@Test func qualityFlagsGarbageAndKeepsJapaneseParagraph() {
    let goodBlocks = [
        OCRBlock(text: "生命保険契約の仕組みを説明します。", confidence: 0.93, boundingBox: .init(x: 0.1, y: 0.8, width: 0.8, height: 0.06), sourceIndex: 0),
        OCRBlock(text: "保険料と保障内容を確認してください。", confidence: 0.91, boundingBox: .init(x: 0.1, y: 0.7, width: 0.8, height: 0.06), sourceIndex: 1)
    ]
    let good = OCRQualityScorer.evaluate(text: goodBlocks.map(\.text).joined(separator: "\n"), blocks: goodBlocks, layout: .horizontal)
    #expect(good.score > 0.62)
    #expect(!good.needsReview)

    let badBlocks = [OCRBlock(text: "|_<>\\", confidence: 0.22, boundingBox: .init(x: 0.1, y: 0.1, width: 0.1, height: 0.02), sourceIndex: 0)]
    let bad = OCRQualityScorer.evaluate(text: badBlocks[0].text, blocks: badBlocks, layout: .unknown)
    #expect(bad.needsReview)
    #expect(bad.score < good.score)
}

@Test func tesseractTSVParserProducesNormalizedBlocks() {
    let tsv = "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n5\t1\t1\t1\t1\t1\t10\t20\t100\t30\t95\t日本語\n5\t1\t1\t1\t1\t2\t120\t20\t80\t30\t88\tOCR"
    let blocks = TesseractTSVParser().parse(tsv)
    #expect(blocks.count == 2)
    #expect(blocks[0].confidence == 0.95)
    #expect(blocks.allSatisfy { $0.boundingBox.x >= 0 && $0.boundingBox.x <= 1 && $0.boundingBox.y >= 0 && $0.boundingBox.y <= 1 })
}

@Test func bookPackagePreservesSequenceAndReviewFlags() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let imageA = temp.appendingPathComponent("a.jpg")
    let imageB = temp.appendingPathComponent("b.jpg")
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: imageA)
    try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: imageB)

    let p1 = OCRPage(pageID: "p1", layout: .horizontal, text: "一ページ目", blocks: [], ocrConfidence: 0.9, engine: "fixture", engineVersion: "1", needsReview: false, sourceTimeMS: 1000)
    let p2 = OCRPage(pageID: "p2", layout: .vertical, text: "二ページ目", blocks: [], ocrConfidence: 0.5, engine: "fixture", engineVersion: "1", needsReview: true, sourceTimeMS: 2000)
    let result = try BookPackageWriter().write(
        bookID: "book-1",
        pages: [OCRPageArtifact(sequence: 2, imageURL: imageB, ocrPage: p2), OCRPageArtifact(sequence: 1, imageURL: imageA, ocrPage: p1)],
        destination: temp
    )

    #expect(result.manifest.pages.map(\.pageID) == ["p1", "p2"])
    #expect(result.reviewRequiredPageIDs == ["p2"])
    #expect(FileManager.default.fileExists(atPath: result.rootURL.appendingPathComponent("text/0001.txt").path))
    #expect(FileManager.default.fileExists(atPath: result.rootURL.appendingPathComponent("book.md").path))
    #expect(FileManager.default.fileExists(atPath: result.rootURL.appendingPathComponent("manifest.json").path))
}
