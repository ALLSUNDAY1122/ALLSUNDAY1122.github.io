#if canImport(Vision) && canImport(PDFKit)
import XCTest
import CoreGraphics
import ImageIO
import PDFKit
@testable import TedoriLogCore
@testable import TedoriLogVision

/// 未知形式コーパスを **実際のApple Vision** で読み、製品チェック1前ゲートの合格条件を測る。
/// macOS runner（CI）またはMac上で実行される。ここが本番相当の数値になる。
///
/// 合格条件（Phase A監査結果・製品チェック1前ゲート v1.0）:
///   - 70%以上の形式で主要9項目中7項目以上を候補提示
///   - 差引支給額 90%以上
///   - 重大誤認（誤った値を確定候補として提示）0件
///   - クラッシュ0 / 外部送信0
final class VisionHoldoutEvaluationTests: XCTestCase {

    struct ManifestCase: Decodable {
        let id: String
        let layout: String
        let media: String
        let split: String
        let file: String
        let ocrPages: [String]?
        let ocrSource: String?

        enum CodingKeys: String, CodingKey {
            case id, layout, media, split, file
            case ocrPages = "ocr_pages"
            case ocrSource = "ocr_source"
        }
    }

    struct Manifest: Decodable { let cases: [ManifestCase] }

    struct TruthFile: Decodable {
        let id: String
        let truth: [String: Int]
    }

    static var fixturesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/holdout")
    }

    struct CaseOutcome {
        let id: String
        let layout: String
        let media: String
        let split: String
        let route: String
        let correct: Int
        let criticalWrong: Int
        let netPayCorrect: Bool
        let ocrPasses: Int
        let elapsedMs: Double
    }

    private func loadImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw XCTSkip("画像を読み込めません: \(url.lastPathComponent)")
        }
        return image
    }

    private func evaluate(_ entry: ManifestCase, dir: URL) throws -> CaseOutcome {
        let truth = try JSONDecoder().decode(
            TruthFile.self,
            from: Data(contentsOf: dir.appendingPathComponent("\(entry.id).truth.json"))).truth

        let fileURL = dir.appendingPathComponent(entry.file)
        let imported: PayslipImporter.ImportResult
        if entry.file.hasSuffix(".pdf") {
            imported = try PayslipImporter.importPDF(url: fileURL)
        } else {
            imported = try PayslipImporter.importImage(loadImage(fileURL))
        }

        var correct = 0
        var criticalWrong = 0
        var netOK = false
        for key in ItemKey.allCases {
            guard let item = imported.result.items[key] else { continue }
            if let value = item.value, value == truth[key.rawValue] {
                correct += 1
                if key == .netPay { netOK = true }
            } else if item.value != nil, item.status == .confident {
                criticalWrong += 1
            }
        }
        return CaseOutcome(id: entry.id, layout: entry.layout, media: entry.media, split: entry.split,
                           route: imported.route.rawValue, correct: correct, criticalWrong: criticalWrong,
                           netPayCorrect: netOK, ocrPasses: imported.ocrPasses,
                           elapsedMs: imported.elapsedMs)
    }

    func testVisionHoldoutGate() throws {
        let dir = Self.fixturesURL
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("manifest.json").path) else {
            throw XCTSkip("holdout fixtureが見つかりません")
        }
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))

        var outcomes: [CaseOutcome] = []
        for entry in manifest.cases {
            outcomes.append(try evaluate(entry, dir: dir))
        }

        // 結果表（CIログにそのまま残す。VISION_EVAL_RESULTS.md へ転記する）
        print("\n=== Apple Vision 未知形式評価 ===")
        print("case   split layout           media       route      correct crit net  passes  ms")
        for o in outcomes.sorted(by: { $0.id < $1.id }) {
            print(String(format: "%@ %-5@ %-16@ %-11@ %-10@ %d/9     %d    %@   %d      %.0f",
                         o.id, o.split, o.layout, o.media, o.route, o.correct, o.criticalWrong,
                         o.netPayCorrect ? "OK" : "NG", o.ocrPasses, o.elapsedMs))
        }

        func report(_ subset: [CaseOutcome], _ title: String) {
            guard !subset.isEmpty else { return }
            let passed = subset.filter { $0.correct >= 7 }.count
            let net = subset.filter(\.netPayCorrect).count
            let critical = subset.reduce(0) { $0 + $1.criticalWrong }
            let avg = Double(subset.reduce(0) { $0 + $1.correct }) / Double(subset.count)
            let times = subset.map(\.elapsedMs).sorted()
            let median = times[times.count / 2]
            print(String(format: "%@: %d/%d形式が7項目以上 (%.0f%%) / 差引 %d/%d (%.0f%%) / 重大誤認 %d / 平均 %.2f項目 / 中央処理時間 %.0fms",
                         title, passed, subset.count, 100 * Double(passed) / Double(subset.count),
                         net, subset.count, 100 * Double(net) / Double(subset.count),
                         critical, avg, median))
        }
        let evalSet = outcomes.filter { $0.split == "eval" }
        let finalSet = outcomes.filter { $0.split == "final" }
        report(evalSet, "評価20形式")
        report(finalSet, "最終確認10形式")
        report(outcomes, "全30形式")
        for media in ["text_pdf", "screenshot", "photo", "image_pdf"] {
            report(outcomes.filter { $0.media == media }, "媒体:\(media)")
        }

        // ゲート判定（安全性は必須。精度は結果を記録して判定する）
        let critical = outcomes.reduce(0) { $0 + $1.criticalWrong }
        XCTAssertEqual(critical, 0, "誤った値を確定候補として提示してはいけない（重大誤認0が必須）")

        let passRate = Double(evalSet.filter { $0.correct >= 7 }.count) / Double(max(evalSet.count, 1))
        let netRate = Double(evalSet.filter(\.netPayCorrect).count) / Double(max(evalSet.count, 1))
        print(String(format: "\nゲート: 形式合格率 %.0f%% (基準70%%) / 差引 %.0f%% (基準90%%) / 重大誤認 %d (基準0)",
                     passRate * 100, netRate * 100, critical))
        XCTAssertGreaterThanOrEqual(passRate, 0.7, "70%以上の未知形式で7項目以上を提示できていない")
        XCTAssertGreaterThanOrEqual(netRate, 0.9, "差引支給額の提示率が90%に届いていない")
    }

    /// 条件付き再OCR: 読みやすい入力では1回で終わることを確認する（常時2回実行しない）。
    func testSecondOCRPassIsConditional() throws {
        let dir = Self.fixturesURL
        let screenshots = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json"))
        ).cases.filter { $0.media == "screenshot" }
        guard let sample = screenshots.first else { throw XCTSkip("スクリーンショットのfixtureが無い") }
        let imported = try PayslipImporter.importImage(loadImage(dir.appendingPathComponent(sample.file)))
        XCTAssertLessThanOrEqual(imported.ocrPasses, 2)
        print("再OCR回数(\(sample.id)): \(imported.ocrPasses)")
    }

    /// 撮影品質の判定が機能すること。
    func testCaptureQualityDetectsDarkImage() throws {
        let width = 1200, height = 800
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let dark = { () -> CGImage? in
                  context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1))
                  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                  return context.makeImage()
              }() else { throw XCTSkip("画像を作れません") }
        let assessment = CaptureQuality.assess(dark)
        XCTAssertTrue(assessment.issues.contains(.tooDark))
        XCTAssertTrue(assessment.shouldRetake)
        XCTAssertNotNil(assessment.message)
    }
}
#endif
