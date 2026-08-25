from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden.sh").read_text(encoding="utf-8")
v3_launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden-v3.sh").read_text(encoding="utf-8")
recorder = (ROOT / "HQGoldenFailureRecorder" / "main.swift").read_text(encoding="utf-8")
sanitizer = (ROOT / "HQGoldenSupport" / "GoldenExecutionFailureSanitizer.swift").read_text(encoding="utf-8")

for token in [
    'scanner-hq-golden-failure-recorder',
    'name: "HQGoldenFailureRecorder"',
    '"HQGoldenFailureRecorder"',
]:
    assert token in package, f"failure recorder package contract missing: {token}"

for token in [
    'scanner-hq-golden-runner',
    'scanner-hq-golden-failure-recorder',
    '--workspace',
    '--reference-corpus-manifest',
    'SCANNER_GOLDEN_REFERENCE_MANIFEST',
    'runner_status',
    'mktemp',
    'trap cleanup EXIT',
    'exit "$runner_status"',
]:
    assert token in launcher, f"Formal Golden launcher fail-safe contract missing: {token}"

assert '[[ ! -f "$reference_corpus_manifest" ]]' in launcher, "configured reference corpus must fail closed when missing"

for token in [
    'golden-v3-user-confirmed-20260825',
    '8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677',
    '4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32',
    'golden-v3-reference-corpus.json',
    '--reference-corpus-manifest',
    '--match-threshold',
    'Unsupported Golden v3 argument',
]:
    assert token in v3_launcher, f"Golden v3 identity-locked launcher contract missing: {token}"
assert '--expected-video-sha "$VIDEO_SHA"' in v3_launcher
assert '--expected-pdf-sha "$PDF_SHA"' in v3_launcher
assert 'exec bash "$LAUNCHER"' in v3_launcher

for token in [
    'FORMAL_GOLDEN_FAIL_PIPELINE_EXECUTION',
    'hq-golden-execution-failure.json',
    'completedStageMarkers',
    'integrityReportRelativePaths',
    'GoldenExecutionFailureSanitizer.sanitize',
    'runner_nonzero_exit',
]:
    assert token in recorder, f"failure recorder evidence contract missing: {token}"

assert 'FORMAL_GOLDEN_PASS' not in launcher
assert 'FORMAL_GOLDEN_PASS' not in v3_launcher
assert 'FORMAL_GOLDEN_PASS' not in recorder
assert 'FORMAL_GOLDEN_PASS' not in sanitizer
assert '<REDACTED_PATH>' in sanitizer and '<HOME>' in sanitizer

print("HQ_GOLDEN_FAILURE_LAUNCHER_CONTRACT_PASS")
