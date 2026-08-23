#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULT_DIR="${1:-${TMPDIR:-/tmp}/scanner-parity-product-apple}"
BUILD_DIR="$RESULT_DIR/build"
LOG="$RESULT_DIR/compile.log"
REPORT="$RESULT_DIR/report.json"
TARGET="${PRODUCT_APPLE_TARGET:-arm64-apple-ios17.0}"
STATUS="FAIL"
DETAIL=""
mkdir -p "$BUILD_DIR"
: > "$LOG"

finish() {
  local code=$?
  python3 - "$REPORT" "$STATUS" "$code" "$TARGET" "${XCODE_VERSION:-unavailable}" "${SWIFT_VERSION:-unavailable}" "${SDK_VERSION:-unavailable}" "$DETAIL" <<'PY'
import json, sys
from pathlib import Path
path,status,code,target,xcode,swift,sdk,detail=sys.argv[1:]
Path(path).write_text(json.dumps({
  "schema_version":1,"status":status,"exit_code":int(code),"target":target,
  "xcode_version":xcode,"swift_version":swift,"iphoneos_sdk_version":sdk,
  "modules":["ProductFlow","AppShell"],"golden_decision":None,
  "failure_detail":detail or None
}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
PY
}
trap finish EXIT
trap 'DETAIL="line ${LINENO}: ${BASH_COMMAND}"' ERR

if [[ "$(uname -s)" != "Darwin" ]]; then
  DETAIL="iPhoneOS compile requires a macOS runner with Xcode."
  echo "$DETAIL" | tee -a "$LOG" >&2
  exit 20
fi
for cmd in xcrun xcodebuild python3; do command -v "$cmd" >/dev/null || { DETAIL="missing command: $cmd"; exit 21; }; done
SWIFTC="$(xcrun --find swiftc)"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ';')"
SWIFT_VERSION="$($SWIFTC --version | tr '\n' ';')"

PRODUCT_SOURCES=("$ROOT"/ProductFlow/Sources/ProductFlow/*.swift)
APP_SOURCES=("$ROOT"/AppShell/Sources/AppShell/*.swift)

echo "== ProductFlow iPhoneOS module ==" | tee -a "$LOG"
"$SWIFTC" -sdk "$SDK" -target "$TARGET" -parse-as-library -module-name ProductFlow \
  -emit-module -emit-module-path "$BUILD_DIR/ProductFlow.swiftmodule" \
  "${PRODUCT_SOURCES[@]}" 2>&1 | tee -a "$LOG"

echo "== AppShell iPhoneOS module ==" | tee -a "$LOG"
"$SWIFTC" -sdk "$SDK" -target "$TARGET" -parse-as-library -module-name AppShell \
  -I "$BUILD_DIR" -emit-module -emit-module-path "$BUILD_DIR/AppShell.swiftmodule" \
  "${APP_SOURCES[@]}" 2>&1 | tee -a "$LOG"

STATUS="PASS"
DETAIL=""
echo "PRODUCT_APPLE_SDK_COMPILE_PASS" | tee -a "$LOG"
