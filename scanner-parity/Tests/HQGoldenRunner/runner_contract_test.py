from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
runner = (ROOT / "HQGoldenRunner" / "main.swift").read_text(encoding="utf-8")
product_flow = (ROOT / "ProductFlow" / "Package.swift").read_text(encoding="utf-8")

required_package_tokens = [
    'name: "RuntimeComposition"',
    '"ProductionScannerRuntime.swift"',
    '"GoldenHardenedScannerRuntime.swift"',
    'name: "scanner-hq-golden-runner"',
]
for token in required_package_tokens:
    assert token in package, f"missing shared runtime composition token: {token}"

assert '.macOS(.v14)' in product_flow, "ProductFlow must support the macOS HQ runner"
assert 'GoldenHardenedScannerRuntime.makeDriver()' in runner, "HQ runner must execute the same Golden-hardened product driver"
assert 'formalGoldenVerdict: "PENDING_REFERENCE_METRIC_EVALUATION"' in runner, "runner must not issue Formal Golden PASS before reference metrics"
for output in ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json"]:
    assert f'"{output}"' in runner, f"BookPackage evidence missing required output: {output}"
for field in ["observedVideoSHA256", "observedPDFSHA256", "referencePDFPageCount", "stageEvidence"]:
    assert field in runner, f"runner evidence missing: {field}"

print("HQ_GOLDEN_RUNNER_CONTRACT_PASS")
