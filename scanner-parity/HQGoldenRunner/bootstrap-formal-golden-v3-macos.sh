#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git"
INTEGRATION_REF="scanner-parity/integration"
VIDEO_SHA="8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677"
PDF_SHA="4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32"
VIDEO_SIZE=191911175
PDF_SIZE=25751801
BOOK_ID="golden-v3-user-confirmed-20260825"

input_dir=""
workspace_root="${HOME}/scanner-parity-golden-v3"

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
    --input-dir) input_dir="$value" ;;
    --workspace-root) workspace_root="$value" ;;
    *)
      echo "Unsupported bootstrap argument: $key" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$input_dir" ]]; then
  echo "Usage: $0 --input-dir <folder-containing-Golden-video-and-PDF> [--workspace-root <private-local-dir>]" >&2
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Formal Golden v3 requires macOS. This bootstrap refuses non-macOS execution." >&2
  exit 3
fi

for tool in git python3 swift xcrun; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required macOS tool: $tool" >&2
    exit 3
  fi
done
xcrun --sdk macosx --show-sdk-path >/dev/null

if [[ ! -d "$input_dir" ]]; then
  echo "Golden input directory does not exist: $input_dir" >&2
  exit 3
fi
input_dir="$(cd "$input_dir" && pwd -P)"
mkdir -p "$workspace_root"
workspace_root="$(cd "$workspace_root" && pwd -P)"

repo_dir="$workspace_root/repo"
if [[ -d "$repo_dir/.git" ]]; then
  origin="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  case "$origin" in
    "$REPO_URL"|"https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io") ;;
    *)
      echo "Dedicated bootstrap repo has unexpected origin: $origin" >&2
      exit 3
      ;;
  esac
  git -C "$repo_dir" fetch --prune origin "$INTEGRATION_REF"
else
  if [[ -e "$repo_dir" ]]; then
    echo "Workspace repo path exists but is not a Git repository: $repo_dir" >&2
    exit 3
  fi
  git clone --single-branch --branch "$INTEGRATION_REF" "$REPO_URL" "$repo_dir"
fi

git -C "$repo_dir" checkout -B "$INTEGRATION_REF" "origin/$INTEGRATION_REF"
git -C "$repo_dir" reset --hard "origin/$INTEGRATION_REF"
git -C "$repo_dir" clean -fd
repo_head="$(git -C "$repo_dir" rev-parse HEAD)"

bindings="$workspace_root/golden-v3-input-bindings.json"
python3 - "$input_dir" "$bindings" "$VIDEO_SHA" "$PDF_SHA" "$VIDEO_SIZE" "$PDF_SIZE" "$BOOK_ID" <<'PY'
import hashlib
import json
import os
import sys
from pathlib import Path

input_dir, output_path, video_sha, pdf_sha, video_size, pdf_size, book_id = sys.argv[1:]
video_size = int(video_size)
pdf_size = int(pdf_size)
root = Path(input_dir)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def exact_match(expected_size: int, expected_sha: str):
    candidates = []
    for entry in root.iterdir():
        try:
            if entry.is_file() and entry.stat().st_size == expected_size:
                if digest(entry).lower() == expected_sha.lower():
                    candidates.append(entry.resolve())
        except OSError:
            continue
    if len(candidates) != 1:
        raise SystemExit(
            f"Expected exactly one Golden file matching size={expected_size} sha256={expected_sha}; found {len(candidates)}"
        )
    return candidates[0]

video = exact_match(video_size, video_sha)
pdf = exact_match(pdf_size, pdf_sha)
if video == pdf:
    raise SystemExit("Golden video and PDF resolved to the same file")

payload = {
    "schemaVersion": 1,
    "bookID": book_id,
    "videoPath": str(video),
    "videoSHA256": video_sha,
    "pdfPath": str(pdf),
    "pdfSHA256": pdf_sha,
    "privacy": "LOCAL_ONLY_DO_NOT_UPLOAD_RAW_OR_DERIVED_BOOK_CONTENT",
}
Path(output_path).write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print("GOLDEN_V3_RAW_IDENTITY_BINDING_PASS")
PY

video="$(python3 - "$bindings" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["videoPath"])
PY
)"
pdf="$(python3 - "$bindings" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["pdfPath"])
PY
)"

timestamp="$(date '+%Y%m%d-%H%M%S')"
run_root="$workspace_root/runs/$timestamp"
thresholdless_workspace="$run_root/thresholdless"
mkdir -p "$run_root"

preflight="$repo_dir/scanner-parity/HQGoldenRunner/run-formal-golden-v3-thresholdless-and-calibrate.sh"
if [[ ! -f "$preflight" ]]; then
  echo "Integrated Golden v3 thresholdless helper is missing from checkout." >&2
  exit 3
fi

bash "$preflight" \
  --video "$video" \
  --pdf "$pdf" \
  --workspace "$thresholdless_workspace"

execution="$thresholdless_workspace/hq-golden-execution.json"
calibration="$thresholdless_workspace/hq-golden-calibration-evidence.json"
if [[ ! -f "$execution" || ! -f "$calibration" ]]; then
  echo "Thresholdless bootstrap did not produce the required sanitized HQ evidence files." >&2
  exit 4
fi

state="$run_root/hq-golden-local-state.json"
python3 - "$state" "$repo_head" "$BOOK_ID" "$thresholdless_workspace" "$execution" "$calibration" <<'PY'
import json
import sys
from pathlib import Path

state, repo_head, book_id, workspace, execution, calibration = sys.argv[1:]
payload = {
    "schemaVersion": 1,
    "bookID": book_id,
    "integrationHEAD": repo_head,
    "phase": "THRESHOLDLESS_CALIBRATION_READY",
    "thresholdlessWorkspace": workspace,
    "executionReport": execution,
    "calibrationEvidence": calibration,
    "next": "HQ_INSPECT_REAL_CALIBRATION_AND_AUTHOR_SHA_BOUND_THRESHOLD_DECISION",
}
Path(state).write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
printf '%s\n' "$run_root" > "$workspace_root/latest-run.txt"

printf '%s\n' \
  "GOLDEN_V3_MACOS_BOOTSTRAP_THRESHOLDLESS_COMPLETE" \
  "integration_head=$repo_head" \
  "book_id=$BOOK_ID" \
  "run_root=$run_root" \
  "execution_report=$execution" \
  "calibration_evidence=$calibration" \
  "next=Provide only the sanitized execution/calibration JSON files to HQ. Keep raw video, PDF, review bundle, OCR text, and derived page images local."
