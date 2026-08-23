from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
runner = (ROOT / "HQGoldenRunner" / "main.swift").read_text(encoding="utf-8")
product_flow = (ROOT / "ProductFlow" / "Package.swift").read_text(encoding="utf-8")

required_package_tokens = [
    'name: "RuntimeComposition"',
    '"ProductionScannerRuntime.swift"',
    '"GoldenHardenedScannerRuntime.swift"',
    'name: "HQGoldenSupport"',
    'name: "scanner-hq-golden-runner"',
]
for token in required_package_tokens:
    assert token in package, f"missing shared runtime composition token: {token}"

assert '.macOS(.v14)' in product_flow, "ProductFlow must support the macOS HQ runner"
assert 'GoldenHardenedScannerRuntime.makeDriver()' in runner, "HQ runner must execute the same Golden-hardened product driver"
assert 'ReferenceFeatureMatcher.compare' in runner, "runner must compare output pages with the reference PDF"
assert 'ReferenceAlignment.evaluate' in runner, "runner must compute reference metrics when a calibrated threshold is supplied"
assert 'PENDING_REFERENCE_THRESHOLD_CALIBRATION' in runner, "runner must not invent an uncalibrated match threshold"
assert 'REFERENCE_METRICS_PASS_OTHER_GOLDEN_GATES_PENDING' in runner, "reference metrics alone must not issue Formal Golden PASS"
assert 'REFERENCE_METRICS_FAIL' in runner, "reference metric failure must remain explicit"
for output in ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json"]:
    assert f'"{output}"' in runner, f"BookPackage evidence missing required output: {output}"
for field in ["observedVideoSHA256", "observedPDFSHA256", "referencePDFPageCount", "stageEvidence", "referenceMatches", "referenceMetrics"]:
    assert field in runner, f"runner evidence missing: {field}"
assert 'videoURL.path' not in runner.split('HQGoldenExecutionReport(', 1)[0], "report schema should not persist a raw local video path"

print("HQ_GOLDEN_RUNNER_CONTRACT_PASS")
