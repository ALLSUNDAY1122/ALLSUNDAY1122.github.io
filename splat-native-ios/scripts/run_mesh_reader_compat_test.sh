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
host_fbx=""
cleanup() {
  rm -f "$log_file"
  if [[ -n "$host_fbx" ]]; then
    rm -f "$host_fbx"
  fi
}
trap cleanup EXIT

# The path printed by XCTest belongs to the simulator namespace and is not guaranteed to be a
# directly readable macOS host path. Record the start time so the host can resolve only the FBX
# artifact produced by this exact test invocation from the selected simulator's data directory.
test_started_at="$(date +%s)"
run_test 2>&1 | tee "$log_file"

simulator_fbx="$(sed -n 's/.*SCANLAB_HOST_FBX=//p' "$log_file" | tr -d '\r' | tail -1)"
if [[ -z "$simulator_fbx" ]]; then
  echo "FAIL: FBX XCTest did not emit SCANLAB_HOST_FBX" >&2
  exit 1
fi

simulator_data_root="$HOME/Library/Developer/CoreSimulator/Devices/$SIMULATOR_ID/data"
fbx_basename="$(basename "$simulator_fbx")"
host_source_fbx="$(python3 - "$simulator_data_root" "$fbx_basename" "$test_started_at" <<'PY'
import os
import sys

root, basename, started_at = sys.argv[1], sys.argv[2], float(sys.argv[3])
candidates = []
for dirpath, _dirnames, filenames in os.walk(root):
    if basename not in filenames or "mesh-third-party-reader-" not in dirpath:
        continue
    path = os.path.join(dirpath, basename)
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        continue
    # Allow a small timestamp-resolution skew while rejecting stale artifacts from earlier runs.
    if mtime >= started_at - 2:
        candidates.append((mtime, path))

if candidates:
    print(max(candidates)[1])
PY
)"

if [[ -z "$host_source_fbx" || ! -f "$host_source_fbx" ]]; then
  echo "FAIL: host could not resolve simulator FBX artifact: $simulator_fbx" >&2
  exit 1
fi

host_fbx="/tmp/scanlab-external-reader-$$.fbx"
cp "$host_source_fbx" "$host_fbx"

if ! command -v assimp >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install assimp
fi

# Use the complete macOS Assimp distribution as the independent reader. The embedded iOS
# XCFramework intentionally remains an exporter dependency and is not allowed to self-certify FBX.
echo "Running independent host Assimp reader against $host_fbx"
assimp info "$host_fbx"
rm -rf "$(dirname "$host_source_fbx")"
echo "PASS: host Assimp independently reopened exported FBX"
