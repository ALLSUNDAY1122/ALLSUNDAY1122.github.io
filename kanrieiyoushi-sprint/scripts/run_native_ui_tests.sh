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

run_tests() {
  local LABEL="$1"; local UDID="$2"; shift 2
  local LOG="$LOG_DIR/${LABEL}.log"
  echo "=== XCTest start: ${LABEL} ==="
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  set +e
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -destination-timeout 60 \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 45 \
    -maximum-test-execution-time-allowance 75 \
    "$@" \
    CODE_SIGNING_ALLOWED=NO \
    ASSETCATALOG_COMPILER_APPICON_NAME= \
    >"$LOG" 2>&1
  local STATUS=$?
  set -e
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  if [[ $STATUS -ne 0 ]]; then
    echo "=== ${LABEL} XCTest FAILURE ===" >&2
    grep -E "Test Case .* (failed|passed)|Assertion Failure|XCTAssert|error:|timed out|Timeout|Failure|TEST FAILED|Executed [0-9]+ tests" "$LOG" | tail -220 >&2 || true
    echo "--- last 80 log lines ---" >&2
    tail -80 "$LOG" >&2 || true
    echo "=== end ${LABEL} XCTest FAILURE ===" >&2
    return "$STATUS"
  fi
  grep -E "Test Case .* passed|Executed [0-9]+ tests|TEST SUCCEEDED" "$LOG" | tail -80 || true
  echo "=== XCTest PASS: ${LABEL} ==="
}

run_tests large "${IDS[0]}" \
  -only-testing:KanriEiyoushiSprintTests \
  -only-testing:KanriEiyoushiSprintUITests

run_tests small "${IDS[1]}" \
  -only-testing:KanriEiyoushiSprintUITests/KanriEiyoushiSprintUITests/testFourTabsAndDailySprintImmediateScoring
