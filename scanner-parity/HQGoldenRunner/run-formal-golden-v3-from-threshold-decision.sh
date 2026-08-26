#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
LAUNCHER="$SCRIPT_DIR/run-formal-golden-v3.sh"

VIDEO_SHA="8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677"
PDF_SHA="4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32"
BOOK_ID="golden-v3-user-confirmed-20260825"
CANONICAL_PAGE_COUNT=22

video=""
pdf=""
thresholdless_workspace=""
decision=""
workspace=""

while (( $# > 0 )); do
  key="$1"
  shift
  if (( $# == 0 )); then
    echo "Missing value for $key" >&2
    exit 2
  fi
  value="$1"
  shift
  case "$key" in
    --video) video="$value" ;;
    --pdf) pdf="$value" ;;
    --thresholdless-workspace) thresholdless_workspace="$value" ;;
    --decision) decision="$value" ;;
    --workspace) workspace="$value" ;;
    --match-threshold)
      echo "Do not supply --match-threshold directly. This launcher only accepts a validated SHA-bound HQ decision file." >&2
      exit 2
      ;;
    *)
      echo "Unsupported Golden v3 decision-rerun argument: $key" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$video" || -z "$pdf" || -z "$thresholdless_workspace" || -z "$decision" || -z "$workspace" ]]; then
  echo "Usage: $0 --video <mp4> --pdf <reference.pdf> --thresholdless-workspace <dir> --decision <decision.json> --workspace <dir>" >&2
  exit 2
fi

execution="$thresholdless_workspace/hq-golden-execution.json"
calibration="$thresholdless_workspace/hq-golden-calibration-evidence.json"
validation="$thresholdless_workspace/hq-golden-threshold-decision-assessment.json"

for required in "$execution" "$calibration" "$decision"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required threshold decision input: $required" >&2
    exit 3
  fi
done

swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-calibrator \
  --execution-report "$execution" \
  --calibration-evidence "$calibration" \
  --decision "$decision" \
  --validate-decision "$validation"

python3 - "$validation" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    assessment = json.load(f)
assert assessment.get("verdict") == "THRESHOLD_DECISION_VALID_FOR_RERUN", "threshold decision is not valid for rerun"
threshold = assessment.get("threshold")
assert isinstance(threshold, (int, float)) and threshold >= 0, "validated threshold missing"
print("GOLDEN_V3_THRESHOLD_DECISION_BINDING_PASS")
PY

threshold="$(swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-calibrator \
  --execution-report "$execution" \
  --calibration-evidence "$calibration" \
  --decision "$decision" \
  --emit-threshold)"

if [[ -z "$threshold" ]]; then
  echo "Validated decision did not emit a threshold." >&2
  exit 3
fi

bash "$LAUNCHER" \
  --video "$video" \
  --pdf "$pdf" \
  --workspace "$workspace" \
  --match-threshold "$threshold"

report="$workspace/hq-golden-execution.json"
if [[ ! -f "$report" ]]; then
  echo "Thresholded runner completed without hq-golden-execution.json" >&2
  exit 3
fi

python3 - "$report" "$VIDEO_SHA" "$PDF_SHA" "$BOOK_ID" "$CANONICAL_PAGE_COUNT" "$threshold" <<'PY'
import json
import math
import sys

path, video_sha, pdf_sha, book_id, canonical_count_raw, threshold_raw = sys.argv[1:]
canonical_count = int(canonical_count_raw)
expected_threshold = float(threshold_raw)
with open(path, encoding="utf-8") as f:
    report = json.load(f)

assert report.get("schemaVersion", 0) >= 4, "execution report schemaVersion must be >= 4"
assert report.get("bookID") == book_id, "Golden v3 bookID mismatch"
assert report.get("observedVideoSHA256", "").lower() == video_sha, "observed video SHA mismatch"
assert report.get("observedPDFSHA256", "").lower() == pdf_sha, "observed PDF SHA mismatch"
assert report.get("videoSHAMatchesExpected") is True, "video expected-SHA binding failed"
assert report.get("pdfSHAMatchesExpected") is True, "PDF expected-SHA binding failed"

metrics = report.get("referenceMetrics")
assert isinstance(metrics, dict), "thresholded run must contain referenceMetrics"
assert metrics.get("referencePageCount") == canonical_count, "reference corpus page count mismatch"
actual_threshold = metrics.get("threshold")
assert isinstance(actual_threshold, (int, float)) and math.isclose(float(actual_threshold), expected_threshold, rel_tol=1e-6, abs_tol=1e-6), "report threshold does not match validated decision"

assessment = report.get("machineGateAssessment") or {}
verdict = assessment.get("verdict")
formal = report.get("formalGoldenVerdict")
if verdict == "MACHINE_GATES_PASS_HUMAN_VISUAL_OCR_REVIEW_PENDING":
    assert formal == "PENDING_HUMAN_VISUAL_OCR_REVIEW", "machine-pass formal verdict mismatch"
    assert metrics.get("pageRecall", 0) >= 0.99, "machine pass with page recall below 99%"
    assert metrics.get("unmatchedOutputCount") == 0, "machine pass with unmatched output"
    assert metrics.get("duplicateRate", 1) <= 0.005, "machine pass with duplicate rate above 0.5%"
    assert metrics.get("orderingAccuracy", 0) >= 1.0, "machine pass with ordering below 100%"
    assert (report.get("correctionSummary") or {}).get("failureCount") == 0, "machine pass with correction failures"
    assert (report.get("ocrSummary") or {}).get("failureCount") == 0, "machine pass with OCR engine failures"
    integrity = report.get("packageIntegrity") or {}
    assert integrity.get("valid") is True and report.get("requiredBookPackageFilesPresent") is True, "machine pass with invalid BookPackage"
    review_path = report.get("reviewBundleRelativePath")
    assert isinstance(review_path, str) and review_path, "machine pass missing review bundle"
    print("GOLDEN_V3_MACHINE_GATE_PASS_HUMAN_REVIEW_REQUIRED")
    print(f"review_bundle={review_path}")
    sys.exit(0)

if verdict == "MACHINE_GATES_FAIL":
    blockers = assessment.get("blockingReasons") or []
    print("FORMAL_GOLDEN_FAIL_MACHINE_GATE", file=sys.stderr)
    print("blocking_reasons=" + ",".join(map(str, blockers)), file=sys.stderr)
    sys.exit(4)

raise AssertionError(f"unexpected machine gate verdict: {verdict!r} / formal={formal!r}")
PY

printf '%s\n' \
  "THRESHOLDED_GOLDEN_V3_RUN_COMPLETE" \
  "decision_assessment=$validation" \
  "execution_report=$report" \
  "review_bundle=$workspace/06-golden-review" \
  "next=Review every output page visually and for Japanese OCR. Machine pass remains pending human review and finalization."
