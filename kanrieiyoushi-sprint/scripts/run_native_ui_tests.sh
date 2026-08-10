#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT="$ROOT/ios/KanriEiyoushiSprint.xcodeproj"; SCHEME="KanriEiyoushiSprint"; BUNDLE_ID="jp.allsunday1122.kanrieiyoushi"
IDS=(); while IFS= read -r id; do IDS+=("$id"); done < <(python3 - <<'PY'
import json,subprocess
raw=subprocess.check_output(['xcrun','simctl','list','-j','devices','available']);data=json.loads(raw);items=[]
for runtime,devices in data['devices'].items():
    if 'iOS' not in runtime: continue
    for d in devices:
        if d.get('isAvailable') and d.get('name','').startswith('iPhone'): items.append((d['name'],d['udid']))
large=['iPhone 17 Pro Max','iPhone 16 Pro Max','iPhone 16 Pro','iPhone 15 Pro Max'];small=['iPhone SE (3rd generation)','iPhone 13 mini','iPhone 16e','iPhone 15'];chosen=[]
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
for UDID in "${IDS[@]}"; do
  xcrun simctl boot "$UDID" >/dev/null 2>&1 || true; xcrun simctl bootstatus "$UDID" -b; xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$UDID" -destination-timeout 90 -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 180 -only-testing:KanriEiyoushiSprintTests -only-testing:KanriEiyoushiSprintUITests CODE_SIGNING_ALLOWED=NO ASSETCATALOG_COMPILER_APPICON_NAME=
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
done
