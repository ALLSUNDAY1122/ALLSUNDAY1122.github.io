import Foundation

@main
struct PipelineOCRBridgeFixtureTests {
    static func main() throws {
        var passed = 0
        var failed = 0

        func test(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                print("PASS \(name)")
                passed += 1
            } catch {
                print("FAIL \(name): \(error)")
                failed += 1
            }
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("scanner-parity-pipeline-ocr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        test("PageAudit repaired order drives OCRPage and BookPackage sequence") {
            let fixture = try makeAuditedFixture(root: root)
            let destination = root.appendingPathComponent("package-order", isDirectory: true)
            let result = try PipelineOCRBridge().write(
                bookID: "book-order",
                auditResult: fixture.audit.auditResult,
                lineage: fixture.audit.lineage,
                ocrPages: fixture.ocrPages.shuffled(),
                destination: destination
            )

            try require(result.artifacts.map { $0.ocrPage.pageID } == ["page-1", "page-2", "page-3", "page-4"])
            try require(result.package.manifest.pages.map(\.pageID) == ["page-1", "page-2", "page-3", "page-4"])
            try require(result.package.manifest.pages.map(\.sequence) == [1, 2, 3, 4])
        }

        test("source_time and text survive audit reorder into manifest and page text") {
            let fixture = try makeAuditedFixture(root: root)
            let destination = root.appendingPathComponent("package-lineage", isDirectory: true)
            let result = try PipelineOCRBridge().write(
                bookID: "book-lineage",
                auditResult: fixture.audit.auditResult,
                lineage: fixture.audit.lineage,
                ocrPages: fixture.ocrPages,
                destination: destination
            )

            let manifest = Dictionary(uniqueKeysWithValues: result.package.manifest.pages.map { ($0.pageID, $0) })
            try require(manifest["page-2"]?.sourceTimeMS == 3_000)
            try require(manifest["page-3"]?.sourceTimeMS == 2_000)

            let page2Text = try String(contentsOf: result.package.rootURL.appendingPathComponent("text/0002.txt"), encoding: .utf8)
            let page3Text = try String(contentsOf: result.package.rootURL.appendingPathComponent("text/0003.txt"), encoding: .utf8)
            try require(page2Text == "縦書きページ二")
            try require(page3Text == "混在ページ三")
        }

        test("audit review and OCR review both propagate into package") {
            let fixture = try makeAuditedFixture(root: root, page2StageFailure: "correction_retry_required", page4OCRNeedsReview: true)
            let destination = root.appendingPathComponent("package-review", isDirectory: true)
            let result = try PipelineOCRBridge().write(
                bookID: "book-review",
                auditResult: fixture.audit.auditResult,
                lineage: fixture.audit.lineage,
                ocrPages: fixture.ocrPages,
                destination: destination
            )

            let review = Set(result.package.reviewRequiredPageIDs)
            try require(review.contains("page-2"))
            try require(review.contains("page-4"))
            let manifest = Dictionary(uniqueKeysWithValues: result.package.manifest.pages.map { ($0.pageID, $0) })
            try require(manifest["page-2"]?.needsReview == true)
            try require(manifest["page-4"]?.needsReview == true)
        }

        test("horizontal vertical mixed layouts survive stage bridge") {
            let fixture = try makeAuditedFixture(root: root)
            let destination = root.appendingPathComponent("package-layout", isDirectory: true)
            let result = try PipelineOCRBridge().write(
                bookID: "book-layout",
                auditResult: fixture.audit.auditResult,
                lineage: fixture.audit.lineage,
                ocrPages: fixture.ocrPages,
                destination: destination
            )
            try require(result.package.manifest.pages.map(\.layout) == [.horizontal, .vertical, .mixed, .horizontal])
        }

        test("audited page missing OCR cannot be silently dropped") {
            let fixture = try makeAuditedFixture(root: root)
            let missing = fixture.ocrPages.filter { $0.pageID != "page-3" }
            do {
                _ = try PipelineOCRBridge().write(
                    bookID: "book-missing-ocr",
                    auditResult: fixture.audit.auditResult,
                    lineage: fixture.audit.lineage,
                    ocrPages: missing,
                    destination: root.appendingPathComponent("package-missing-ocr")
                )
                throw FixtureError.expectedFailure
            } catch PipelineOCRBridgeError.missingOCRPage(let pageID) {
                try require(pageID == "page-3")
            }
        }

        test("audited page missing lineage cannot be silently dropped") {
            let fixture = try makeAuditedFixture(root: root)
            let missing = fixture.audit.lineage.filter { $0.pageID != "page-2" }
            do {
                _ = try PipelineOCRBridge().write(
                    bookID: "book-missing-lineage",
                    auditResult: fixture.audit.auditResult,
                    lineage: missing,
                    ocrPages: fixture.ocrPages,
                    destination: root.appendingPathComponent("package-missing-lineage")
                )
                throw FixtureError.expectedFailure
            } catch PipelineOCRBridgeError.missingLineage(let pageID) {
                try require(pageID == "page-2")
            }
        }

        test("duplicate OCR page IDs are rejected before package write") {
            let fixture = try makeAuditedFixture(root: root)
            let duplicated = fixture.ocrPages + [fixture.ocrPages[0]]
            do {
                _ = try PipelineOCRBridge().write(
                    bookID: "book-duplicate-ocr",
                    auditResult: fixture.audit.auditResult,
                    lineage: fixture.audit.lineage,
                    ocrPages: duplicated,
                    destination: root.appendingPathComponent("package-duplicate-ocr")
                )
                throw FixtureError.expectedFailure
            } catch PipelineOCRBridgeError.duplicateOCRPageID(let pageID) {
                try require(pageID == "page-1")
            }
        }

        test("pages removed from final audit order do not re-enter package") {
            let fixture = try makeAuditedFixture(root: root)
            let reducedAudit = PageAuditResult(
                orderedPageIDs: ["page-1", "page-2", "page-4"],
                pageNumberObservations: fixture.audit.auditResult.pageNumberObservations,
                duplicateGroups: fixture.audit.auditResult.duplicateGroups,
                missingPageSuspicions: fixture.audit.auditResult.missingPageSuspicions,
                reversalEvents: fixture.audit.auditResult.reversalEvents,
                autoFixes: fixture.audit.auditResult.autoFixes,
                reviewRequired: fixture.audit.auditResult.reviewRequired
            )
            let result = try PipelineOCRBridge().write(
                bookID: "book-final-order",
                auditResult: reducedAudit,
                lineage: fixture.audit.lineage,
                ocrPages: fixture.ocrPages,
                destination: root.appendingPathComponent("package-final-order")
            )
            try require(result.package.manifest.pages.map(\.pageID) == ["page-1", "page-2", "page-4"])
            try require(!result.package.manifest.pages.map(\.pageID).contains("page-3"))
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    struct Fixture {
        let audit: PipelineBridgeResult
        let ocrPages: [OCRPage]
    }

    static func makeAuditedFixture(
        root: URL,
        page2StageFailure: String? = nil,
        page4OCRNeedsReview: Bool = false
    ) throws -> Fixture {
        let imageDir = root.appendingPathComponent("images-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)

        let page1 = try makeRecord(page: 1, time: 1_000, imageDir: imageDir)
        let page3 = try makeRecord(page: 3, time: 2_000, imageDir: imageDir)
        var page2 = try makeRecord(page: 2, time: 3_000, imageDir: imageDir)
        let page4 = try makeRecord(page: 4, time: 4_000, imageDir: imageDir)
        page2.stageFailure = page2StageFailure

        let audit = PipelineAuditBridge().audit([page1, page3, page2, page4])
        try require(audit.auditResult.orderedPageIDs == ["page-1", "page-2", "page-3", "page-4"])

        let ocrPages = [
            makeOCR(page: 1, layout: .horizontal, text: "横書きページ一"),
            makeOCR(page: 2, layout: .vertical, text: "縦書きページ二"),
            makeOCR(page: 3, layout: .mixed, text: "混在ページ三"),
            makeOCR(page: 4, layout: .horizontal, text: "横書きページ四", needsReview: page4OCRNeedsReview)
        ]
        return Fixture(audit: audit, ocrPages: ocrPages)
    }

    static func makeRecord(page: Int, time: Int64, imageDir: URL) throws -> PipelinePageRecord {
        let pageID = "page-\(page)"
        let candidateID = "candidate-\(page)"
        let imageURL = imageDir.appendingPathComponent("\(pageID).png")
        try writeTinyPNG(to: imageURL)

        return PipelinePageRecord(
            pageID: pageID,
            candidate: PageCandidate(
                candidateID: candidateID,
                bookID: "book-fixture",
                sourceTimeMS: time,
                sourceRangeMS: .init(start: time - 100, end: time + 100),
                imageRef: imageURL.path,
                stabilityScore: 0.99,
                sharpnessScore: 0.95,
                motionScore: 0.01,
                flags: ["stable"]
            ),
            correction: CorrectedPageMetadata(
                pageID: pageID,
                candidateID: candidateID,
                cropQuad: .fullFrame,
                rotationDegrees: 0,
                perspectiveApplied: true,
                dewarpApplied: false,
                colorProfile: .reading,
                qualityScores: .init(boundaryConfidence: 0.95, perspectiveSeverity: 0.04, residualSkewDegrees: 0.2),
                flags: [.perspectiveApplied]
            ),
            correctedImageRef: imageURL.path,
            auditSignals: PipelineAuditSignals(
                pageNumber: PageNumberObservation(
                    pageID: pageID,
                    value: page,
                    confidence: 0.999,
                    rawText: String(page),
                    boundingBox: .init(x: 0.85, y: 0.02, width: 0.08, height: 0.04),
                    score: 99.9
                ),
                perceptualHash: UInt64(page) << 56,
                text: "audit text page \(page)"
            )
        )
    }

    static func makeOCR(page: Int, layout: OCRLayout, text: String, needsReview: Bool = false) -> OCRPage {
        OCRPage(
            pageID: "page-\(page)",
            layout: layout,
            text: text,
            blocks: [OCRBlock(
                text: text,
                confidence: 0.96,
                boundingBox: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
                sourceIndex: 0
            )],
            ocrConfidence: 0.96,
            engine: "fixture-ocr",
            engineVersion: "1",
            needsReview: needsReview,
            sourceTimeMS: nil
        )
    }

    static func writeTinyPNG(to url: URL) throws {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        guard let data = Data(base64Encoded: base64) else { throw FixtureError.invalidFixture }
        try data.write(to: url, options: .atomic)
    }

    static func require(_ condition: @autoclosure () -> Bool) throws {
        if !condition() { throw FixtureError.assertionFailed }
    }

    enum FixtureError: Error {
        case assertionFailed
        case expectedFailure
        case invalidFixture
    }
}
