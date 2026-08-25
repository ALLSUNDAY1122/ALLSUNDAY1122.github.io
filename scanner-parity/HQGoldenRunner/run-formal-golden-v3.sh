#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_PATH/.." && pwd)"
LAUNCHER="$SCRIPT_DIR/run-formal-golden.sh"
REFERENCE_MANIFEST="$REPO_ROOT/automation/chatgpt-dispatcher/scanner-parity/evidence/golden-v3-reference-corpus.json"

VIDEO_SHA="8334cc4b3116b92f25541fe8144bff850b15808846ada4ce7dc7a998576c1677"
PDF_SHA="4fae66be8ba95549859bbc5f9f1fc433ebe1a3a8b6c078cbd3317cf0e78e7b32"
BOOK_ID="golden-v3-user-confirmed-20260825"

video=""
pdf=""
workspace=""
match_threshold=""

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
    --match-threshold) match_threshold="$value" ;;
    *)
      echo "Unsupported Golden v3 argument: $key" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$video" || -z "$pdf" || -z "$workspace" ]]; then
  echo "Golden v3 launcher requires --video, --pdf, and --workspace." >&2
  exit 2
fi
if [[ ! -f "$REFERENCE_MANIFEST" ]]; then
  echo "Golden v3 reference manifest is missing from the checked-out repository." >&2
  exit 2
fi

args=(
  --video "$video"
  --pdf "$pdf"
  --workspace "$workspace"
  --book-id "$BOOK_ID"
  --expected-video-sha "$VIDEO_SHA"
  --expected-pdf-sha "$PDF_SHA"
  --reference-corpus-manifest "$REFERENCE_MANIFEST"
)
if [[ -n "$match_threshold" ]]; then
  args+=(--match-threshold "$match_threshold")
fi

exec bash "$LAUNCHER" "${args[@]}"
