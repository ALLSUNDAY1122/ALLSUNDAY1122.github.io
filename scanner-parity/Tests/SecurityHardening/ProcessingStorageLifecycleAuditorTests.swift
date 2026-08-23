import Foundation

@main
struct ProcessingStorageLifecycleAuditorTests {
    static func main() throws {
        let auditor = ProcessingStorageLifecycleAuditor()
        var passed = 0
        var failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 } catch { print("FAIL \(name): \(error)"); failed += 1 }
        }
        let goodImport = "applicationSupportDirectory Imports isExcludedFromBackup = true discardImportedAssets removeItem AVCaptureDevice"
        let goodStore = "applicationSupportDirectory purgeProcessingWorkspace"
        let runtime = "01-frame-extraction 02-image-correction 03-page-audit 04-ocr"
        test("managed recovery storage may pass when lifecycle is explicit") {
            let r = auditor.audit(mediaImportSource: goodImport, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: ["NSCameraUsageDescription"])
            try require(r.pass)
        }
        test("missing workspace purge blocks") {
            let r = auditor.audit(mediaImportSource: goodImport, productFlowStoreSource: "applicationSupportDirectory", productionRuntimeSource: runtime, appResourceTexts: ["NSCameraUsageDescription"])
            try require(r.issues.contains(.processingWorkspaceNotPurged))
        }
        test("missing backup exclusion blocks") {
            let r = auditor.audit(mediaImportSource: "applicationSupportDirectory Imports discardImportedAssets removeItem AVCaptureDevice", productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: ["NSCameraUsageDescription"])
            try require(r.issues.contains(.managedImportNotBackupExcluded))
        }
        test("missing camera purpose string blocks") {
            let r = auditor.audit(mediaImportSource: goodImport, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.issues.contains(.cameraPurposeStringNotRepresented))
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }
    static func require(_ value: @autoclosure () -> Bool) throws { if !value() { throw TestError.assertion } }
    enum TestError: Error { case assertion }
}
