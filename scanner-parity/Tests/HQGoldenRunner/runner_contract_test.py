from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
runner = (ROOT / "HQGoldenRunner" / "main.swift").read_text(encoding="utf-8")
v3_launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden-v3.sh").read_text(encoding="utf-8")
thresholdless_preflight = (ROOT / "HQGoldenRunner" / "run-formal-golden-v3-thresholdless-and-calibrate.sh").read_text(encoding="utf-8")
decision_rerun = (ROOT / "HQGoldenRunner" / "run-formal-golden-v3-from-threshold-decision.sh").read_text(encoding="utf-8")
machine_gate = (ROOT / "HQGoldenSupport" / "FormalGoldenMachineGate.swift").read_text(encoding="utf-8")
review_bundle = (ROOT / "HQGoldenSupport" / "GoldenReviewBundleBuilder.swift").read_text(encoding="utf-8")
reference_matcher = (ROOT / "HQGoldenSupport" / "ReferenceFeatureMatcher.swift").read_text(encoding="utf-8")
reference_alignment = (ROOT / "HQGoldenSupport" / "ReferenceAlignment.swift").read_text(encoding="utf-8")
reference_manifest = (ROOT / "HQGoldenSupport" / "ReferenceCorpusManifest.swift").read_text(encoding="utf-8")
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

# The real v3 reference PDF contains negative captures and capture order that is
# not canonical reading order. A configured, SHA-bound corpus manifest must
# normalize raw reference pages before recall/duplicate/order metrics are computed.
for token in [
    'SCANNER_GOLDEN_REFERENCE_MANIFEST',
    'ReferenceCorpusManifest',
    'referenceCorpusManifestSHA256',
    'canonicalReferenceIndex',
    'nearestNegativeDistance',
]:
    assert token in reference_matcher or token in reference_alignment or token in reference_manifest, f"reference-corpus contract missing: {token}"
assert 'referencePDFSHA256.caseInsensitiveCompare(actualPDFSHA256)' in reference_manifest
assert 'unassignedPages' in reference_manifest and 'pageAssignedMoreThanOnce' in reference_manifest
assert 'canonicalReferenceIndex ?? match.referenceIndex' in reference_alignment
assert 'negativeDistance <= threshold' in reference_alignment

# Golden v3 must remain identity locked. The one-command preflight is allowed to
# run the thresholdless production path and produce calibration evidence, but it
# must never accept or auto-select a threshold.
for token in [
    '8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677',
    '4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32',
    'golden-v3-user-confirmed-20260825',
    '--reference-corpus-manifest',
]:
    assert token in v3_launcher, f"Golden v3 identity launcher missing token: {token}"
for token in [
    'run-formal-golden-v3.sh',
    'hq-golden-execution.json',
    'hq-golden-calibration-evidence.json',
    'PENDING_REFERENCE_THRESHOLD_CALIBRATION',
    'CALIBRATION_EVIDENCE_READY_OPERATOR_DECISION_REQUIRED',
    'recommendedThreshold',
    'scanner-hq-golden-calibrator',
    '--analyze',
    'THRESHOLDLESS_CALIBRATION_READY',
]:
    assert token in thresholdless_preflight, f"thresholdless one-command preflight missing token: {token}"
assert 'recommendedThreshold") is None' in thresholdless_preflight, "preflight must reject an automatic threshold recommendation"
assert 'This launcher is thresholdless by contract' in thresholdless_preflight, "preflight must reject --match-threshold"
assert 'next=HQ must inspect the real distributions/sweep/gaps and explicitly select a threshold' in thresholdless_preflight
assert '--emit-threshold' not in thresholdless_preflight, "thresholdless preflight must not emit/select a threshold"

# The second one-command helper may use a threshold only after the calibrator
# validates a human/HQ-authored SHA-bound decision. It must never accept a raw
# threshold argument and must stop at human review rather than Formal Golden PASS.
for token in [
    '--thresholdless-workspace',
    '--decision',
    '--validate-decision',
    'THRESHOLD_DECISION_VALID_FOR_RERUN',
    '--emit-threshold',
    'run-formal-golden-v3.sh',
    '--match-threshold "$threshold"',
    'MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING',
    'PENDING_HUMAN_VISUAL_OCR_REVIEW',
    'GOLDEN_V3_MACHINE_GATE_PASS_HUMAN_REVIEW_REQUIRED',
    'FORMAL_GOLDEN_FAIL_MACHINE_GATE',
    '06-golden-review',
]:
    assert token in decision_rerun, f"decision-bound rerun helper missing token: {token}"
assert 'Do not supply --match-threshold directly' in decision_rerun, "decision-bound rerun must reject a raw threshold"
assert 'pageRecall", 0) >= 0.99' in decision_rerun
assert 'unmatchedOutputCount") == 0' in decision_rerun
assert 'duplicateRate", 1) <= 0.005' in decision_rerun
assert 'orderingAccuracy", 0) >= 1.0' in decision_rerun
assert 'FORMAL_GOLDEN_PASS' not in decision_rerun, "decision-bound rerun helper must never issue Formal Golden PASS"

print("HQ_GOLDEN_RUNNER_CONTRACT_PASS")
