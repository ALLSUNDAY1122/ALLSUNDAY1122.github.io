#!/usr/bin/env python3
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'codemagic.yaml'
text = path.read_text(encoding='utf-8')
marker = '\n  network-specialist-signing-preflight:\n'

canonical = r'''

  network-specialist-signing-preflight:
    name: ネットワークスペシャリスト - Apple Signing Preflight
    max_build_duration: 20
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: networkspecialist_appstore
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: jp.allsunday1122.networkspecialist
      vars:
        BUNDLE_ID: jp.allsunday1122.networkspecialist
        APP_STORE_CONNECT_APP_ID: "6799754573"
        CODEMAGIC_PROFILE_REF: networkspecialist_appstore
        IAP_PRODUCT_ID: jp.allsunday1122.networkspecialist.premium
      xcode: latest
    scripts:
      - name: Verify canonical identifiers
        script: |
          set -euo pipefail
          test "$BUNDLE_ID" = 'jp.allsunday1122.networkspecialist'
          test "$APP_STORE_CONNECT_APP_ID" = '6799754573'
          test "$CODEMAGIC_PROFILE_REF" = 'networkspecialist_appstore'
          test "$IAP_PRODUCT_ID" = 'jp.allsunday1122.networkspecialist.premium'
      - name: Verify Codemagic automatic signing assets
        script: |
          set -euo pipefail
          security find-identity -v -p codesigning
          PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
          test -d "$PROFILE_DIR"
          test -n "$(find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.mobileprovision' -print -quit)"
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
'''

if marker not in text:
    path.write_text(text.rstrip() + canonical + '\n', encoding='utf-8')
    print('added canonical network-specialist-signing-preflight')
    raise SystemExit(0)

start = text.index(marker)
search_from = start + len(marker)
next_match = re.search(r'(?m)^  [A-Za-z0-9][A-Za-z0-9_.-]*:\s*$', text[search_from:])
end = search_from + next_match.start() if next_match else len(text)
old = text[start:end]
new = canonical.rstrip('\n') + '\n'
if old == new:
    print('network-specialist-signing-preflight already canonical')
    raise SystemExit(0)
path.write_text(text[:start] + new + text[end:], encoding='utf-8')
print('repaired network-specialist-signing-preflight to app-specific integration and automatic signing')
