import XCTest
@testable import TedoriLogCore

/// 金額正規化・辞書・候補選択・検算・保存ガードの単体テスト。
/// PoC(JS)側の test/ と同じ観点をSwiftへ移植している。
final class CoreTests: XCTestCase {

    // MARK: - 金額正規化

    func testParseAmountCommonForms() {
        XCTAssertEqual(Normalize.parseAmount("1,234")?.value, 1234)
        XCTAssertEqual(Normalize.parseAmount("¥1,234")?.value, 1234)
        XCTAssertEqual(Normalize.parseAmount("１２３，４５６")?.value, 123456)
        XCTAssertEqual(Normalize.parseAmount("1 234")?.value, 1234)
        XCTAssertEqual(Normalize.parseAmount("1234円")?.value, 1234)
        XCTAssertEqual(Normalize.parseAmount("419000")?.value, 419000)
    }

    func testParseAmountNegativeForms() {
        XCTAssertEqual(Normalize.parseAmount("-1,234")?.value, -1234)
        XCTAssertEqual(Normalize.parseAmount("△1,234")?.value, -1234)
        XCTAssertEqual(Normalize.parseAmount("▲1,234")?.value, -1234)
        XCTAssertEqual(Normalize.parseAmount("(1,234)")?.value, -1234)
        XCTAssertEqual(Normalize.parseAmount("(¥19,220)")?.value, -19220)
        XCTAssertEqual(Normalize.parseAmount("A18,900")?.value, -18900, "△をAと誤読しても符号として扱う")
    }

    func testParseAmountOCRNoise() {
        XCTAssertEqual(Normalize.parseAmount("13,7 00")?.value, 13700)
        XCTAssertEqual(Normalize.parseAmount("67.736")?.value, 67736, "カンマを点と誤読しても桁区切りとして扱う")
        XCTAssertEqual(Normalize.parseAmount("1,234.00")?.value, 1234)
        let noisy = Normalize.parseAmount("12,3,45")
        XCTAssertEqual(noisy?.value, 12345)
        XCTAssertLessThan(noisy?.confidence ?? 1, 1)
    }

    func testParseAmountRejectsNonAmounts() {
        for text in ["2026年3月", "2026-03", "2026/03/25", "8:30", "20.5時間", "15%", "基本給", "", "---"] {
            XCTAssertNil(Normalize.parseAmount(text), "\(text) は金額として扱ってはいけない")
        }
    }

    // MARK: - 辞書

    func testLexiconKnownWording() {
        let expectations: [(String, ItemKey)] = [
            ("基本給", .basicPay), ("本給", .basicPay), ("月例給", .basicPay), ("基準内給与", .basicPay),
            ("時間外手当", .overtime), ("法定内残業", .overtime), ("超勤手当", .overtime),
            ("休日割増賃金", .overtime), ("所定外賃金", .overtime), ("深夜勤務手当", .overtime),
            ("通勤手当", .otherAllowance), ("在宅勤務手当", .otherAllowance), ("食事補助", .otherAllowance),
            ("単身赴任手当", .otherAllowance), ("特殊作業手当", .otherAllowance),
            ("健康保険料等", .healthInsurance), ("健保", .healthInsurance),
            ("厚生年金保険", .pension), ("厚年", .pension),
            ("雇用保険料等", .employmentInsurance), ("雇保", .employmentInsurance),
            ("源泉税", .incomeTax), ("所得税", .incomeTax),
            ("市町村民税", .residentTax), ("地方税", .residentTax),
            ("お振込金額", .netPay), ("差引合計", .netPay), ("手取額", .netPay),
        ]
        for (text, key) in expectations {
            XCTAssertEqual(Lexicon.matchItem(text)?.key, key, "\(text) の判定")
        }
    }

    func testLexiconDoesNotConfuseTotalsWithNetPay() {
        XCTAssertNotEqual(Lexicon.matchItem("総支給額")?.key, .netPay)
        XCTAssertEqual(Lexicon.matchTotal("総支給額")?.kind, .gross)
        XCTAssertEqual(Lexicon.matchTotal("支給額計")?.kind, .gross)
        XCTAssertEqual(Lexicon.matchTotal("控除額計")?.kind, .deduction)
        XCTAssertNil(Lexicon.matchTotal("差引支給額"), "差引支給額は合計行ではない")
    }

    func testLexiconRejectsAttendanceRows() {
        for text in ["時間外時間", "深夜時間", "出勤日数", "総労働時間"] {
            let match = Lexicon.matchItem(text)
            XCTAssertTrue(match == nil || match?.key == .otherAllowance && match?.loose == true,
                          "\(text) を金額項目として拾ってはいけない: \(String(describing: match?.key))")
        }
    }

    func testOtherDeductionDetection() {
        XCTAssertTrue(Lexicon.isOtherDeduction("介護保険料"))
        XCTAssertTrue(Lexicon.isOtherDeduction("財形貯蓄"))
        XCTAssertFalse(Lexicon.isOtherDeduction("健康保険料"))
        XCTAssertNotEqual(Lexicon.matchItem("介護保険料")?.key, .healthInsurance)
    }

    // MARK: - 抽出

    private func token(_ text: String, _ x: Double, _ y: Double, w: Double? = nil, conf: Double = 1) -> TextToken {
        TextToken(text: text, x: x, y: y, w: w ?? Double(text.count) * 6, h: 10, conf: conf)
    }

    private func simpleSlip(basic: String = "250,000") -> [TextToken] {
        let rows: [(String, String)] = [
            ("基本給", basic), ("残業手当", "30,000"), ("通勤手当", "10,000"), ("支給合計", "290,000"),
            ("健康保険料", "14,000"), ("厚生年金保険料", "26,000"), ("雇用保険料", "1,740"),
            ("所得税", "5,000"), ("住民税", "12,000"), ("控除合計", "58,740"), ("差引支給額", "231,260"),
        ]
        var tokens: [TextToken] = []
        for (index, row) in rows.enumerated() {
            let y = 100 + Double(index) * 20
            tokens.append(token(row.0, 50, y))
            tokens.append(token(row.1, 300, y, w: 50))
        }
        return tokens
    }

    func testExtractSameRowAssignment() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(), route: "pdf_text")
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.items[.basicPay]?.value, 250000)
        XCTAssertEqual(result.items[.overtime]?.value, 30000)
        XCTAssertEqual(result.items[.otherAllowance]?.value, 10000)
        XCTAssertEqual(result.items[.netPay]?.value, 231260)
        XCTAssertEqual(result.items[.netPay]?.status, .confident)
    }

    func testExtractAggregatesMultipleRows() {
        var tokens: [TextToken] = []
        let rows: [(String, String)] = [
            ("基本給", "250,000"), ("時間外手当", "20,000"), ("深夜手当", "5,000"),
            ("通勤手当", "8,000"), ("住宅手当", "12,000"),
        ]
        for (index, row) in rows.enumerated() {
            tokens.append(token(row.0, 50, 100 + Double(index) * 20))
            tokens.append(token(row.1, 300, 100 + Double(index) * 20, w: 50))
        }
        let result = PayslipExtractor.extract(tokens: tokens, route: "pdf_text")
        XCTAssertEqual(result.items[.overtime]?.value, 25000)
        XCTAssertEqual(result.items[.otherAllowance]?.value, 20000)
    }

    func testColumnHeaderLayout() {
        // ラベル行の真下に金額行がある形式（幅の違うラベルでも順序で対応付ける）
        let labels = ["健康保険料等", "厚生年金保険", "雇用保険", "財形貯蓄"]
        let amounts = ["13,660", "25,730", "1,740", "2,800"]
        var tokens: [TextToken] = []
        for (index, label) in labels.enumerated() {
            tokens.append(token(label, 60 + Double(index) * 125, 100))
        }
        for (index, amount) in amounts.enumerated() {
            tokens.append(token(amount, 133 + Double(index) * 125, 130, w: 35))
        }
        let result = PayslipExtractor.extract(tokens: tokens, route: "pdf_text")
        XCTAssertEqual(result.items[.healthInsurance]?.value, 13660)
        XCTAssertEqual(result.items[.pension]?.value, 25730)
        XCTAssertEqual(result.items[.employmentInsurance]?.value, 1740)
    }

    func testReconciliationDowngradesMismatch() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(basic: "260,000"), route: "pdf_text")
        let payCheck = result.checks.first { $0.id == "pay_total" }
        XCTAssertEqual(payCheck?.ok, false)
        XCTAssertEqual(result.items[.basicPay]?.status, .needsReview)
    }

    func testDerivesNetPayWhenMissing() {
        let tokens = simpleSlip().filter { $0.text != "差引支給額" && $0.text != "231,260" }
        let result = PayslipExtractor.extract(tokens: tokens, route: "pdf_text")
        XCTAssertEqual(result.items[.netPay]?.value, 231260)
        XCTAssertEqual(result.items[.netPay]?.status, .needsReview)
        XCTAssertEqual(result.items[.netPay]?.derived, true)
    }

    func testOCRRouteNeedsCorroboration() {
        let tokens = [token("基本給", 50, 100), token("250,000", 300, 100, w: 50, conf: 0.95),
                      token("健康保険料", 50, 120), token("14,000", 300, 120, w: 50, conf: 0.95)]
        let result = PayslipExtractor.extract(tokens: tokens, route: "ocr")
        XCTAssertEqual(result.items[.basicPay]?.value, 250000)
        XCTAssertEqual(result.items[.basicPay]?.status, .needsReview, "裏付けが無ければ確定候補にしない")
    }

    func testDigitRepairMarksCorrectedAsNeedsReview() {
        let tokens = simpleSlip(basic: "250,900").map { t -> TextToken in
            var copy = t
            copy.conf = t.text == "250,900" ? 0.4 : 0.95
            return copy
        }
        let result = PayslipExtractor.extract(tokens: tokens, route: "ocr")
        XCTAssertEqual(result.items[.basicPay]?.value, 250000, "合計と整合する値へ補正する")
        XCTAssertEqual(result.items[.basicPay]?.status, .needsReview)
        XCTAssertEqual(result.items[.basicPay]?.corrected, true)
        XCTAssertTrue(result.items[.basicPay]?.alternatives.contains { $0.value == 250900 } ?? false)
    }

    func testPDFRouteDoesNotRepairDigits() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(basic: "250,900"), route: "pdf_text")
        XCTAssertEqual(result.items[.basicPay]?.value, 250900)
        XCTAssertEqual(result.items[.basicPay]?.corrected, false)
    }

    func testVariantDisagreementBlocksConfident() {
        let good = simpleSlip()
        let bad = simpleSlip(basic: "250,900")
        let result = PayslipExtractor.extractBest(
            variants: [.init(name: "a", tokens: good), .init(name: "b", tokens: bad)], route: "ocr")
        XCTAssertNotEqual(result.items[.basicPay]?.status, .confident,
                          "読み取り条件によって値が違う項目は確定候補にしない")
    }

    func testSkewedPaperIsGroupedIntoRows() {
        let slope = 0.045
        let tokens = simpleSlip().map { t -> TextToken in
            var copy = t
            copy.y = t.y + slope * t.x
            return copy
        }
        let result = PayslipExtractor.extract(tokens: tokens, route: "ocr")
        XCTAssertEqual(result.items[.basicPay]?.value, 250000)
        XCTAssertEqual(result.items[.netPay]?.value, 231260)
        XCTAssertEqual(result.skewSlope, slope, accuracy: 0.01)
    }

    func testEmptyAndInvalidInput() {
        let empty = PayslipExtractor.extract(tokens: [], route: "pdf_text")
        XCTAssertFalse(empty.ok)
        XCTAssertEqual(empty.error, "no_text_detected")
        XCTAssertEqual(empty.items[.basicPay]?.status, .notFound)

        let noise = PayslipExtractor.extract(
            tokens: [token("◆◆◆", 10, 10), token("■", 20, 30)], route: "ocr")
        XCTAssertTrue(noise.ok)
        XCTAssertEqual(noise.notFoundCount, 9)
    }

    // MARK: - 保存ガード

    func testSaveGuardBlocksUnconfirmed() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(), route: "pdf_text")
        let draft = SaveGuard.buildDraft(result: result, confirmations: [:])
        XCTAssertFalse(draft.ok, "確認していない候補があるまま保存できてはいけない")
        XCTAssertNil(draft.payload)
    }

    func testSaveGuardAllowsConfirmed() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(), route: "pdf_text")
        var confirmations: [ItemKey: SaveGuard.Confirmation] = [:]
        for key in ItemKey.allCases {
            confirmations[key] = .init(value: result.items[key]?.value, confirmed: true)
        }
        let draft = SaveGuard.buildDraft(result: result, confirmations: confirmations)
        XCTAssertTrue(draft.ok)
        XCTAssertEqual(draft.payload?.items.first { $0.key == .basicPay }?.value, 250000)
        XCTAssertEqual(draft.payload?.items.first { $0.key == .basicPay }?.source, .userConfirmed)
    }

    func testSaveGuardRecordsEdits() {
        let result = PayslipExtractor.extract(tokens: simpleSlip(), route: "pdf_text")
        var confirmations: [ItemKey: SaveGuard.Confirmation] = [:]
        for key in ItemKey.allCases {
            confirmations[key] = .init(value: result.items[key]?.value, confirmed: true)
        }
        confirmations[.incomeTax] = .init(value: 5100, confirmed: true)
        let draft = SaveGuard.buildDraft(result: result, confirmations: confirmations)
        XCTAssertTrue(draft.ok)
        let item = draft.payload?.items.first { $0.key == .incomeTax }
        XCTAssertEqual(item?.value, 5100)
        XCTAssertEqual(item?.source, .userEdited)
        XCTAssertEqual(item?.suggested, 5000)
    }

    func testSavedPayloadHasNoRawText() throws {
        let result = PayslipExtractor.extract(tokens: simpleSlip(), route: "pdf_text")
        var confirmations: [ItemKey: SaveGuard.Confirmation] = [:]
        for key in ItemKey.allCases {
            confirmations[key] = .init(value: result.items[key]?.value, confirmed: true)
        }
        let draft = SaveGuard.buildDraft(result: result, confirmations: confirmations)
        let data = try JSONEncoder().encode(draft.payload)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("tokens"), "トークン列を保存しない")
        XCTAssertFalse(json.lowercased().contains("base64"), "画像を保存しない")
    }
}
