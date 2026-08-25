#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
ARGS=("$@")

video=""
pdf=""
workspace=""
book_id="golden-v2-current-project-20260823"
expected_video_sha=""
expected_pdf_sha=""
reference_corpus_manifest=""

index=0
while (( index < ${#ARGS[@]} )); do
  key="${ARGS[$index]}"
  if (( index + 1 >= ${#ARGS[@]} )); then
    echo "Missing value for $key" >&2
    exit 2
  fi
  value="${ARGS[$((index + 1))]}"
  case "$key" in
    --video) video="$value" ;;
    --pdf) pdf="$value" ;;
    --workspace) workspace="$value" ;;
    --book-id) book_id="$value" ;;
    --expected-video-sha) expected_video_sha="$value" ;;
    --expected-pdf-sha) expected_pdf_sha="$value" ;;
    --reference-corpus-manifest) reference_corpus_manifest="$value" ;;
  esac
  index=$((index + 2))
done

if [[ -z "$video" || -z "$pdf" || -z "$workspace" ]]; then
  echo "Formal Golden launcher requires --video, --pdf, and explicit --workspace." >&2
  exit 2
fi

if [[ -n "$reference_corpus_manifest" ]]; then
  if [[ ! -f "$reference_corpus_manifest" ]]; then
    echo "Configured reference-corpus manifest is missing: $reference_corpus_manifest" >&2
    exit 2
  fi
  export SCANNER_GOLDEN_REFERENCE_MANIFEST="$reference_corpus_manifest"
fi

stderr_log="$(mktemp "${TMPDIR:-/tmp}/scanner-hq-golden-stderr.XXXXXX")"
cleanup() {
  rm -f "$stderr_log"
}
trap cleanup EXIT

set +e
swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-runner "${ARGS[@]}" 2> >(tee "$stderr_log" >&2)
runner_status=$?
set -e

if (( runner_status != 0 )); then
  recorder_args=(
    --video "$video"
    --pdf "$pdf"
    --workspace "$workspace"
    --book-id "$book_id"
    --stderr-log "$stderr_log"
    --runner-exit-code "$runner_status"
  )
  if [[ -n "$expected_video_sha" ]]; then
    recorder_args+=(--expected-video-sha "$expected_video_sha")
  fi
  if [[ -n "$expected_pdf_sha" ]]; then
    recorder_args+=(--expected-pdf-sha "$expected_pdf_sha")
  fi

  if ! swift run --package-path "$PACKAGE_PATH" scanner-hq-golden-failure-recorder "${recorder_args[@]}"; then
    echo "[HQGolden] WARNING: failure recorder could not persist failure evidence." >&2
  fi
fi

exit "$runner_status"
