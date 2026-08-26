from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
package = (ROOT / "Package.swift").read_text(encoding="utf-8")
launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden.sh").read_text(encoding="utf-8")
v3_launcher = (ROOT / "HQGoldenRunner" / "run-formal-golden-v3.sh").read_text(encoding="utf-8")
bootstrap_path = ROOT / "HQGoldenRunner" / "bootstrap-formal-golden-v3-macos.sh"
bootstrap = bootstrap_path.read_text(encoding="utf-8")
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
assert 'unset SCANNER_GOLDEN_REFERENCE_MANIFEST' in launcher, "generic execution must clear inherited stale corpus binding"

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

# The user-facing macOS bootstrap may download/update only project code. It must
# bind the exact local raw Golden bytes by size+SHA, run the thresholdless real
# production path locally, and stop for HQ calibration review. Raw/derived book
# content must never be added or pushed to GitHub by the bootstrap.
subprocess.run(["bash", "-n", str(bootstrap_path)], check=True)
for token in [
    'Darwin',
    'scanner-parity/integration',
    '8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677',
    '4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32',
    'VIDEO_SIZE=191911175',
    'PDF_SIZE=25751801',
    'golden-v3-user-confirmed-20260825',
    '--input-dir',
    'LOCAL_ONLY_DO_NOT_UPLOAD_RAW_OR_DERIVED_BOOK_CONTENT',
    'run-formal-golden-v3-thresholdless-and-calibrate.sh',
    'hq-golden-execution.json',
    'hq-golden-calibration-evidence.json',
    'THRESHOLDLESS_CALIBRATION_READY',
    'HQ_INSPECT_REAL_CALIBRATION_AND_AUTHOR_SHA_BOUND_THRESHOLD_DECISION',
    'GOLDEN_V3_MACOS_BOOTSTRAP_THRESHOLDLESS_COMPLETE',
]:
    assert token in bootstrap, f"macOS Golden bootstrap contract missing: {token}"
assert 'git clone --single-branch --branch "$INTEGRATION_REF"' in bootstrap
assert 'git -C "$repo_dir" fetch --prune origin "$INTEGRATION_REF"' in bootstrap
assert 'git push' not in bootstrap, "bootstrap must never push raw/derived local state"
assert 'git add' not in bootstrap, "bootstrap must never stage raw/derived local state"
assert '--match-threshold' not in bootstrap, "bootstrap initial phase must remain thresholdless"
assert 'len(candidates) != 1' in bootstrap, "raw identity discovery must fail closed on zero/duplicate exact matches"

assert 'FORMAL_GOLDEN_PASS' not in launcher
assert 'FORMAL_GOLDEN_PASS' not in v3_launcher
assert 'FORMAL_GOLDEN_PASS' not in recorder
assert 'FORMAL_GOLDEN_PASS' not in sanitizer
assert '<REDACTED_PATH>' in sanitizer and '<HOME>' in sanitizer

print("HQ_GOLDEN_FAILURE_LAUNCHER_CONTRACT_PASS")
