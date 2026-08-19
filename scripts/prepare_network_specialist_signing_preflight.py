#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'codemagic.yaml'
text = path.read_text(encoding='utf-8')
marker = '\n  network-specialist-signing-preflight:\n'
if marker in text:
    print('network-specialist-signing-preflight already present')
    raise SystemExit(0)

block = r'''

  network-specialist-signing-preflight:
    name: ネットワークスペシャリスト - Apple Signing Preflight
    max_build_duration: 20
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: "Codemagic Shiwake Swipe"
    environment:
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
      - name: Initialize signing keychain
        script: keychain initialize
      - name: Fetch or create App Store signing files
        script: app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
      - name: Add signing certificate to keychain
        script: keychain add-certificates
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: false
        submit_to_app_store: false
'''
path.write_text(text.rstrip() + block + '\n', encoding='utf-8')
print('added network-specialist-signing-preflight')
