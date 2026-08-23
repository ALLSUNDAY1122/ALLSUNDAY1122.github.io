import Foundation

public struct TesseractTSVParser {
    public init() {}

    public func parse(_ tsv: String) -> [OCRBlock] {
        let rows = tsv.split(whereSeparator: \.isNewline)
        guard rows.count > 1 else { return [] }
        var parsed: [(text: String, confidence: Double, left: Double, top: Double, width: Double, height: Double, index: Int)] = []
        var maxX = 1.0
        var maxY = 1.0

        for (index, row) in rows.dropFirst().enumerated() {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 12,
                  let confidence = Double(columns[10]), confidence >= 0,
                  let left = Double(columns[6]), let top = Double(columns[7]),
                  let width = Double(columns[8]), let height = Double(columns[9]) else { continue }
            let text = columns[11].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            maxX = max(maxX, left + width)
            maxY = max(maxY, top + height)
            parsed.append((text, confidence / 100.0, left, top, width, height, index))
        }

        return parsed.map { item in
            let x = item.left / maxX
            let yFromTop = item.top / maxY
            let h = item.height / maxY
            return OCRBlock(
                text: item.text,
                confidence: min(1, max(0, item.confidence)),
                boundingBox: OCRRect(
                    x: x,
                    y: max(0, 1 - yFromTop - h),
                    width: item.width / maxX,
                    height: h
                ),
                sourceIndex: item.index
            )
        }
    }
}

public struct OCREngineComparison: Sendable, Equatable {
    public let appleVisionScore: Double?
    public let tesseractJPNScore: Double?
    public let tesseractJPNVertScore: Double?
    public let recommendedEngine: String

    public init(appleVisionScore: Double?, tesseractJPNScore: Double?, tesseractJPNVertScore: Double?) {
        self.appleVisionScore = appleVisionScore
        self.tesseractJPNScore = tesseractJPNScore
        self.tesseractJPNVertScore = tesseractJPNVertScore
        let candidates = [
            ("apple-vision", appleVisionScore),
            ("tesseract-jpn", tesseractJPNScore),
            ("tesseract-jpn_vert", tesseractJPNVertScore)
        ].compactMap { name, score in score.map { (name, $0) } }
        self.recommendedEngine = candidates.max(by: { $0.1 < $1.1 })?.0 ?? "unavailable"
    }
}

#if os(macOS) || os(Linux)
public final class TesseractCLIRunner: @unchecked Sendable {
    public let executableURL: URL

    public init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/tesseract")) {
        self.executableURL = executableURL
    }

    public func recognize(imageURL: URL, language: String) throws -> OCRPage {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [imageURL.path, "stdout", "-l", language, "--psm", "3", "tsv"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "TesseractCLIRunner", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "tesseract failed"])
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let tsv = String(data: data, encoding: .utf8) ?? ""
        let raw = TesseractTSVParser().parse(tsv)
        let layout = OCRQualityScorer.inferLayout(from: raw)
        let ordered = OCRReadingOrder.ordered(raw, layout: layout)
        let text = ordered.map(\.text).joined(separator: "\n")
        let quality = OCRQualityScorer.evaluate(text: text, blocks: ordered, layout: layout)
        return OCRPage(
            pageID: imageURL.deletingPathExtension().lastPathComponent,
            layout: layout,
            text: text,
            blocks: ordered,
            ocrConfidence: quality.score,
            engine: "tesseract-\(language)",
            engineVersion: "cli",
            needsReview: quality.needsReview
        )
    }
}
#endif
