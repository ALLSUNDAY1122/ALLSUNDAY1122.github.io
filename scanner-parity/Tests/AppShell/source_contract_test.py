from pathlib import Path

root = Path(__file__).resolve().parents[2]
root_view = (root / "AppShell/Sources/AppShell/ScannerParityRootView.swift").read_text()
importer = (root / "AppShell/Sources/AppShell/MediaImportCoordinator.swift").read_text()
store = (root / "AppShell/Sources/AppShell/ProductFlowStore.swift").read_text()
bindings = (root / "AppShell/Sources/AppShell/ScannerPipelineBindings.swift").read_text()
production = (root / "AppShell/Sources/AppShell/ProductionScannerRuntime.swift").read_text()
app = (root / "AppShell/Sources/AppShell/ScannerParityApp.swift").read_text()
recovery = (root / "AppShell/Sources/AppShell/RecoveryProductReviewWorkflow.swift").read_text()
background = (root / "AppShell/Sources/AppShell/ProductBackgroundTaskController.swift").read_text()
exporter = (root / "AppShell/Sources/AppShell/BookPackageExportView.swift").read_text()
package = (root / "AppShell/Package.swift").read_text()
privacy = root / "AppShell/Sources/AppShell/Resources/PrivacyInfo.xcprivacy"

checks = {
    "navigation stack": "NavigationStack" in root_view,
    "photo and video picker": ".any(of: [.images, .videos])" in root_view,
    "Files importer": ".fileImporter" in root_view and "allowedContentTypes: [.image, .movie]" in root_view,
    "camera denial recovery": "Photos and Files import still work" in root_view,
    "video file representation": "FileRepresentation(contentType: .movie)" in importer,
    "pipeline start": "store.startProcessing()" in root_view,
    "pipeline cancel": "store.cancelProcessing()" in root_view,
    "checkpoint resume": "store.resumeProcessing()" in root_view and "restoreCheckpoint" in store,
    "progress propagation": "updateProgress" in store and "completedUnits" in root_view,
    "review adapter": "ProductReviewWorkflow" in store and "resolveReviewItem" in root_view,
    "canonical five-stage bindings": all(name in bindings for name in ["frameExtraction", "imageCorrection", "pageAudit", "ocr", "packageWrite"]),
    "production five-stage runtime": all(token in production for token in ["frameExtractionBinding()", "imageCorrectionBinding()", "pageAuditBinding()", "ocrBinding()", "packageBinding()"]),
    "production app default": "ProductionScannerRuntime.makeDriver()" in app and "BoundProductPipelineDriver(bindings: [])" not in app,
    "recovery core product adapter": "RecoveryProductReviewWorkflow" in app and "AppShellReviewAdapter" in recovery,
    "package integrity gate": "PackageIntegrityVerifier().verify" in production and "packageIntegrityFailed" in production,
    "privacy manifest embedded": privacy.exists() and "PrivacyInfo.xcprivacy" in package,
    "share UX": "ShareLink" in root_view,
    "Files export UX": "BookPackageDocumentExporter" in root_view and "UIDocumentPickerViewController" in exporter,
    "bounded background grace": "beginBackgroundTask" in background and "store.cancelProcessing()" in root_view,
    "no obsolete export placeholder": "Files/share export is connected in a later lane milestone." not in root_view,
}

for name, passed in checks.items():
    print(("PASS " if passed else "FAIL ") + name)

if not all(checks.values()):
    raise SystemExit(1)
print(f"RESULT passed={sum(checks.values())} failed=0")
