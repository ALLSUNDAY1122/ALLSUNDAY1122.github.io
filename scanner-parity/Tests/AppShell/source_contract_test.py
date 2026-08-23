from pathlib import Path

root = Path(__file__).resolve().parents[2]
root_view = (root / "AppShell/Sources/AppShell/ScannerParityRootView.swift").read_text()
importer = (root / "AppShell/Sources/AppShell/MediaImportCoordinator.swift").read_text()
store = (root / "AppShell/Sources/AppShell/ProductFlowStore.swift").read_text()

checks = {
    "navigation stack": "NavigationStack" in root_view,
    "photo and video picker": ".any(of: [.images, .videos])" in root_view,
    "Files importer": ".fileImporter" in root_view and "allowedContentTypes: [.image, .movie]" in root_view,
    "camera denial recovery": "Photos and Files import still work" in root_view,
    "video file representation": "FileRepresentation(contentType: .movie)" in importer,
    "state reducer store": "ProductFlowReducer.reduce" in store,
    "retry action": "Button(\"Retry\")" in root_view,
}

for name, passed in checks.items():
    print(("PASS " if passed else "FAIL ") + name)

if not all(checks.values()):
    raise SystemExit(1)
print(f"RESULT passed={sum(checks.values())} failed=0")
