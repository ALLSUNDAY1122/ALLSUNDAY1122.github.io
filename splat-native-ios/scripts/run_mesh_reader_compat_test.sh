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
trap 'rm -f "$log_file"' EXIT
run_test 2>&1 | tee "$log_file"

fbx_path="$(sed -n 's/.*SCANLAB_HOST_FBX=//p' "$log_file" | tr -d '\r' | tail -1)"
if [[ -z "$fbx_path" || ! -f "$fbx_path" ]]; then
  echo "FBX XCTest did not expose a readable host artifact path" >&2
  exit 1
fi

if ! command -v assimp >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install assimp
fi

# Use the complete macOS Assimp distribution as the independent reader. The embedded iOS
# XCFramework intentionally remains an exporter dependency and is not allowed to self-certify FBX.
assimp info "$fbx_path"
rm -rf "$(dirname "$fbx_path")"
echo "PASS: host Assimp independently reopened exported FBX"
