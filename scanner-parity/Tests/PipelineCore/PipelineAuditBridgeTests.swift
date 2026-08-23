import Foundation

@main
struct PipelineAuditBridgeFixtureTests {
    static func main() {
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

        test("lineage preserves candidate/source time/flags") {
            let record = makeRecord(page: 1, time: 1_000, sourceFlags: ["stable", "fixture"])
            let bridge = PipelineAuditBridge()
            let lineage = bridge.makeLineage(from: record)
            try require(lineage.candidateID == "candidate-1")
            try require(lineage.pageID == "page-1")
            try require(lineage.sourceTimeMS == 1_000)
            try require(lineage.sourceRangeMS == SourceRangeMS(start: 900, end: 1_100))
            try require(lineage.sourceFlags == ["stable", "fixture"])
            try require(lineage.correctionFlags.contains(CorrectionFlag.perspectiveApplied.rawValue))
        }

        test("normal ordering survives stage bridge") {
            let result = PipelineAuditBridge().audit([
                makeRecord(page: 1, time: 1_000),
                makeRecord(page: 2, time: 2_000),
                makeRecord(page: 3, time: 3_000)
            ])
            try require(result.auditResult.orderedPageIDs == ["page-1", "page-2", "page-3"])
            try require(result.auditResult.missingPageSuspicions.isEmpty)
        }

        test("duplicate is detected across stages") {
            let first = makeRecord(page: 2, time: 2_000, hash: 0xAAAA_AAAA_AAAA_AAAA, text: "同じ本文を持つページです")
            var duplicate = makeRecord(page: 2, time: 2_500, hash: 0xAAAA_AAAA_AAAA_AAAA, text: "同じ本文を持つページです")
            duplicate.pageID = "page-2-duplicate"
            duplicate.candidate = PageCandidate(
                candidateID: "candidate-2-duplicate",
                bookID: "book-fixture",
                sourceTimeMS: 2_500,
                sourceRangeMS: .init(start: 2_400, end: 2_600),
                imageRef: "source://2-duplicate",
                stabilityScore: 0.99,
                sharpnessScore: 0.95,
                motionScore: 0.01,
                flags: ["stable"]
            )
            duplicate.correction = makeCorrection(pageID: "page-2-duplicate", candidateID: "candidate-2-duplicate")
            duplicate.auditSignals.pageNumber = number(pageID: "page-2-duplicate", value: 2)

            let result = PipelineAuditBridge().audit([first, duplicate])
            try require(!result.auditResult.duplicateGroups.isEmpty)
        }

        test("missing page is detected across stages") {
            let result = PipelineAuditBridge().audit([
                makeRecord(page: 1, time: 1_000),
                makeRecord(page: 3, time: 3_000)
            ])
            try require(result.auditResult.missingPageSuspicions.contains { $0.expectedPageNumbers == [2] })
        }

        test("adjacent reversal is detected and high-confidence repair stays auditable") {
            let result = PipelineAuditBridge().audit([
                makeRecord(page: 1, time: 1_000),
                makeRecord(page: 3, time: 2_000),
                makeRecord(page: 2, time: 3_000),
                makeRecord(page: 4, time: 4_000)
            ])
            try require(!result.auditResult.reversalEvents.isEmpty)
            try require(result.auditResult.autoFixes.contains { $0.kind == .swapAdjacentPages })
            try require(result.auditResult.orderedPageIDs == ["page-1", "page-2", "page-3", "page-4"])
        }

        test("stage failure is not dropped and enters review_required") {
            var failedPage = makeRecord(page: 5, time: 5_000)
            failedPage.correction = nil
            failedPage.correctedImageRef = nil
            failedPage.stageFailure = "correction_engine_failed"

            let result = PipelineAuditBridge().audit([failedPage])
            try require(result.auditResult.orderedPageIDs == ["page-5"])
            try require(result.lineage.first?.stageFailure == "correction_engine_failed")
            try require(result.auditResult.reviewRequired.contains { $0.detail.contains("stage_failure") })
        }

        test("low correction confidence propagates to review_required") {
            var low = makeRecord(page: 6, time: 6_000)
            low.correction = makeCorrection(
                pageID: "page-6",
                candidateID: "candidate-6",
                boundaryConfidence: 0.40,
                flags: [.lowBoundaryConfidence]
            )
            let result = PipelineAuditBridge().audit([low])
            try require(result.auditResult.reviewRequired.contains { $0.detail.contains("low_confidence") })
        }

        test("contract mismatch cannot silently cross the bridge") {
            var mismatched = makeRecord(page: 7, time: 7_000)
            mismatched.correction = makeCorrection(pageID: "wrong-page", candidateID: "wrong-candidate")
            let result = PipelineAuditBridge().audit([mismatched])
            try require(result.auditResult.reviewRequired.contains { $0.detail.contains("contract_mismatch") })
        }

        test("mismatched page-number evidence is quarantined before audit") {
            var mismatched = makeRecord(page: 8, time: 8_000)
            mismatched.auditSignals.pageNumber = number(pageID: "page-99", value: 99)
            let bridge = PipelineAuditBridge()
            let input = bridge.makeAuditInput(from: mismatched)
            try require(input.pageNumber == nil)

            let result = bridge.audit([mismatched])
            try require(result.auditResult.pageNumberObservations.isEmpty)
            try require(result.auditResult.orderedPageIDs == ["page-8"])
            try require(result.auditResult.reviewRequired.contains {
                $0.detail.contains("page_number.page_id")
            })
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    static func makeRecord(
        page: Int,
        time: Int64,
        sourceFlags: [String] = ["stable"],
        hash: UInt64? = nil,
        text: String? = nil
    ) -> PipelinePageRecord {
        let pageID = "page-\(page)"
        let candidateID = "candidate-\(page)"
        return PipelinePageRecord(
            pageID: pageID,
            candidate: PageCandidate(
                candidateID: candidateID,
                bookID: "book-fixture",
                sourceTimeMS: time,
                sourceRangeMS: .init(start: time - 100, end: time + 100),
                imageRef: "source://\(page)",
                stabilityScore: 0.99,
                sharpnessScore: 0.95,
                motionScore: 0.01,
                flags: sourceFlags
            ),
            correction: makeCorrection(pageID: pageID, candidateID: candidateID),
            correctedImageRef: "corrected://\(page)",
            auditSignals: PipelineAuditSignals(
                pageNumber: number(pageID: pageID, value: page),
                perceptualHash: hash ?? UInt64(page) << 56,
                text: text ?? "fixture page \(page) unique body text"
            )
        )
    }

    static func makeCorrection(
        pageID: String,
        candidateID: String,
        boundaryConfidence: Double = 0.95,
        flags: [CorrectionFlag] = [.perspectiveApplied]
    ) -> CorrectedPageMetadata {
        CorrectedPageMetadata(
            pageID: pageID,
            candidateID: candidateID,
            cropQuad: .fullFrame,
            rotationDegrees: 0,
            perspectiveApplied: flags.contains(.perspectiveApplied),
            dewarpApplied: false,
            colorProfile: .reading,
            qualityScores: .init(
                boundaryConfidence: boundaryConfidence,
                perspectiveSeverity: 0.05,
                residualSkewDegrees: 0.2
            ),
            flags: flags
        )
    }

    static func number(pageID: String, value: Int) -> PageNumberObservation {
        PageNumberObservation(
            pageID: pageID,
            value: value,
            confidence: 0.999,
            rawText: String(value),
            boundingBox: .init(x: 0.85, y: 0.02, width: 0.08, height: 0.04),
            score: 99.9
        )
    }

    static func require(_ condition: @autoclosure () -> Bool) throws {
        if !condition() { throw FixtureError.assertionFailed }
    }

    enum FixtureError: Error { case assertionFailed }
}
