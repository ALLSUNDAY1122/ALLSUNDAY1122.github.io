import Foundation

@main
struct PrivacyStaticAuditorFixtureTests {
    static func main() throws {
        var passed = 0
        var failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 }
            catch { print("FAIL \(name): \(error)"); failed += 1 }
        }

        test("URLSession is egress risk") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": "let s = URLSession.shared"])
            try require(r.productionEgressRisks.contains { $0.category == .network })
            try require(!r.releaseBlockingFindings.isEmpty)
        }
        test("OpenAI endpoint is external AI egress risk") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": #"let u = "https://api.openai.com/v1/chat/completions""#])
            try require(r.productionEgressRisks.contains { $0.category == .externalAI })
        }
        test("analytics SDK is egress risk") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": "import FirebaseAnalytics"])
            try require(r.productionEgressRisks.contains { $0.category == .analytics })
        }
        test("Application Support alone is not automatically a blocker") {
            let r = PrivacyStaticAuditor().audit(files: ["/AppShell/Store.swift": "FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)"])
            try require(r.releaseBlockingFindings.isEmpty)
        }
        test("Apple Vision is local informational finding") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": "import Vision"])
            try require(r.findings.contains { $0.category == .appleLocalFramework && $0.risk == .info })
            try require(r.releaseBlockingFindings.isEmpty)
        }
        test("Tesseract Process is local CLI review not blocker") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": """
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/tesseract")
                """])
            try require(r.findings.contains { $0.category == .localCLI })
            try require(r.releaseBlockingFindings.isEmpty)
        }
        test("network CLI inside Process is egress risk") {
            let r = PrivacyStaticAuditor().audit(files: ["/Sources/A.swift": """
                let p = Process()
                p.arguments = ["curl ", "https://api.example.invalid"]
                """])
            try require(r.productionEgressRisks.contains { $0.ruleID == "network-cli" })
        }
        test("custom denylist catches future SDK") {
            let r = PrivacyStaticAuditor(extraDenylist: ["FutureCloudOCR"]).audit(files: ["/Sources/A.swift": "FutureCloudOCR.upload(page)"])
            try require(r.productionEgressRisks.contains { $0.ruleID == "custom-denylist" })
        }
        test("allowlist may suppress approved local CLI review") {
            let r = PrivacyStaticAuditor(extraAllowlist: ["xcrun"]).audit(files: ["/Scripts/build.sh": "xcrun swiftc main.swift"])
            try require(!r.findings.contains { $0.token.lowercased() == "xcrun" })
        }
        test("allowlist cannot suppress egress deny rules") {
            let r = PrivacyStaticAuditor(extraAllowlist: ["URLSession"]).audit(files: ["/Sources/A.swift": "URLSession.shared"])
            try require(r.productionEgressRisks.contains { $0.ruleID == "network-api" })
        }
        test("all test paths are excluded from production scan") {
            let r = PrivacyStaticAuditor().audit(files: ["/Tests/OtherModule/Fixture.swift": "URLSession.shared"])
            try require(r.scannedFiles == 0)
            try require(r.releaseBlockingFindings.isEmpty)
        }
        test("remote package is review not blocker by itself") {
            let r = PrivacyStaticAuditor().audit(files: ["/Package.swift": #".package(url: "https://github.com/example/lib", from: "1.0.0")"#])
            try require(r.findings.contains { $0.category == .remotePackageDependency && $0.risk == .review })
            try require(r.releaseBlockingFindings.isEmpty)
        }
        test("final result always remains HQ gated") {
            let r = PrivacyStaticAuditor().audit(files: [:])
            try require(r.hqReleaseGateRequired)
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    static func require(_ v: @autoclosure () -> Bool) throws {
        if !v() { throw TestError.assertion }
    }
    enum TestError: Error { case assertion }
}
