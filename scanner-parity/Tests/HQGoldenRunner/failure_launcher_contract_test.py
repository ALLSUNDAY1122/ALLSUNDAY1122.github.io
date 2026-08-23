from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden.sh").read_text(encoding="utf-8")
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
    'runner_status',
    'mktemp',
    'trap cleanup EXIT',
    'exit "$runner_status"',
]:
    assert token in launcher, f"Formal Golden launcher fail-safe contract missing: {token}"

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
assert 'FORMAL_GOLDEN_PASS' not in recorder
assert 'FORMAL_GOLDEN_PASS' not in sanitizer
assert '<REDACTED_PATH>' in sanitizer and '<HOME>' in sanitizer

print("HQ_GOLDEN_FAILURE_LAUNCHER_CONTRACT_PASS")
