import Foundation

@main
struct ApplePrivacyComplianceAuditorTests {
    static func main() throws {
        let auditor = ApplePrivacyComplianceAuditor()
        let baseline = try String(contentsOfFile: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scanner-parity/SecurityHardening/PrivacyManifestBaseline.xcprivacy")
        var passed = 0
        var failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 }
            catch { print("FAIL \(name): \(error)"); failed += 1 }
        }
        test("local only baseline passes without sensitive APIs") {
            let r = auditor.audit(sourceFiles: ["A.swift":"import Vision\nlet x = FileManager.default"], infoPlist: nil, privacyManifest: baseline)
            try require(r.isFailClosedPass)
        }
        test("UserDefaults requires privacy manifest declaration") {
            let r = auditor.audit(sourceFiles: ["A.swift":"UserDefaults.standard.bool(forKey: \"x\")"], infoPlist: nil, privacyManifest: baseline)
            try require(r.issues.contains(.requiredReasonAPINeedsDeclaration("NSPrivacyAccessedAPICategoryUserDefaults")))
        }
        test("system uptime category detected") {
            let r = auditor.detectRequiredReasonCategories(in: "ProcessInfo.processInfo.systemUptime")
            try require(r.contains("NSPrivacyAccessedAPICategorySystemBootTime"))
        }
        test("disk space category detected") {
            let r = auditor.detectRequiredReasonCategories(in: "URLResourceKey.volumeAvailableCapacityKey")
            try require(r.contains("NSPrivacyAccessedAPICategoryDiskSpace"))
        }
        test("file timestamp category detected") {
            let r = auditor.detectRequiredReasonCategories(in: "resourceValues.creationDate")
            try require(r.contains("NSPrivacyAccessedAPICategoryFileTimestamp"))
        }
        test("camera source requires usage description") {
            let r = auditor.audit(sourceFiles: ["Camera.swift":"let d = AVCaptureDevice.default(for: .video)"], infoPlist: "<dict></dict>", privacyManifest: baseline)
            try require(r.issues.contains(.missingCameraUsageDescription))
        }
        test("photo library source requires usage description") {
            let r = auditor.audit(sourceFiles: ["Photos.swift":"let picker = PHPickerViewController(configuration: c)"], infoPlist: "<dict></dict>", privacyManifest: baseline)
            try require(r.issues.contains(.missingPhotoLibraryUsageDescription))
        }
        test("tracking true is rejected") {
            let bad = baseline.replacingOccurrences(of: "<false/>", with: "<true/>")
            let r = auditor.audit(sourceFiles: [:], infoPlist: nil, privacyManifest: bad)
            try require(r.issues.contains(.trackingEnabled))
        }
        test("tracking domains are rejected") {
            let bad = baseline.replacingOccurrences(of: "<key>NSPrivacyTrackingDomains</key>\n  <array/>", with: "<key>NSPrivacyTrackingDomains</key>\n  <array><string>tracker.invalid</string></array>")
            let r = auditor.audit(sourceFiles: [:], infoPlist: nil, privacyManifest: bad)
            try require(r.issues.contains(.trackingDomainsPresent))
        }
        test("missing manifest fails closed") {
            let r = auditor.audit(sourceFiles: [:], infoPlist: nil, privacyManifest: nil)
            try require(r.issues.contains(.missingPrivacyManifest))
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }
    static func require(_ value: @autoclosure () -> Bool) throws { if !value() { throw TestError.assertion } }
    enum TestError: Error { case assertion }
}
