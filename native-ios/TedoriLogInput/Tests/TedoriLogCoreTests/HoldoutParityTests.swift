import XCTest
@testable import TedoriLogCore

/// 未知形式コーパスのトークンを使い、Swift版がJS版(PoC)と同じ判断をするかを確認する。
/// 移植のズレを検出するための回帰テスト。fixtureはリポジトリ内の Fixtures/holdout を直接読む。
final class HoldoutParityTests: XCTestCase {

    struct TokenFile: Decodable {
        struct Variant: Decodable {
            let name: String
            let tokens: [TextToken]
        }
        let route: String
        let variants: [Variant]
    }

    struct GoldenItem: Decodable {
        let value: Int?
        let status: String
    }

    struct GoldenCase: Decodable {
        let variant: String
        let items: [String: GoldenItem]
    }

    struct ManifestCase: Decodable {
        let id: String
        let split: String
    }

    struct Manifest: Decodable {
        let cases: [ManifestCase]
    }

    static var fixturesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TedoriLogCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Fixtures/holdout")
    }

    func testMatchesJavaScriptEngineOnHoldoutTokens() throws {
        let dir = Self.fixturesURL
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))
        let golden = try JSONDecoder().decode(
            [String: GoldenCase].self, from: Data(contentsOf: dir.appendingPathComponent("golden_js.json")))

        var mismatches: [String] = []
        for entry in manifest.cases {
            let tokenFile = try JSONDecoder().decode(
                TokenFile.self, from: Data(contentsOf: dir.appendingPathComponent("\(entry.id).tokens.json")))
            let variants = tokenFile.variants.map {
                PayslipExtractor.Variant(name: $0.name, tokens: $0.tokens)
            }
            let result = PayslipExtractor.extractBest(variants: variants, route: tokenFile.route)
            guard let expected = golden[entry.id] else { continue }

            for key in ItemKey.allCases {
                let got = result.items[key]?.value
                let want = expected.items[key.rawValue]?.value
                if got != want {
                    mismatches.append("\(entry.id) \(key.rawValue): swift=\(String(describing: got)) js=\(String(describing: want))")
                }
            }
        }
        XCTAssertTrue(mismatches.isEmpty,
                      "JS版と判断が食い違う項目があります:\n" + mismatches.joined(separator: "\n"))
    }

    /// 未知形式トークンでの合格条件（OCRの読み取り自体はJS側と同じTesseract出力を使う）。
    func testHoldoutGateOnStoredTokens() throws {
        let dir = Self.fixturesURL
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))

        var passed = 0
        var total = 0
        var criticalWrong = 0
        for entry in manifest.cases where entry.split == "eval" {
            let tokenFile = try JSONDecoder().decode(
                TokenFile.self, from: Data(contentsOf: dir.appendingPathComponent("\(entry.id).tokens.json")))
            let truth = try JSONDecoder().decode(
                [String: [String: Int]].self,
                from: Data(contentsOf: dir.appendingPathComponent("\(entry.id).truth.json"))
            )["truth"] ?? [:]
            let result = PayslipExtractor.extractBest(
                variants: tokenFile.variants.map { .init(name: $0.name, tokens: $0.tokens) },
                route: tokenFile.route)

            var correct = 0
            for key in ItemKey.allCases {
                guard let item = result.items[key] else { continue }
                if let value = item.value, value == truth[key.rawValue] {
                    correct += 1
                } else if item.value != nil, item.status == .confident {
                    criticalWrong += 1
                }
            }
            total += 1
            if correct >= 7 { passed += 1 }
        }
        // 安全性（誤った値を確定候補にしない）は入力品質に関わらず守る
        XCTAssertEqual(criticalWrong, 0, "誤った値を確定候補として提示してはいけない")
        XCTAssertGreaterThan(total, 0)
        print("holdout(stored tokens): \(passed)/\(total) formats >= 7/9 items")
    }
}
