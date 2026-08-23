import Foundation

public struct BookPackageResult: Sendable, Equatable {
    public let rootURL: URL
    public let searchablePDFURL: URL?
    public let reviewRequiredPageIDs: [String]
    public let manifest: BookManifest
}

public enum BookPackageWriterError: Error, LocalizedError {
    case duplicateSequence(Int)
    case emptyBook

    public var errorDescription: String? {
        switch self {
        case .duplicateSequence(let sequence): return "Duplicate page sequence: \(sequence)"
        case .emptyBook: return "Cannot create an empty book package."
        }
    }
}

public final class BookPackageWriter: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func write(bookID: String, pages: [OCRPageArtifact], destination: URL) throws -> BookPackageResult {
        guard !pages.isEmpty else { throw BookPackageWriterError.emptyBook }
        let ordered = pages.sorted { $0.sequence < $1.sequence }
        let unique = Set(ordered.map(\.sequence))
        if unique.count != ordered.count {
            let duplicate = Dictionary(grouping: ordered.map(\.sequence), by: { $0 }).first { $0.value.count > 1 }!.key
            throw BookPackageWriterError.duplicateSequence(duplicate)
        }

        let root = destination.appendingPathComponent(bookID, isDirectory: true)
        let pagesDir = root.appendingPathComponent("pages", isDirectory: true)
        let textDir = root.appendingPathComponent("text", isDirectory: true)
        try fileManager.createDirectory(at: pagesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: textDir, withIntermediateDirectories: true)

        var manifestPages: [BookManifest.Page] = []
        var markdown: [String] = ["# Book \(bookID)"]
        var plainText: [String] = []

        for artifact in ordered {
            let stem = String(format: "%04d", artifact.sequence)
            let imageName = "\(stem).jpg"
            let textName = "\(stem).txt"
            let imageDestination = pagesDir.appendingPathComponent(imageName)
            let textDestination = textDir.appendingPathComponent(textName)

            if fileManager.fileExists(atPath: imageDestination.path) {
                try fileManager.removeItem(at: imageDestination)
            }
            try PageImageWriter.writeJPEG(sourceURL: artifact.imageURL, destinationURL: imageDestination)
            if let textData = artifact.ocrPage.text.data(using: .utf8) {
                try textData.write(to: textDestination, options: .atomic)
            }

            markdown.append("\n## Page \(artifact.sequence)\n\n\(artifact.ocrPage.text)")
            plainText.append("=== PAGE \(artifact.sequence) ===\n\(artifact.ocrPage.text)")
            manifestPages.append(.init(
                sequence: artifact.sequence,
                pageID: artifact.ocrPage.pageID,
                imagePath: "pages/\(imageName)",
                textPath: "text/\(textName)",
                sourceTimeMS: artifact.ocrPage.sourceTimeMS,
                ocrConfidence: artifact.ocrPage.ocrConfidence,
                needsReview: artifact.ocrPage.needsReview,
                engine: artifact.ocrPage.engine,
                layout: artifact.ocrPage.layout
            ))
        }

        if let markdownData = markdown.joined(separator: "\n").data(using: .utf8) {
            try markdownData.write(to: root.appendingPathComponent("book.md"), options: .atomic)
        }
        if let textData = plainText.joined(separator: "\n\n").data(using: .utf8) {
            try textData.write(to: root.appendingPathComponent("book.txt"), options: .atomic)
        }

        let formatter = ISO8601DateFormatter()
        let manifest = BookManifest(schemaVersion: 1, bookID: bookID, createdAt: formatter.string(from: Date()), pages: manifestPages)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        let pdfURL = try SearchablePDFWriter.writeIfSupported(pages: ordered, outputURL: root.appendingPathComponent("book_searchable.pdf"))
        return BookPackageResult(
            rootURL: root,
            searchablePDFURL: pdfURL,
            reviewRequiredPageIDs: ordered.filter { $0.ocrPage.needsReview }.map { $0.ocrPage.pageID },
            manifest: manifest
        )
    }
}
