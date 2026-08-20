#!/usr/bin/env bash
set -euo pipefail

method="${1:?XCTest method name is required}"
SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); ids=[d["udid"] for runtime,devices in data.get("devices",{}).items() if "iOS" in runtime for d in devices if d.get("isAvailable") and d.get("name","").startswith("iPhone")]; print(ids[0] if ids else "")')"
test -n "$SIMULATOR_ID"

run_test() {
  xcodebuild -project SplatNative.xcodeproj -scheme SplatNativeTests \
    -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test-without-building \
    -only-testing:"SplatNativeTests/MeshThirdPartyReaderCompatibilityTests/${method}"
}

if [[ "$method" != "testFBXReopensThroughAssimp" ]]; then
  run_test
  exit 0
fi

log_file="$(mktemp)"
host_b64="$(mktemp)"
host_fbx="/tmp/scanlab-external-reader-$$.fbx"
cleanup() {
  rm -f "$log_file" "$host_b64" "$host_fbx"
}
trap cleanup EXIT

run_test 2>&1 | tee "$log_file"

# The simulator test emits the exact FBX bytes as base64. Decode those bytes on the macOS host
# instead of depending on CoreSimulator's private filesystem/container path mapping.
sed -n 's/^.*SCANLAB_HOST_FBX_BASE64=\([A-Za-z0-9+\/=]*\).*$/\1/p' "$log_file" \
  | tr -d '\r' \
  | tail -1 > "$host_b64"

if [[ ! -s "$host_b64" ]]; then
  echo "FAIL: FBX XCTest did not emit SCANLAB_HOST_FBX_BASE64" >&2
  exit 1
fi

python3 - "$host_b64" "$host_fbx" <<'PY'
import base64
import pathlib
import sys

encoded = pathlib.Path(sys.argv[1]).read_text(encoding="ascii").strip()
if not encoded:
    raise SystemExit("FAIL: empty FBX base64 payload")
try:
    payload = base64.b64decode(encoded, validate=True)
except Exception as exc:
    raise SystemExit(f"FAIL: invalid FBX base64 payload: {exc}") from exc
pathlib.Path(sys.argv[2]).write_bytes(payload)
PY

fbx_size="$(wc -c < "$host_fbx" | tr -d ' ')"
if [[ -z "$fbx_size" || "$fbx_size" -le 100 ]]; then
  echo "FAIL: decoded FBX payload is implausibly small (${fbx_size:-0} bytes)" >&2
  exit 1
fi

if ! command -v assimp >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install assimp
fi

# The embedded iOS XCFramework is only the exporter dependency. A complete macOS Assimp install
# independently certifies that the emitted FBX is consumable outside the app process.
echo "Running independent host Assimp reader against $host_fbx ($fbx_size bytes)"
assimp info "$host_fbx"
echo "PASS: host Assimp independently reopened exported FBX"
