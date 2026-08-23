import Foundation

@main
struct SensitiveDataStaticAuditTests {
    static func main() throws {
        let auditor = SensitiveDataStaticAudit()
        var passed = 0
        var failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 }
            catch { print("FAIL \(name): \(error)"); failed += 1 }
        }
        test("OCR text logging is rejected") {
            let r = auditor.audit(files: ["/Sources/A.swift":"print(ocrPage.text)"])
            try require(r.contains { $0.kind == .sensitiveLogging })
        }
        test("page image cache persistence is rejected") {
            let r = auditor.audit(files: ["/Sources/A.swift":"let pageImageURL = cachesDirectory.appendingPathComponent(\"p.jpg\")"])
            try require(r.contains { $0.kind == .cachePersistence })
        }
        test("OCR upload path is rejected") {
            let r = auditor.audit(files: ["/Sources/A.swift":"URLSession.shared.uploadTask(with: request, from: ocrText)"])
            try require(r.contains { $0.kind == .networkBoundary })
        }
        test("opaque metrics logging is allowed") {
            let r = auditor.audit(files: ["/Sources/A.swift":"logger.info(\"pages=10 duration=22\")"])
            try require(r.isEmpty)
        }
        test("fixture sources are excluded") {
            let r = auditor.audit(files: ["/Tests/A.swift":"print(ocrPage.text)"])
            try require(r.isEmpty)
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }
    static func require(_ value: @autoclosure () -> Bool) throws { if !value() { throw TestError.assertion } }
    enum TestError: Error { case assertion }
}
