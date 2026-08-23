import Foundation

@main
struct DataLifecyclePolicyTests {
    static func main() throws {
        let policy = BookDataLifecyclePolicy()
        var passed = 0
        var failed = 0

        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 }
            catch { print("FAIL \(name): \(error)"); failed += 1 }
        }

        test("images never allowed in logs") {
            try require(!policy.decision(for: .pageImage, storage: .log).allowed)
        }
        test("ocr text never allowed in logs") {
            try require(!policy.decision(for: .ocrText, storage: .log).allowed)
        }
        test("standard path forbids network transmission") {
            for kind in SensitiveBookDataKind.allCases {
                try require(!policy.mayTransmit(kind))
            }
        }
        test("temporary processing must purge") {
            let d = policy.decision(for: .pageImage, storage: .temporary)
            try require(d.allowed && d.purgeAfterUse)
        }
        test("cache retention is denied") {
            try require(!policy.decision(for: .ocrText, storage: .cache).allowed)
            try require(policy.decision(for: .ocrText, storage: .cache).purgeAfterUse)
        }
        test("persistent export requires user action") {
            let d = policy.decision(for: .bookPackage, storage: .userSelectedPersistent)
            try require(d.allowed && d.requiresExplicitUserAction)
        }
        test("raw source not silently persisted in app documents") {
            try require(!policy.decision(for: .sourceVideo, storage: .appDocuments).allowed)
            try require(!policy.decision(for: .pageImage, storage: .appDocuments).allowed)
            try require(!policy.decision(for: .ocrText, storage: .appDocuments).allowed)
        }
        test("final local package may persist") {
            try require(policy.decision(for: .bookPackage, storage: .appDocuments).allowed)
        }
        test("unsafe opaque id is redacted") {
            let out = PrivacySafeLogger().sanitize([.opaqueID("page text / secret")])
            try require(out == ["id=<redacted>"])
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    static func require(_ value: @autoclosure () -> Bool) throws {
        if !value() { throw TestError.assertion }
    }
    enum TestError: Error { case assertion }
}
