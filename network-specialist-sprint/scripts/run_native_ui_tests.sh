#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/ios/NetworkSpecialist.xcodeproj"
SCHEME="NetworkSpecialist"

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

run_test_suite() {
  local udid="$1"
  local log="${TMPDIR:-/tmp}/network-specialist-ui-$udid.log"
  echo "=== XCTest start: $udid ==="
  set +e
  /usr/bin/python3 - "$log" "$PROJECT" "$SCHEME" "$udid" <<'PY'
import subprocess, sys
log, project, scheme, udid = sys.argv[1:]
cmd = [
    'xcodebuild', 'test',
    '-project', project,
    '-scheme', scheme,
    '-destination', f'platform=iOS Simulator,id={udid}',
    '-destination-timeout', '60',
    '-parallel-testing-enabled', 'NO',
    '-test-timeouts-enabled', 'YES',
    '-default-test-execution-time-allowance', '60',
    '-maximum-test-execution-time-allowance', '120',
    '-only-testing:NetworkSpecialistTests',
    '-only-testing:NetworkSpecialistUITests',
    'CODE_SIGNING_ALLOWED=NO',
    'ASSETCATALOG_COMPILER_APPICON_NAME=',
]
with open(log, 'wb') as output:
    try:
        result = subprocess.run(cmd, stdout=output, stderr=subprocess.STDOUT, timeout=540)
        raise SystemExit(result.returncode)
    except subprocess.TimeoutExpired:
        output.write(b'\nNETWORK_XCODEBUILD_HARD_TIMEOUT_540S\n')
        raise SystemExit(124)
PY
  local status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    echo "=== XCTest FAILURE status=$status ===" >&2
    grep -E 'NETWORK_XCODEBUILD_HARD_TIMEOUT|Test Case .* (failed|passed)|Assertion Failure|XCTAssert|error:|timed out|Timeout|Failure|TEST FAILED|Executed [0-9]+ tests' "$log" | tail -180 >&2 || true
    tail -100 "$log" >&2 || true
    return "$status"
  fi
  grep -E 'Test Case .* passed|Executed [0-9]+ tests|TEST SUCCEEDED' "$log" | tail -60 || true
  echo "=== XCTest PASS: $udid ==="
}

for UDID in "${IDS[@]}"; do
  boot_device "$UDID"
  run_test_suite "$UDID"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
done
