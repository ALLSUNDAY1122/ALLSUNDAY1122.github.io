#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ios/KanriEiyoushiSprint.xcodeproj"
SCHEME="KanriEiyoushiSprint"
BUNDLE_ID="jp.allsunday1122.kanrieiyoushi"
LOG_DIR="${TMPDIR:-/tmp}/kanri-native-ui"
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

boot_device() {
  local UDID="$1"
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

run_one() {
  local LABEL="$1"; local UDID="$2"; local TEST="$3"
  local LOG="$LOG_DIR/${LABEL}.log"
  echo "=== XCTest start: ${LABEL} ==="
  set +e
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -destination-timeout 45 \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 35 \
    -maximum-test-execution-time-allowance 60 \
    -only-testing:"$TEST" \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME= \
    >"$LOG" 2>&1
  local STATUS=$?
  set -e
  if [[ $STATUS -ne 0 ]]; then
    echo "=== ${LABEL} XCTest FAILURE ===" >&2
    grep -E "Test Case .* (failed|passed)|Assertion Failure|XCTAssert|error:|timed out|Timeout|Failure|TEST FAILED|Executed [0-9]+ tests" "$LOG" | tail -160 >&2 || true
    tail -60 "$LOG" >&2 || true
    echo "=== end ${LABEL} XCTest FAILURE ===" >&2
    return "$STATUS"
  fi
  grep -E "Test Case .* passed|Executed [0-9]+ tests|TEST SUCCEEDED" "$LOG" | tail -30 || true
  echo "=== XCTest PASS: ${LABEL} ==="
}

LARGE="${IDS[0]}"; SMALL="${IDS[1]}"
boot_device "$LARGE"
run_one unit-large "$LARGE" "KanriEiyoushiSprintTests"
run_one ui-learning-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testFourTabsAndDailySprintImmediateScoring"
run_one ui-settings-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testSettingsExposeGoldenMasterControls"
run_one ui-mock-history-large "$LARGE" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testPremiumMockAndHistoryRoutes"
xcrun simctl shutdown "$LARGE" >/dev/null 2>&1 || true

boot_device "$SMALL"
run_one ui-learning-small "$SMALL" "KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testFourTabsAndDailySprintImmediateScoring"
xcrun simctl shutdown "$SMALL" >/dev/null 2>&1 || true
