from pathlib import Path

root = Path(__file__).resolve().parents[2]
root_view = (root / "AppShell/Sources/AppShell/ScannerParityRootView.swift").read_text()
importer = (root / "AppShell/Sources/AppShell/MediaImportCoordinator.swift").read_text()
store = (root / "AppShell/Sources/AppShell/ProductFlowStore.swift").read_text()
bindings = (root / "AppShell/Sources/AppShell/ScannerPipelineBindings.swift").read_text()
background = (root / "AppShell/Sources/AppShell/ProductBackgroundTaskController.swift").read_text()
exporter = (root / "AppShell/Sources/AppShell/BookPackageExportView.swift").read_text()

checks = {
    "navigation stack": "NavigationStack" in root_view,
    "photo and video picker": ".any(of: [.images, .videos])" in root_view,
    "Files importer": ".fileImporter" in root_view and "allowedContentTypes: [.image, .movie]" in root_view,
    "no unused camera authorization API": "AVCaptureDevice" not in importer and "requestCameraPermission" not in root_view,
    "video file representation": "FileRepresentation(contentType: .movie)" in importer,
    "durable import storage": ".applicationSupportDirectory" in importer and "ScannerParity" in importer and "Imports" in importer,
    "recoverable imports excluded from backup": "isExcludedFromBackup = true" in importer,
    "managed input cleanup": "discardImportedAssets" in importer and "store.replaceInput" in root_view,
    "pipeline start": "store.startProcessing()" in root_view,
    "pipeline cancel": "store.cancelProcessing()" in root_view,
    "checkpoint resume": "store.resumeProcessing()" in root_view and "restoreCheckpoint" in store,
    "relaunch input restoration": "checkpoint.inputAssets" in store and "fileExists(atPath:" in store,
    "terminal completion restore": "checkpoint.completion" in store and ".restoreCompleted" in store,
    "legacy completion migration": "checkpoint.terminalCompletion" in store and "makeTerminalCheckpoint" in store,
    "active corrupt checkpoint rejected": "checkpoint.hasCanonicalExistingArtifacts" in store,
    "raw input purge after processing": "purgeManagedInputs(inputs)" in store and "self.state.inputAssets = []" in store,
    "intermediate workspace purge after processing": "purgeProcessingWorkspace(bookID: bookID)" in store,
    "processing workspace excluded from backup": "prepareRecoverableDirectory(workspace)" in store,
    "completed package staging excluded from backup": "appendingPathComponent(\"Completed\"" in store and "prepareRecoverableDirectory(root)" in store,
    "terminal checkpoint omits raw and intermediate state": "inputAssets: nil" in store and "completedArtifacts: []" in store,
    "local staging removed after export": "purgeCompletedPackageIfManaged" in store and "Finish and remove local staging" in root_view,
    "stale checkpoint invalidation": "checkpointStore.clear()" in store and "public func replaceInput" in store,
    "progress propagation": "updateProgress" in store and "completedUnits" in root_view,
    "review adapter": "ProductReviewWorkflow" in store and "resolveReviewItem" in root_view,
    "canonical five-stage bindings": all(name in bindings for name in ["frameExtraction", "imageCorrection", "pageAudit", "ocr", "packageWrite"]),
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
