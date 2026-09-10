#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ios/NetworkSpecialist.xcodeproj"
SCHEME="NetworkSpecialist"
DERIVED_DATA="${TMPDIR:-/tmp}/network-specialist-derived-data"

IDS=()
while IFS= read -r id; do
  IDS+=("$id")
done < <(python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(['xcrun','simctl','list','-j','devices','available'])
data = json.loads(raw)
items=[]
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable') and d.get('name','').startswith('iPhone'):
            items.append((d['name'], d['udid']))
preferred_large=['iPhone 17 Pro Max','iPhone 16 Pro Max','iPhone 16 Pro','iPhone 15 Pro Max','iPhone 15 Pro']
preferred_small=['iPhone SE (3rd generation)','iPhone 13 mini','iPhone 16e','iPhone 15']
chosen=[]
for prefs in (preferred_large, preferred_small):
    found=None
    for name in prefs:
        found=next((x for x in items if x[0]==name and x[1] not in [c[1] for c in chosen]), None)
        if found: break
    if not found:
        found=next((x for x in items if x[1] not in [c[1] for c in chosen]), None)
    if found: chosen.append(found)
for name, udid in chosen[:2]:
    print(udid)
PY
)

if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "No available iPhone simulators" >&2
  exit 1
fi

boot_device() {
  local udid="$1"
  /usr/bin/python3 - "$udid" <<'PY'
import subprocess, sys, time
udid = sys.argv[1]
try:
    subprocess.run(['xcrun', 'simctl', 'boot', udid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
except subprocess.TimeoutExpired:
    print('NETWORK_SIMCTL_BOOT_HARD_TIMEOUT_30S', file=sys.stderr)
    raise SystemExit(124)
for attempt in range(36):
    try:
        result = subprocess.run(
            ['xcrun', 'simctl', 'list', 'devices', 'available'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10
        )
        if result.returncode == 0 and udid in result.stdout and '(Booted)' in result.stdout:
            print(f'NETWORK_SIMULATOR_BOOTED attempt={attempt + 1}')
            raise SystemExit(0)
    except subprocess.TimeoutExpired:
        print('NETWORK_SIMCTL_LIST_TIMEOUT_RETRYING', file=sys.stderr)
    time.sleep(5)
print('NETWORK_SIMULATOR_DID_NOT_BOOT_WITHIN_180S', file=sys.stderr)
raise SystemExit(124)
PY
}

run_xcodebuild_logged() {
  local phase="$1"
  local timeout_seconds="$2"
  shift 2
  local log="${TMPDIR:-/tmp}/network-specialist-${phase}.log"
  echo "=== XCTest ${phase} start ==="
  set +e
  /usr/bin/python3 - "$log" "$timeout_seconds" "$@" <<'PY'
import subprocess, sys
log = sys.argv[1]
timeout_seconds = int(sys.argv[2])
cmd = sys.argv[3:]
with open(log, 'wb') as output:
    try:
        result = subprocess.run(cmd, stdout=output, stderr=subprocess.STDOUT, timeout=timeout_seconds)
        raise SystemExit(result.returncode)
    except subprocess.TimeoutExpired:
        output.write(f'\nNETWORK_XCODEBUILD_HARD_TIMEOUT_{timeout_seconds}S\n'.encode())
        raise SystemExit(124)
PY
  local status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "=== XCTest ${phase} FAILURE status=$status ===" >&2
    grep -E 'NETWORK_XCODEBUILD_HARD_TIMEOUT|Test Case .* (failed|passed)|Assertion Failure|XCTAssert|error:|timed out|Timeout|Failure|TEST FAILED|Executed [0-9]+ tests' "$log" | tail -220 >&2 || true
    tail -120 "$log" >&2 || true
    return "$status"
  fi
  grep -E 'Test Case .* passed|Executed [0-9]+ tests|TEST SUCCEEDED|BUILD SUCCEEDED' "$log" | tail -80 || true
  echo "=== XCTest ${phase} PASS ==="
}

rm -rf "$DERIVED_DATA"
mkdir -p "$DERIVED_DATA"

# Build the app and both test bundles exactly once. Keep compilation outside all
# per-device test timeouts so a slow build cannot masquerade as a hung journey.
run_xcodebuild_logged "build-for-testing" 600 \
  xcodebuild build-for-testing \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=${IDS[0]}" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME=

# Unit tests are device-size independent. Run them once, then run each UI journey
# independently on both phone sizes. A single stalled journey now fails with its
# own phase name instead of consuming the whole 420s suite timeout.
boot_device "${IDS[0]}"
run_xcodebuild_logged "unit-${IDS[0]}" 180 \
  xcodebuild test-without-building \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=${IDS[0]}" \
    -destination-timeout 60 \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 120 \
    -only-testing:NetworkSpecialistTests \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME=
xcrun simctl shutdown "${IDS[0]}" >/dev/null 2>&1 || true

UI_TESTS=(
  "NetworkSpecialistUITests/NetworkSpecialistUITests/testCoreLearningFlowAndFourTabs"
  "NetworkSpecialistUITests/NetworkSpecialistUITests/testFreeUserCannotEnterPremiumTabs"
  "NetworkSpecialistUITests/NetworkSpecialistUITests/testPremiumMockHidesImmediateCorrectness"
  "NetworkSpecialistUITests/NetworkSpecialistUITests/testPremiumHistorySettingsAndLargeTextStayInsidePhoneWidth"
)

for UDID in "${IDS[@]}"; do
  boot_device "$UDID"
  for TEST_ID in "${UI_TESTS[@]}"; do
    TEST_NAME="${TEST_ID##*/}"
    run_xcodebuild_logged "ui-${UDID}-${TEST_NAME}" 150 \
      xcodebuild test-without-building \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$UDID" \
        -destination-timeout 60 \
        -derivedDataPath "$DERIVED_DATA" \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled YES \
        -default-test-execution-time-allowance 60 \
        -maximum-test-execution-time-allowance 120 \
        -only-testing:"$TEST_ID" \
        CODE_SIGNING_ALLOWED=NO \
        ASSETCATALOG_COMPILER_APPICON_NAME=
  done
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
done
