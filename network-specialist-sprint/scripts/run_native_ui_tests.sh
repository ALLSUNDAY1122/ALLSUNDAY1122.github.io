#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ios/NetworkSpecialist.xcodeproj"
SCHEME="NetworkSpecialist"
DERIVED_DATA="${TMPDIR:-/tmp}/network-specialist-derived-data"
LOG_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
mkdir -p "$LOG_DIR"

IDS=()
while IFS= read -r id; do
  IDS+=("$id")
done < <(python3 - <<'PY'
import json, re, subprocess

sdk = subprocess.check_output(
    ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True
).strip()
sdk_match = re.match(r'^(\d+)(?:\.(\d+))?', sdk)
if not sdk_match:
    raise SystemExit(f'Unable to parse iPhone Simulator SDK version: {sdk}')
sdk_major = int(sdk_match.group(1))
sdk_minor = int(sdk_match.group(2) or 0)

raw = subprocess.check_output(['xcrun','simctl','list','-j','devices','available'])
data = json.loads(raw)
items=[]
for runtime, devices in data['devices'].items():
    m = re.search(r'SimRuntime\.iOS-(\d+)-(\d+)', runtime)
    if not m:
        continue
    runtime_version = (int(m.group(1)), int(m.group(2)))
    # Xcode 16.4 can coexist with newer runtimes on GitHub-hosted runners.
    # Never choose a simulator runtime newer than the active Xcode SDK.
    if runtime_version > (sdk_major, sdk_minor):
        continue
    for d in devices:
        if d.get('isAvailable') and d.get('name','').startswith('iPhone'):
            items.append((runtime_version, d['name'], d['udid']))

if not items:
    raise SystemExit(f'No iPhone simulator compatible with active SDK {sdk}')

# Prefer the newest runtime that is not newer than the active SDK, then choose
# one large and one small phone within that same runtime for deterministic tests.
best_runtime = max(x[0] for x in items)
items = [(name, udid) for runtime, name, udid in items if runtime == best_runtime]
preferred_large=['iPhone 16 Pro Max','iPhone 16 Pro','iPhone 15 Pro Max','iPhone 15 Pro','iPhone 17 Pro Max']
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

print(f'NETWORK_SIMULATOR_RUNTIME_SELECTED iOS {best_runtime[0]}.{best_runtime[1]} for SDK {sdk}', file=__import__('sys').stderr)
for name, udid in chosen[:2]:
    print(udid)
PY
)

if [[ ${#IDS[@]} -lt 2 ]]; then
  echo "Need two compatible iPhone simulators for large/small Visual Gate" >&2
  exit 1
fi

boot_device() {
  local udid="$1"
  /usr/bin/python3 - "$udid" <<'PY'
import subprocess, sys
udid = sys.argv[1]
try:
    subprocess.run(['xcrun', 'simctl', 'boot', udid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
except subprocess.TimeoutExpired:
    print('NETWORK_SIMCTL_BOOT_HARD_TIMEOUT_30S', file=sys.stderr)
    raise SystemExit(124)
# "Booted" in simctl list is not sufficient: wait until SpringBoard/services are ready.
try:
    result = subprocess.run(
        ['xcrun', 'simctl', 'bootstatus', udid, '-b'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120
    )
except subprocess.TimeoutExpired:
    print('NETWORK_SIMULATOR_BOOTSTATUS_HARD_TIMEOUT_120S', file=sys.stderr)
    raise SystemExit(124)
if result.returncode != 0:
    print(result.stdout, file=sys.stderr)
    raise SystemExit(result.returncode)
print('NETWORK_SIMULATOR_BOOT_READY')
PY
}

run_xcodebuild_logged() {
  local phase="$1"
  local timeout_seconds="$2"
  shift 2
  local log="$LOG_DIR/network-specialist-${phase}.log"
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

run_xcodebuild_logged "build-for-testing" 900 \
  xcodebuild build-for-testing \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=${IDS[0]}" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME=

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
