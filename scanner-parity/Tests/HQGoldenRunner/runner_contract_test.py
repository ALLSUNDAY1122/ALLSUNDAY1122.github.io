from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
runner = (ROOT / "HQGoldenRunner" / "main.swift").read_text(encoding="utf-8")
machine_gate = (ROOT / "HQGoldenSupport" / "FormalGoldenMachineGate.swift").read_text(encoding="utf-8")
review_bundle = (ROOT / "HQGoldenSupport" / "GoldenReviewBundleBuilder.swift").read_text(encoding="utf-8")
product_flow = (ROOT / "ProductFlow" / "Package.swift").read_text(encoding="utf-8")

required_package_tokens = [
    'name: "RuntimeComposition"',
    '"ProductionScannerRuntime.swift"',
    '"GoldenHardenedScannerRuntime.swift"',
    'name: "HQGoldenSupport"',
    'name: "scanner-hq-golden-runner"',
    '"ScannerRuntime"',
]
for token in required_package_tokens:
    assert token in package, f"missing shared runtime composition token: {token}"

assert '.macOS(.v14)' in product_flow, "ProductFlow must support the macOS HQ runner"
assert 'GoldenHardenedScannerRuntime.makeDriver()' in runner, "HQ runner must execute the same Golden-hardened product driver"
assert 'ReferenceFeatureMatcher.compare' in runner, "runner must compare output pages with the reference PDF"
assert 'ReferenceAlignment.evaluate' in runner, "runner must compute reference metrics when a calibrated threshold is supplied"
assert 'FormalGoldenMachineGate.evaluate' in runner, "runner must aggregate hard machine gates"
assert 'GoldenReviewBundleBuilder.write' in runner, "runner must generate the local visual/OCR review bundle"
assert '06-golden-review' in runner, "runner must place the local review bundle in a dedicated workspace directory"
assert 'reviewBundleRelativePath' in runner and 'reviewBundlePageCount' in runner, "runner report must point to the local review bundle without persisting raw paths"
assert 'PackageIntegrityReport' in runner, "runner must include canonical BookPackage integrity evidence"
assert 'searchablePDFTextSummary' in runner, "runner must inspect extractable searchable-PDF text"
assert 'PENDING_HUMAN_VISUAL_OCR_REVIEW' in runner, "machine success must still require real visual/OCR review"
assert 'FORMAL_GOLDEN_FAIL_MACHINE_GATE' in runner, "hard machine failures must fail closed"
assert 'FORMAL_GOLDEN_PASS' not in runner, "runner must never issue Formal Golden PASS automatically"

for token in [
    'PENDING_GOLDEN_IDENTITY_EXPECTATIONS',
    'PENDING_REFERENCE_THRESHOLD_CALIBRATION',
    'MACHINE_GATES_FAIL',
    'MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING',
]:
    assert token in machine_gate, f"machine-gate verdict contract missing: {token}"
assert 'FORMAL_GOLDEN_PASS' not in machine_gate, "machine gate must never issue Formal Golden PASS"

for token in [
    'review-manifest.json',
    'index.html',
    'images/output',
    'images/reference',
    'Do not commit or upload',
]:
    assert token in review_bundle, f"Golden review bundle contract missing: {token}"
assert 'referencePDFURL.path' not in review_bundle, "review bundle must not persist the raw reference PDF absolute path"

for output in ["pages", "text", "book_searchable.pdf", "book.md", "book.txt", "manifest.json", "integrity-report.json"]:
    assert f'"{output}"' in runner, f"BookPackage evidence missing required output: {output}"
for field in [
    "observedVideoSHA256",
    "observedPDFSHA256",
    "referencePDFPageCount",
    "stageEvidence",
    "correctionSummary",
    "pageAuditSummary",
    "ocrSummary",
    "searchablePDFTextSummary",
    "packageIntegrity",
    "referenceMatches",
    "referenceMetrics",
    "reviewBundleRelativePath",
    "reviewBundlePageCount",
    "machineGateAssessment",
]:
    assert field in runner, f"runner evidence missing: {field}"
assert 'videoURL.path' not in runner.split('HQGoldenExecutionReport(', 1)[0], "report schema should not persist a raw local video path"

print("HQ_GOLDEN_RUNNER_CONTRACT_PASS")
