import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
import ProductFlow
import RuntimeComposition
import ScannerRuntime
import UniformTypeIdentifiers

struct LongRunOptions {
    let workspaceURL: URL
    let pageCount: Int
}

struct ProductionLongRunReport: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let inputPageCount: Int
    let completedPageCount: Int
    let reviewCount: Int
    let checkpointStageCount: Int
    let searchablePDFPageCount: Int
    let requiredBookPackageFilesPresent: Bool
    let packageIntegrityValid: Bool
    let elapsedMilliseconds: Int
    let verdict: String
}

actor LongRunCheckpointBox {
    private var checkpoint: ProductPipelineCheckpoint?
    func set(_ value: ProductPipelineCheckpoint) { checkpoint = value }
    func value() -> ProductPipelineCheckpoint? { checkpoint }
}

@main
enum HQProductionLongRun {
    static func main() async throws {
        let options = try parseArguments(CommandLine.arguments)
        guard options.pageCount >= 200 else {
            throw NSError(domain: "HQProductionLongRun", code: 2, userInfo: [NSLocalizedDescriptionKey: "--pages must be at least 200"])
        }

        try resetDirectory(options.workspaceURL)
        let inputDirectory = options.workspaceURL.appendingPathComponent("00-input-pages", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDirectory, withIntermediateDirectories: true)

        var inputs: [ProductInputAsset] = []
        inputs.reserveCapacity(options.pageCount)
        for index in 1...options.pageCount {
            let pageURL = inputDirectory.appendingPathComponent(String(format: "%04d.jpg", index))
            try writeSyntheticPage(index: index, total: options.pageCount, to: pageURL)
            inputs.append(ProductInputAsset(
                id: String(format: "longrun-image-%04d", index),
                kind: .image,
                localURL: pageURL,
                displayName: pageURL.lastPathComponent
            ))
        }

        let request = ProductPipelineRequest(
            bookID: "production-longrun-\(options.pageCount)",
            inputs: inputs,
            workspaceURL: options.workspaceURL
        )
        let driver = ProductionScannerRuntime.makeDriver()
        let checkpointBox = LongRunCheckpointBox()
        let started = DispatchTime.now().uptimeNanoseconds
        let completion = try await driver.run(
            request: request,
            resume: nil,
            progress: { progress in
                if progress.completedUnits == 1 || progress.completedUnits == progress.totalUnits || progress.completedUnits % 40 == 0 {
                    let line = "[ProductionLongRun] \(progress.stage.rawValue) \(progress.completedUnits)/\(progress.totalUnits.map(String.init) ?? "?")\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            },
            checkpoint: { checkpoint in
                await checkpointBox.set(checkpoint)
            }
        )
        let elapsed = Int((DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        let checkpoint = await checkpointBox.value()

        let requiredFiles = ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json", "integrity-report.json"]
        let packageComplete = requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: completion.bookPackageURL.appendingPathComponent($0).path)
        }
        let integrity: PackageIntegrityReport = try decodeJSON(
            completion.bookPackageURL.appendingPathComponent("integrity-report.json")
        )
        guard let searchablePDF = PDFDocument(url: completion.bookPackageURL.appendingPathComponent("book_searchable.pdf")) else {
            throw NSError(domain: "HQProductionLongRun", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unreadable searchable PDF"])
        }

        let pass = completion.pageCount == options.pageCount
            && searchablePDF.pageCount == options.pageCount
            && packageComplete
            && integrity.valid
            && (checkpoint?.completedArtifacts.count ?? 0) >= 5

        let report = ProductionLongRunReport(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            inputPageCount: options.pageCount,
            completedPageCount: completion.pageCount,
            reviewCount: completion.reviewItems.count,
            checkpointStageCount: checkpoint?.completedArtifacts.count ?? 0,
            searchablePDFPageCount: searchablePDF.pageCount,
            requiredBookPackageFilesPresent: packageComplete,
            packageIntegrityValid: integrity.valid,
            elapsedMilliseconds: elapsed,
            verdict: pass ? "PRODUCTION_LONG_RUN_PASS" : "PRODUCTION_LONG_RUN_FAIL"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: options.workspaceURL.appendingPathComponent("production-longrun-report.json"), options: .atomic)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))

        guard pass else {
            throw NSError(domain: "HQProductionLongRun", code: 4, userInfo: [NSLocalizedDescriptionKey: "240-page production long-run gate failed"])
        }
    }

    static func parseArguments(_ arguments: [String]) throws -> LongRunOptions {
        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            guard arguments[index].hasPrefix("--"), index + 1 < arguments.count else {
                throw NSError(domain: "HQProductionLongRun", code: 2, userInfo: [NSLocalizedDescriptionKey: usage])
            }
            values[arguments[index]] = arguments[index + 1]
            index += 2
        }
        guard let workspace = values["--workspace"] else {
            throw NSError(domain: "HQProductionLongRun", code: 2, userInfo: [NSLocalizedDescriptionKey: usage])
        }
        let pages = Int(values["--pages"] ?? "240") ?? 240
        return .init(workspaceURL: URL(fileURLWithPath: workspace, isDirectory: true), pageCount: pages)
    }

    static var usage: String {
        "Usage: scanner-production-longrun --workspace <dir> [--pages 240]"
    }

    static func writeSyntheticPage(index: Int, total: Int, to url: URL) throws {
        let width = 420
        let height = 560
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "HQProductionLongRun", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot create synthetic page context"])
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(CGColor(gray: 0.05, alpha: 1))
        context.setLineWidth(5)
        context.stroke(CGRect(x: 18, y: 18, width: width - 36, height: height - 36))

        // Deterministic high-contrast page fingerprint so PageAudit does not
        // collapse the 240 synthetic pages as perceptual duplicates.
        for bit in 0..<8 {
            if ((index >> bit) & 1) == 1 {
                let x = 32 + bit * 42
                context.setFillColor(CGColor(gray: 0.15 + CGFloat(bit) * 0.07, alpha: 1))
                context.fill(CGRect(x: x, y: height - 82, width: 24, height: 32 + bit * 3))
            }
        }

        drawText("SCANNER PARITY LONG RUN", size: 22, x: 40, y: 470, context: context)
        drawText(String(format: "PAGE %03d / %03d", index, total), size: 30, x: 40, y: 410, context: context)
        drawText("Synthetic production-path verification page", size: 15, x: 40, y: 360, context: context)
        drawText(String(format: "Unique sequence token LR-%03d-%04X", index, index * 7919), size: 15, x: 40, y: 330, context: context)
        for row in 0..<7 {
            drawText(String(format: "Line %02d page %03d integrity OCR audit package", row + 1, index), size: 13, x: 40, y: 285 - row * 30, context: context)
        }

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "HQProductionLongRun", code: 6, userInfo: [NSLocalizedDescriptionKey: "Cannot create synthetic JPEG"])
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "HQProductionLongRun", code: 7, userInfo: [NSLocalizedDescriptionKey: "Cannot finalize synthetic JPEG"])
        }
    }

    static func drawText(_ text: String, size: CGFloat, x: Int, y: Int, context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.05, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    static func decodeJSON<T: Decodable>(_ url: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    static func resetDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
