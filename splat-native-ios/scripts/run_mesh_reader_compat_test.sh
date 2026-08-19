#!/usr/bin/env bash
set -euo pipefail

method="${1:?XCTest method name is required}"
SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); ids=[d["udid"] for runtime,devices in data.get("devices",{}).items() if "iOS" in runtime for d in devices if d.get("isAvailable") and d.get("name","").startswith("iPhone")]; print(ids[0] if ids else "")')"
test -n "$SIMULATOR_ID"

xcodebuild -project SplatNative.xcodeproj -scheme SplatNativeTests \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test-without-building \
  -only-testing:"SplatNativeTests/MeshThirdPartyReaderCompatibilityTests/${method}"
