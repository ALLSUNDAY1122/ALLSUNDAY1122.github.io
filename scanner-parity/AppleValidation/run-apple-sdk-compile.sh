#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_DIR="$ROOT_DIR/scanner-parity/AppleValidation"
RESULT_DIR="${1:-$VALIDATION_DIR/.results}"
BUILD_DIR="$RESULT_DIR/build"
LOG_FILE="$RESULT_DIR/compile.log"
REPORT_FILE="$RESULT_DIR/report.json"
TARGET="${APPLE_VALIDATION_TARGET:-arm64-apple-ios17.0}"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS="FAIL"
FAILURE_DETAIL=""

mkdir -p "$BUILD_DIR"
: > "$LOG_FILE"

json_report() {
  local exit_code="$1"
  local finished_at
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 - "$REPORT_FILE" "$STATUS" "$exit_code" "$STARTED_AT" "$finished_at" "$TARGET" "${XCODE_VERSION:-unavailable}" "${SWIFT_VERSION:-unavailable}" "${SDK_PATH:-unavailable}" "${SDK_VERSION:-unavailable}" "$FAILURE_DETAIL" <<'PY'
import json
import sys
from pathlib import Path

(
    report_path,
    status,
    exit_code,
    started_at,
    finished_at,
    target,
    xcode_version,
    swift_version,
    sdk_path,
    sdk_version,
    failure_detail,
) = sys.argv[1:]

report = {
    "schema_version": 1,
    "status": status,
    "exit_code": int(exit_code),
    "started_at": started_at,
    "finished_at": finished_at,
    "target": target,
    "xcode_version": xcode_version,
    "swift_version": swift_version,
    "iphoneos_sdk_path": sdk_path,
    "iphoneos_sdk_version": sdk_version,
    "modules": ["FrameExtraction", "ImageCorrection", "PageAudit"],
    "contract_probe": "AppleAdapterContractProbe.swift",
    "formal_golden_decision": None,
    "failure_detail": failure_detail or None,
}
Path(report_path).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

on_exit() {
  local code=$?
  if [[ $code -ne 0 && -z "$FAILURE_DETAIL" ]]; then
    FAILURE_DETAIL="compile harness exited with code $code"
  fi
  json_report "$code" || true
}
trap on_exit EXIT
trap 'FAILURE_DETAIL="line ${LINENO}: ${BASH_COMMAND}"' ERR

if [[ "$(uname -s)" != "Darwin" ]]; then
  FAILURE_DETAIL="Apple SDK validation requires macOS/Darwin."
  echo "$FAILURE_DETAIL" | tee -a "$LOG_FILE" >&2
  exit 20
fi

for command in xcrun xcodebuild python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    FAILURE_DETAIL="required command missing: $command"
    echo "$FAILURE_DETAIL" | tee -a "$LOG_FILE" >&2
    exit 21
  fi
done

SWIFTC="$(xcrun --find swiftc)"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ';' | sed 's/;$//')"
SWIFT_VERSION="$($SWIFTC --version | tr '\n' ';' | sed 's/;$//')"

{
  echo "xcode=$XCODE_VERSION"
  echo "swift=$SWIFT_VERSION"
  echo "iphoneos_sdk=$SDK_VERSION"
  echo "target=$TARGET"
} | tee -a "$LOG_FILE"

compile_module() {
  local module="$1"
  shift
  local -a sources=("$@")
  echo "== compile module: $module ==" | tee -a "$LOG_FILE"
  for source in "${sources[@]}"; do
    if [[ ! -f "$source" ]]; then
      FAILURE_DETAIL="missing source for $module: ${source#$ROOT_DIR/}"
      echo "$FAILURE_DETAIL" | tee -a "$LOG_FILE" >&2
      return 22
    fi
  done

  "$SWIFTC" \
    -sdk "$SDK_PATH" \
    -target "$TARGET" \
    -parse-as-library \
    -module-name "$module" \
    -emit-module \
    -emit-module-path "$BUILD_DIR/$module.swiftmodule" \
    "${sources[@]}" 2>&1 | tee -a "$LOG_FILE"
}

compile_module FrameExtraction \
  "$ROOT_DIR/scanner-parity/FrameExtraction/FrameExtractionModels.swift" \
  "$ROOT_DIR/scanner-parity/FrameExtraction/StableFrameSelector.swift" \
  "$ROOT_DIR/scanner-parity/FrameExtraction/AVFoundationStableFrameExtractor.swift"

compile_module ImageCorrection \
  "$ROOT_DIR/scanner-parity/ImageCorrection/CorrectionCore.swift" \
  "$ROOT_DIR/scanner-parity/ImageCorrection/ApplePageCorrectionEngine.swift"

compile_module PageAudit \
  "$ROOT_DIR/scanner-parity/PageAudit/PageAuditModels.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/PageNumberScorer.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/PageIntegrityAuditor.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/PageAuditReportFormatter.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/PagePerceptualHasher.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/PageAuditInputFactory.swift" \
  "$ROOT_DIR/scanner-parity/PageAudit/VisionPageAuditRecognizer.swift"

echo "== cross-module Apple contract probe ==" | tee -a "$LOG_FILE"
"$SWIFTC" \
  -sdk "$SDK_PATH" \
  -target "$TARGET" \
  -I "$BUILD_DIR" \
  -typecheck \
  "$VALIDATION_DIR/AppleAdapterContractProbe.swift" 2>&1 | tee -a "$LOG_FILE"

STATUS="PASS"
FAILURE_DETAIL=""
echo "APPLE_SDK_COMPILE_PASS" | tee -a "$LOG_FILE"
