#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ios/KanriEiyoushiSprint.xcodeproj"
SCHEME="KanriEiyoushiSprint"
BUNDLE_ID="jp.allsunday1122.kanrieiyoushi"
LOG_DIR="${TMPDIR:-/tmp}/kanri-native-ui"
DERIVED="$LOG_DIR/DerivedData"
mkdir -p "$LOG_DIR"

IDS=()
while IFS= read -r id; do IDS+=("$id"); done < <(python3 - <<'PY'
import json,subprocess
raw=subprocess.check_output(['xcrun','simctl','list','-j','devices','available']);data=json.loads(raw);items=[]
for runtime,devices in data['devices'].items():
    if 'iOS' not in runtime: continue
    for d in devices:
        if d.get('isAvailable') and d.get('name','').startswith('iPhone'): items.append((d['name'],d['udid']))
large=['iPhone 17 Pro Max','iPhone 16 Pro Max','iPhone 16 Pro','iPhone 15 Pro Max']
small=['iPhone SE (3rd generation)','iPhone 13 mini','iPhone 16e','iPhone 15']
chosen=[]
for prefs in (large,small):
    found=None
    for name in prefs:
        found=next((x for x in items if x[0]==name and x[1] not in [c[1] for c in chosen]),None)
        if found: break
    if not found: found=next((x for x in items if x[1] not in [c[1] for c in chosen]),None)
    if found: chosen.append(found)
for _,udid in chosen[:2]: print(udid)
PY
)
[[ ${#IDS[@]} -ge 2 ]] || { echo "Need two available iPhone simulators" >&2; exit 1; }
LARGE="${IDS[0]}"; SMALL="${IDS[1]}"

boot_device() {
  local UDID="$1"
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  /usr/bin/python3 - "$UDID" <<'PY'
import subprocess, sys, time
udid = sys.argv[1]
for attempt in range(36):
    try:
        result = subprocess.run(
            ['xcrun', 'simctl', 'list', 'devices', 'available'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10
        )
        if result.returncode == 0 and udid in result.stdout and '(Booted)' in result.stdout:
            print(f'KANRI_SIMULATOR_BOOTED attempt={attempt + 1}')
            raise SystemExit(0)
    except subprocess.TimeoutExpired:
        print('KANRI_SIMCTL_LIST_TIMEOUT_RETRYING', file=sys.stderr)
    time.sleep(5)
print('KANRI_SIMULATOR_DID_NOT_BOOT_WITHIN_180S', file=sys.stderr)
raise SystemExit(124)
PY
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

boot_device "$LARGE"
echo "=== XCTest build-for-testing ==="
BUILD_LOG="$LOG_DIR/build-for-testing.log"
set +e
python3 - "$BUILD_LOG" "$PROJECT" "$SCHEME" "$LARGE" "$DERIVED" <<'PY'
import subprocess,sys
log,project,scheme,udid,derived=sys.argv[1:]
cmd=[
  'xcodebuild','build-for-testing','-project',project,'-scheme',scheme,
  '-destination',f'platform=iOS Simulator,id={udid}','-destination-timeout','45',
  '-derivedDataPath',derived,'-parallel-testing-enabled','NO',
  'CODE_SIGNING_ALLOWED=NO','ASSETCATALOG_COMPILER_APPICON_NAME='
]
with open(log,'wb') as f:
    try:
        result=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=600)
        raise SystemExit(result.returncode)
    except subprocess.TimeoutExpired:
        f.write(b'\nKANRI_BUILD_FOR_TESTING_HARD_TIMEOUT_600S\n')
        raise SystemExit(124)
PY
BUILD_STATUS=$?
set -e
if [[ $BUILD_STATUS -ne 0 ]]; then
  echo "=== build-for-testing FAILURE ===" >&2
  grep -E "KANRI_BUILD_FOR_TESTING_HARD_TIMEOUT|error:|BUILD FAILED|failed" "$BUILD_LOG" | tail -160 >&2 || true
  tail -80 "$BUILD_LOG" >&2 || true
  exit "$BUILD_STATUS"
fi
echo "=== build-for-testing PASS ==="

run_one() {
  local LABEL="$1"; local UDID="$2"; local TEST="$3"
  local LOG="$LOG_DIR/${LABEL}.log"
  echo "=== XCTest start: ${LABEL} ==="
  set +e
  python3 - "$LOG" "$PROJECT" "$SCHEME" "$UDID" "$TEST" "$DERIVED" <<'PY'
import subprocess,sys
log,project,scheme,udid,test,derived=sys.argv[1:]
cmd=[
  'xcodebuild','test-without-building','-project',project,'-scheme',scheme,
  '-destination',f'platform=iOS Simulator,id={udid},arch=arm64','-derivedDataPath',derived,
  '-destination-timeout','45','-parallel-testing-enabled','NO',
  '-test-timeouts-enabled','YES','-default-test-execution-time-allowance','75',
  '-maximum-test-execution-time-allowance','150',f'-only-testing:{test}',
  'CODE_SIGNING_ALLOWED=NO','ASSETCATALOG_COMPILER_APPICON_NAME='
]
with open(log,'wb') as f:
    try:
        result=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=180)
        raise SystemExit(result.returncode)
    except subprocess.TimeoutExpired:
        f.write(b'\nKANRI_XCTEST_HARD_TIMEOUT_180S\n')
        raise SystemExit(124)
PY
  local STATUS=$?
  set -e
  if [[ $STATUS -ne 0 ]]; then
    echo "=== ${LABEL} XCTest FAILURE status=${STATUS} ===" >&2
    grep -E "KANRI_XCTEST_HARD_TIMEOUT|Test Case .* (failed|passed)|Assertion Failure|XCTAssert|error:|timed out|Timeout|Failure|TEST FAILED|Executed [0-9]+ tests" "$LOG" | tail -180 >&2 || true
    tail -70 "$LOG" >&2 || true
    echo "=== end ${LABEL} XCTest FAILURE ===" >&2
    return "$STATUS"
  fi
  grep -E "Test Case .* passed|Executed [0-9]+ tests|TEST SUCCEEDED" "$LOG" | tail -30 || true
  echo "=== XCTest PASS: ${LABEL} ==="
}

run_one unit-large "$LARGE" "KanriEiyoushiSprintTests"
run_one ui-learning-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testFourTabsAndDailySprintImmediateScoring"
run_one ui-settings-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testSettingsExposeGoldenMasterControls"
run_one ui-mock-history-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testPremiumMockAndHistoryRoutes"
xcrun simctl shutdown "$LARGE" >/dev/null 2>&1 || true

boot_device "$SMALL"
run_one ui-learning-small "$SMALL" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testFourTabsAndDailySprintImmediateScoring"
xcrun simctl shutdown "$SMALL" >/dev/null 2>&1 || true
