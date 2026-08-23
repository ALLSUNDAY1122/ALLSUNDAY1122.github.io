import Foundation

@main
struct ProcessingStorageLifecycleAuditorTests {
    static func main() throws {
        let auditor = ProcessingStorageLifecycleAuditor()
        var passed = 0
        var failed = 0
        func test(_ name: String, _ body: () throws -> Void) {
            do { try body(); print("PASS \(name)"); passed += 1 }
            catch { print("FAIL \(name): \(error)"); failed += 1 }
        }

        let managedImport = "applicationSupportDirectory Imports isExcludedFromBackup = true discardImportedAssets removeItem"
        let managedImportWithCamera = managedImport + " AVCaptureDevice"
        let goodStore = "applicationSupportDirectory purgeProcessingWorkspace"
        let runtime = "01-frame-extraction 02-image-correction 03-page-audit 04-ocr"

        test("managed recovery storage passes with backup exclusion and purge") {
            let r = auditor.audit(mediaImportSource: managedImport, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.pass)
        }
        test("camera-free product does not require camera purpose string") {
            let r = auditor.audit(mediaImportSource: managedImport, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(!r.issues.contains(.cameraPurposeStringNotRepresented))
        }
        test("camera product passes with purpose string") {
            let r = auditor.audit(mediaImportSource: managedImportWithCamera, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: ["NSCameraUsageDescription"])
            try require(r.pass)
        }
        test("missing workspace purge blocks") {
            let r = auditor.audit(mediaImportSource: managedImport, productFlowStoreSource: "applicationSupportDirectory", productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.issues.contains(.processingWorkspaceNotPurged))
        }
        test("missing backup exclusion blocks") {
            let r = auditor.audit(mediaImportSource: "applicationSupportDirectory Imports discardImportedAssets removeItem", productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.issues.contains(.managedImportNotBackupExcluded))
        }
        test("missing import purge blocks") {
            let r = auditor.audit(mediaImportSource: "applicationSupportDirectory Imports isExcludedFromBackup = true", productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.issues.contains(.managedImportNotPurgeable))
        }
        test("camera without purpose string blocks") {
            let r = auditor.audit(mediaImportSource: managedImportWithCamera, productFlowStoreSource: goodStore, productionRuntimeSource: runtime, appResourceTexts: [])
            try require(r.issues.contains(.cameraPurposeStringNotRepresented))
        }

        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }

    static func require(_ value: @autoclosure () -> Bool) throws {
        if !value() { throw TestError.assertion }
    }
    enum TestError: Error { case assertion }
}
