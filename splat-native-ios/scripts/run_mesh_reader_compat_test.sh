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
host_fbx="/tmp/scanlab-external-reader-$$.fbx"
cleanup() {
  rm -f "$log_file" "$host_fbx"
}
trap cleanup EXIT

run_test 2>&1 | tee "$log_file"

# xcodebuild may prefix XCTest stdout. Capture only the emitted .fbx path, then read the file
# from the same simulator namespace that produced it instead of guessing CoreSimulator host paths.
simulator_fbx="$(sed -n 's/^.*SCANLAB_HOST_FBX=\(.*\.fbx\).*$/\1/p' "$log_file" | tr -d '\r' | tail -1)"
if [[ -z "$simulator_fbx" ]]; then
  echo "FAIL: FBX XCTest did not emit SCANLAB_HOST_FBX" >&2
  exit 1
fi

echo "Copying simulator FBX to host: $simulator_fbx"
if ! xcrun simctl spawn "$SIMULATOR_ID" /bin/cat "$simulator_fbx" > "$host_fbx"; then
  echo "FAIL: simctl could not read exported FBX: $simulator_fbx" >&2
  exit 1
fi

fbx_size="$(wc -c < "$host_fbx" | tr -d ' ')"
if [[ -z "$fbx_size" || "$fbx_size" -le 100 ]]; then
  echo "FAIL: copied FBX payload is implausibly small (${fbx_size:-0} bytes)" >&2
  exit 1
fi

if ! command -v assimp >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install assimp
fi

# The embedded iOS XCFramework is an exporter dependency. A complete macOS Assimp installation
# independently certifies that the emitted FBX can be consumed outside the app process.
echo "Running independent host Assimp reader against $host_fbx ($fbx_size bytes)"
assimp info "$host_fbx"
echo "PASS: host Assimp independently reopened exported FBX"
