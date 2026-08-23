import Foundation

#if canImport(PDFKit)
import PDFKit

public struct DefaultPackagePDFInspector: PackagePDFInspecting {
    public init() {}

    public func pageCount(at url: URL) throws -> Int {
        guard let document = PDFDocument(url: url) else { throw PackagePDFInspectorError.unreadable }
        return document.pageCount
    }
}
#else
public struct DefaultPackagePDFInspector: PackagePDFInspecting {
    public init() {}
    public func pageCount(at url: URL) throws -> Int { throw PackagePDFInspectorError.unsupported }
}
#endif

public struct PackageIntegrityVerifier {
    public let fileManager: FileManager
    public let pdfInspector: any PackagePDFInspecting

    public init(fileManager: FileManager = .default, pdfInspector: any PackagePDFInspecting = DefaultPackagePDFInspector()) {
        self.fileManager = fileManager
        self.pdfInspector = pdfInspector
    }

    public func verify(rootURL: URL) -> PackageIntegrityReport {
        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return terminalReport(code: .manifestMissing, detail: "manifest.json が存在しません")
        }

        let manifest: PackageManifestSnapshot
        do {
            manifest = try JSONDecoder().decode(PackageManifestSnapshot.self, from: Data(contentsOf: manifestURL))
        } catch {
            return terminalReport(code: .manifestUnreadable, detail: "manifest.json をdecodeできません: \(error)")
        }

        var issues: [PackageIntegrityIssue] = []
        if manifest.pages.isEmpty {
            issues.append(.init(code: .emptyManifest, detail: "manifestにページがありません"))
        }

        for (sequence, pages) in Dictionary(grouping: manifest.pages, by: \.sequence) where pages.count > 1 {
            issues.append(.init(code: .duplicateSequence, sequence: sequence, detail: "sequence \(sequence) が \(pages.count) 件あります"))
        }
        for (pageID, pages) in Dictionary(grouping: manifest.pages, by: \.pageID) where pages.count > 1 {
            issues.append(.init(code: .duplicatePageID, pageID: pageID, detail: "page_id \(pageID) が \(pages.count) 件あります"))
        }
        for (path, pages) in Dictionary(grouping: manifest.pages, by: \.imagePath) where pages.count > 1 {
            issues.append(.init(code: .duplicateImagePath, detail: "image_path \(path) が複数ページから参照されています: \(pages.map(\.pageID))"))
        }
        for (path, pages) in Dictionary(grouping: manifest.pages, by: \.textPath) where pages.count > 1 {
            issues.append(.init(code: .duplicateTextPath, detail: "text_path \(path) が複数ページから参照されています: \(pages.map(\.pageID))"))
        }

        let sequences = manifest.pages.map(\.sequence)
        let sortedSequences = sequences.sorted()
        if sequences != sortedSequences {
            issues.append(.init(code: .manifestOrderMismatch, detail: "manifest配列順とsequence昇順が一致しません"))
        }
        if let first = sortedSequences.first {
            let expected = Array(first..<(first + sortedSequences.count))
            if sortedSequences != expected {
                issues.append(.init(code: .nonContiguousSequence, detail: "sequenceが連続していません: observed=\(sortedSequences)"))
            }
        }

        var validImageRefs = 0
        var validTextRefs = 0
        for page in manifest.pages {
            if let imageURL = safeResolvedURL(rootURL: rootURL, relativePath: page.imagePath) {
                if fileManager.fileExists(atPath: imageURL.path) {
                    validImageRefs += 1
                } else {
                    issues.append(.init(code: .missingImageFile, pageID: page.pageID, sequence: page.sequence, detail: page.imagePath))
                }
            } else {
                issues.append(.init(code: .unsafeRelativePath, pageID: page.pageID, sequence: page.sequence, detail: "unsafe image_path: \(page.imagePath)"))
            }

            if let textURL = safeResolvedURL(rootURL: rootURL, relativePath: page.textPath) {
                if fileManager.fileExists(atPath: textURL.path) {
                    do {
                        _ = try String(contentsOf: textURL, encoding: .utf8)
                        validTextRefs += 1
                    } catch {
                        issues.append(.init(code: .unreadableTextFile, pageID: page.pageID, sequence: page.sequence, detail: page.textPath))
                    }
                } else {
                    issues.append(.init(code: .missingTextFile, pageID: page.pageID, sequence: page.sequence, detail: page.textPath))
                }
            } else {
                issues.append(.init(code: .unsafeRelativePath, pageID: page.pageID, sequence: page.sequence, detail: "unsafe text_path: \(page.textPath)"))
            }
        }

        if !fileManager.fileExists(atPath: rootURL.appendingPathComponent("book.md").path) {
            issues.append(.init(code: .aggregateMarkdownMissing, detail: "book.md が存在しません"))
        }
        if !fileManager.fileExists(atPath: rootURL.appendingPathComponent("book.txt").path) {
            issues.append(.init(code: .aggregateTextMissing, detail: "book.txt が存在しません"))
        }

        let pdfURL = rootURL.appendingPathComponent("book_searchable.pdf")
        var pdfPageCount: Int?
        if fileManager.fileExists(atPath: pdfURL.path) {
            do {
                let count = try pdfInspector.pageCount(at: pdfURL)
                pdfPageCount = count
                if count != manifest.pages.count {
                    issues.append(.init(code: .pdfPageCountMismatch, detail: "PDF=\(count), manifest=\(manifest.pages.count)"))
                }
            } catch PackagePDFInspectorError.unsupported {
                issues.append(.init(code: .searchablePDFUnreadable, severity: .warning, detail: "この実行環境ではPDFページ数を検査できません"))
            } catch {
                issues.append(.init(code: .searchablePDFUnreadable, detail: "PDFを検査できません: \(error)"))
            }
        } else {
            issues.append(.init(code: .searchablePDFMissing, detail: "book_searchable.pdf が存在しません"))
        }

        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let reviewIDs = Set(manifest.pages.filter { $0.needsReview }.map(\.pageID))
            .union(issues.compactMap(\.pageID))
            .sorted()

        return .init(
            bookID: manifest.bookID,
            valid: errorCount == 0,
            summary: .init(
                manifestPageCount: manifest.pages.count,
                imageReferenceCount: validImageRefs,
                textReferenceCount: validTextRefs,
                pdfPageCount: pdfPageCount,
                errorCount: errorCount,
                warningCount: warningCount,
                reviewPageIDs: reviewIDs
            ),
            issues: issues
        )
    }

    public static func jsonData(_ report: PackageIntegrityReport, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(report)
    }

    public static func markdown(_ report: PackageIntegrityReport) -> String {
        var lines = [
            "# BookPackage Integrity Report",
            "",
            "- book_id: `\(report.bookID ?? "unknown")`",
            "- valid: **\(report.valid)**",
            "- manifest_pages: \(report.summary.manifestPageCount)",
            "- image_refs_ok: \(report.summary.imageReferenceCount)",
            "- text_refs_ok: \(report.summary.textReferenceCount)",
            "- pdf_pages: \(report.summary.pdfPageCount.map(String.init) ?? "not_observed")",
            "- errors: \(report.summary.errorCount)",
            "- warnings: \(report.summary.warningCount)",
            ""
        ]
        if report.issues.isEmpty {
            lines.append("No integrity issues detected.")
        } else {
            lines.append("## Issues")
            for issue in report.issues {
                let page = issue.pageID.map { " page=\($0)" } ?? ""
                let sequence = issue.sequence.map { " sequence=\($0)" } ?? ""
                lines.append("- [\(issue.severity.rawValue)] `\(issue.code.rawValue)`\(page)\(sequence): \(issue.detail)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func safeResolvedURL(rootURL: URL, relativePath: String) -> URL? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { return nil }
        let root = rootURL.standardizedFileURL.path
        let resolved = rootURL.appendingPathComponent(relativePath).standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard resolved.hasPrefix(prefix) else { return nil }
        return URL(fileURLWithPath: resolved)
    }

    private func terminalReport(code: PackageIntegrityIssueCode, detail: String) -> PackageIntegrityReport {
        .init(
            bookID: nil,
            valid: false,
            summary: .init(manifestPageCount: 0, imageReferenceCount: 0, textReferenceCount: 0, pdfPageCount: nil, errorCount: 1, warningCount: 0, reviewPageIDs: []),
            issues: [.init(code: code, detail: detail)]
        )
    }
}
