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
    --workspace) workspace="$value" ;;
    --match-threshold)
      echo "This launcher is thresholdless by contract; do not supply --match-threshold." >&2
      exit 2
      ;;
    *)
      echo "Unsupported Golden v3 thresholdless argument: $key" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$video" || -z "$pdf" || -z "$workspace" ]]; then
  echo "Usage: $0 --video <mp4> --pdf <reference.pdf> --workspace <dir>" >&2
  exit 2
fi

bash "$LAUNCHER" \
  --video "$video" \
  --pdf "$pdf" \
  --workspace "$workspace"

report="$workspace/hq-golden-execution.json"
calibration="$workspace/hq-golden-calibration-evidence.json"

if [[ ! -f "$report" ]]; then
  echo "Thresholdless runner completed without hq-golden-execution.json" >&2
  exit 3
fi

python3 - "$report" "$VIDEO_SHA" "$PDF_SHA" "$BOOK_ID" "$CANONICAL_PAGE_COUNT" <<'PY'
import json
import sys

path, video_sha, pdf_sha, book_id, canonical_count_raw = sys.argv[1:]
canonical_count = int(canonical_count_raw)
with open(path, encoding="utf-8") as f:
    report = json.load(f)

assert report.get("schemaVersion", 0) >= 4, "execution report schemaVersion must be >= 4"
assert report.get("bookID") == book_id, "Golden v3 bookID mismatch"
assert report.get("observedVideoSHA256", "").lower() == video_sha, "observed video SHA mismatch"
assert report.get("observedPDFSHA256", "").lower() == pdf_sha, "observed PDF SHA mismatch"
assert report.get("videoSHAMatchesExpected") is True, "video expected-SHA binding failed"
assert report.get("pdfSHAMatchesExpected") is True, "PDF expected-SHA binding failed"
assert report.get("formalGoldenVerdict") == "PENDING_REFERENCE_THRESHOLD_CALIBRATION", "thresholdless run did not reach calibration state"
assert report.get("referenceMetrics") is None, "thresholdless run must not contain thresholded reference metrics"
matches = report.get("referenceMatches") or []
assert matches, "thresholdless run contains no reference matches"
assert report.get("outputPageCount") == len(matches), "outputPageCount/referenceMatches mismatch"
corpus_counts = {m.get("referenceCorpusPageCount") for m in matches}
assert corpus_counts == {canonical_count}, f"reference corpus count mismatch: {corpus_counts}"
for match in matches:
    idx = match.get("canonicalReferenceIndex")
    assert isinstance(idx, int) and 0 <= idx < canonical_count, "invalid canonical reference index"
    manifest_sha = match.get("referenceCorpusManifestSHA256")
    assert isinstance(manifest_sha, str) and len(manifest_sha) == 64, "missing corpus-manifest SHA binding"
print("GOLDEN_V3_THRESHOLDLESS_REPORT_BINDING_PASS")
PY

swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-calibrator \
  --execution-report "$report" \
  --analyze "$calibration"

python3 - "$calibration" "$VIDEO_SHA" "$PDF_SHA" "$BOOK_ID" <<'PY'
import json
import sys

path, video_sha, pdf_sha, book_id = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    evidence = json.load(f)

assert evidence.get("verdict") == "CALIBRATION_EVIDENCE_READY_OPERATOR_DECISION_REQUIRED", "unexpected calibration verdict"
assert evidence.get("recommendedThreshold") is None, "automatic threshold recommendation is forbidden"
assert evidence.get("bookID") == book_id, "calibration bookID mismatch"
assert evidence.get("observedVideoSHA256", "").lower() == video_sha, "calibration video SHA mismatch"
assert evidence.get("observedPDFSHA256", "").lower() == pdf_sha, "calibration PDF SHA mismatch"
assert len(evidence.get("executionReportSHA256", "")) == 64, "missing execution-report SHA binding"
assert evidence.get("thresholdSweep"), "threshold sweep is empty"
print("GOLDEN_V3_CALIBRATION_EVIDENCE_BINDING_PASS")
PY

printf '%s\n' \
  "THRESHOLDLESS_CALIBRATION_READY" \
  "execution_report=$report" \
  "calibration_evidence=$calibration" \
  "next=HQ must inspect the real distributions/sweep/gaps and explicitly select a threshold; this script does not recommend or choose one."
