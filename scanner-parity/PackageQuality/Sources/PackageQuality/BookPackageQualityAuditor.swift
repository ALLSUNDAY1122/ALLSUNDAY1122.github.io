import Foundation
import PackageValidation

#if canImport(PDFKit)
import PDFKit

public struct DefaultPDFTextLayerInspector: PDFTextLayerInspecting {
    public init() {}

    public func pageTexts(at url: URL) throws -> [String] {
        guard let document = PDFDocument(url: url) else { throw PDFTextLayerInspectorError.unreadable }
        return (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
    }
}
#else
public struct DefaultPDFTextLayerInspector: PDFTextLayerInspecting {
    public init() {}
    public func pageTexts(at url: URL) throws -> [String] { throw PDFTextLayerInspectorError.unsupported }
}
#endif

private struct CachedPDFCountInspector: PackagePDFInspecting {
    let result: Result<[String], Error>
    func pageCount(at url: URL) throws -> Int { try result.get().count }
}

public struct BookPackageQualityAuditor: Sendable {
    public let fileManager: FileManager
    public let pdfTextInspector: any PDFTextLayerInspecting

    public init(fileManager: FileManager = .default, pdfTextInspector: any PDFTextLayerInspecting = DefaultPDFTextLayerInspector()) {
        self.fileManager = fileManager
        self.pdfTextInspector = pdfTextInspector
    }

    public func audit(rootURL: URL, ocrPages: [PackageOCRQualityPage]) -> PackageQualityReport {
        let pdfURL = rootURL.appendingPathComponent("book_searchable.pdf")
        let pdfTextResult: Result<[String], Error> = Result { try pdfTextInspector.pageTexts(at: pdfURL) }
        let integrity = PackageIntegrityVerifier(fileManager: fileManager, pdfInspector: CachedPDFCountInspector(result: pdfTextResult)).verify(rootURL: rootURL)

        var issues: [PackageQualityIssue] = []
        if !integrity.valid {
            issues.append(.init(code: .integrityFailure, detail: "BookPackage Integrity Verifier が error を検出: \(integrity.summary.errorCount)"))
        }

        let manifest: PackageManifestSnapshot?
        do {
            manifest = try JSONDecoder().decode(PackageManifestSnapshot.self, from: Data(contentsOf: rootURL.appendingPathComponent("manifest.json")))
        } catch {
            manifest = nil
        }

        guard let manifest else {
            return .init(
                bookID: integrity.bookID,
                valid: false,
                metrics: .init(pdfTextLayerCoverage: nil, pdfTextOrderAccuracy: nil, markdownBoundaryAccuracy: 0, textBoundaryAccuracy: 0, ocrReviewedOrAcceptedRatio: 0, lineageCoverage: 0),
                issues: issues + [.init(code: .integrityFailure, detail: "manifestを品質監査へ読み込めません")],
                ingestionRecords: []
            )
        }

        if manifest.schemaVersion != 1 {
            issues.append(.init(code: .manifestSchemaUnsupported, detail: "schema_version=\(manifest.schemaVersion) は未対応"))
        }

        let expectedSequences = manifest.pages.map(\.sequence)
        let markdownSequences = parseMarkdownSequences(rootURL.appendingPathComponent("book.md"))
        let textSequences = parseTextSequences(rootURL.appendingPathComponent("book.txt"))
        let markdownAccuracy = positionalAccuracy(expected: expectedSequences, observed: markdownSequences)
        let textAccuracy = positionalAccuracy(expected: expectedSequences, observed: textSequences)
        if markdownAccuracy < 1 {
            issues.append(.init(code: .markdownBoundaryMismatch, detail: "expected=\(expectedSequences), observed=\(markdownSequences)"))
        }
        if textAccuracy < 1 {
            issues.append(.init(code: .textBoundaryMismatch, detail: "expected=\(expectedSequences), observed=\(textSequences)"))
        }

        var pdfCoverage: Double?
        var pdfOrderAccuracy: Double?
        switch pdfTextResult {
        case .success(let pdfTexts):
            let expectedTexts = manifest.pages.map { page -> String in
                guard let url = safeResolvedURL(rootURL: rootURL, relativePath: page.textPath),
                      let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
                return text
            }
            if expectedTexts.isEmpty {
                pdfCoverage = 1
                pdfOrderAccuracy = 1
            } else {
                let nonEmpty = pdfTexts.prefix(expectedTexts.count).filter { !normalize($0).isEmpty }.count
                pdfCoverage = Double(nonEmpty) / Double(expectedTexts.count)
                var orderedMatches = 0
                for index in expectedTexts.indices where index < pdfTexts.count {
                    if textSimilarity(expectedTexts[index], pdfTexts[index]) >= 0.55 { orderedMatches += 1 }
                }
                pdfOrderAccuracy = Double(orderedMatches) / Double(expectedTexts.count)
            }
            if (pdfCoverage ?? 0) < 1 {
                issues.append(.init(code: .pdfTextLayerMissing, detail: "PDF text-layer coverage=\(pdfCoverage ?? 0)"))
            }
            if (pdfOrderAccuracy ?? 0) < 1 {
                issues.append(.init(code: .pdfTextOrderMismatch, detail: "PDF text order accuracy=\(pdfOrderAccuracy ?? 0)"))
            }
        case .failure(let error):
            let severity: PackageQualitySeverity = error is PDFTextLayerInspectorError ? .warning : .error
            issues.append(.init(code: .pdfTextLayerUnavailable, severity: severity, detail: "PDF text-layerを検査できません: \(error)"))
        }

        let pagesByID = Dictionary(uniqueKeysWithValues: ocrPages.map { ($0.pageID, $0) })
        var reviewedOrAccepted = 0
        for page in ocrPages {
            let lowQuality = normalize(page.text).count < 8 || page.confidence < 0.55
            let unknownLayout = page.layout == .unknown
            if lowQuality || unknownLayout {
                if page.needsReview {
                    reviewedOrAccepted += 1
                    issues.append(.init(code: .ocrReviewRequired, severity: .warning, pageID: page.pageID, sequence: page.sequence, detail: "低品質/未知layoutはreviewへ保持済み"))
                } else {
                    if lowQuality {
                        issues.append(.init(code: .ocrLowQualityUnreviewed, pageID: page.pageID, sequence: page.sequence, detail: "confidence=\(page.confidence), length=\(normalize(page.text).count)"))
                    }
                    if unknownLayout {
                        issues.append(.init(code: .ocrUnknownLayoutUnreviewed, pageID: page.pageID, sequence: page.sequence, detail: "layout=unknown だがneeds_review=false"))
                    }
                }
            } else {
                reviewedOrAccepted += 1
            }
        }
        let ocrRatio = ocrPages.isEmpty ? 1 : Double(reviewedOrAccepted) / Double(ocrPages.count)

        var ingestion: [AIIngestionRecord] = []
        var lineageCount = 0
        for page in manifest.pages {
            if let time = page.sourceTimeMS {
                lineageCount += 1
                ingestion.append(.init(sequence: page.sequence, pageID: page.pageID, imagePath: page.imagePath, textPath: page.textPath, sourceTimeMS: time, needsReview: page.needsReview || (pagesByID[page.pageID]?.needsReview ?? false)))
            } else {
                issues.append(.init(code: .manifestLineageMissing, pageID: page.pageID, sequence: page.sequence, detail: "source_time_ms がありません"))
            }
        }
        let lineageCoverage = manifest.pages.isEmpty ? 1 : Double(lineageCount) / Double(manifest.pages.count)

        let errorCount = issues.filter { $0.severity == .error }.count
        return .init(
            bookID: manifest.bookID,
            valid: errorCount == 0,
            metrics: .init(
                pdfTextLayerCoverage: pdfCoverage,
                pdfTextOrderAccuracy: pdfOrderAccuracy,
                markdownBoundaryAccuracy: markdownAccuracy,
                textBoundaryAccuracy: textAccuracy,
                ocrReviewedOrAcceptedRatio: ocrRatio,
                lineageCoverage: lineageCoverage
            ),
            issues: issues,
            ingestionRecords: ingestion.sorted { $0.sequence < $1.sequence }
        )
    }

    public static func jsonData(_ report: PackageQualityReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    public static func markdown(_ report: PackageQualityReport) -> String {
        var lines = [
            "# Package Quality Report",
            "",
            "- book_id: `\(report.bookID ?? "unknown")`",
            "- valid: **\(report.valid)**",
            "- pdf_text_layer_coverage: \(format(report.metrics.pdfTextLayerCoverage))",
            "- pdf_text_order_accuracy: \(format(report.metrics.pdfTextOrderAccuracy))",
            "- markdown_boundary_accuracy: \(String(format: "%.4f", report.metrics.markdownBoundaryAccuracy))",
            "- text_boundary_accuracy: \(String(format: "%.4f", report.metrics.textBoundaryAccuracy))",
            "- ocr_reviewed_or_accepted_ratio: \(String(format: "%.4f", report.metrics.ocrReviewedOrAcceptedRatio))",
            "- lineage_coverage: \(String(format: "%.4f", report.metrics.lineageCoverage))",
            ""
        ]
        if report.issues.isEmpty { lines.append("No quality issues detected.") }
        else {
            lines.append("## Issues")
            for issue in report.issues {
                let page = issue.pageID.map { " page=\($0)" } ?? ""
                lines.append("- [\(issue.severity.rawValue)] `\(issue.code.rawValue)`\(page): \(issue.detail)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func parseMarkdownSequences(_ url: URL) -> [Int] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let prefix = "## Page "
            guard line.hasPrefix(prefix) else { return nil }
            return Int(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
        }
    }

    private func parseTextSequences(_ url: URL) -> [Int] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let prefix = "=== PAGE "
            guard line.hasPrefix(prefix), line.hasSuffix(" ===") else { return nil }
            return Int(line.dropFirst(prefix.count).dropLast(4).trimmingCharacters(in: .whitespaces))
        }
    }

    private func positionalAccuracy(expected: [Int], observed: [Int]) -> Double {
        guard !expected.isEmpty else { return observed.isEmpty ? 1 : 0 }
        let matches = expected.indices.filter { $0 < observed.count && expected[$0] == observed[$0] }.count
        return Double(matches) / Double(expected.count)
    }

    private func safeResolvedURL(rootURL: URL, relativePath: String) -> URL? {
        guard !relativePath.hasPrefix("/") else { return nil }
        let root = rootURL.standardizedFileURL.path
        let resolved = rootURL.appendingPathComponent(relativePath).standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return resolved.hasPrefix(prefix) ? URL(fileURLWithPath: resolved) : nil
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private func textSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let a = shingles(normalize(lhs))
        let b = shingles(normalize(rhs))
        guard !a.isEmpty, !b.isEmpty else { return a == b ? 1 : 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private func shingles(_ text: String) -> Set<String> {
        let chars = Array(text)
        guard chars.count >= 3 else { return text.isEmpty ? [] : [text] }
        return Set((0...(chars.count - 3)).map { String(chars[$0...($0 + 2)]) })
    }

    private static func format(_ value: Double?) -> String {
        value.map { String(format: "%.4f", $0) } ?? "not_observed"
    }
}
