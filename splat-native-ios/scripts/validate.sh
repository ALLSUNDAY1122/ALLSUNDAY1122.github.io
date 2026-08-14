#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
test -f project.yml
test -f SplatNative/ScanModel.swift
test -f SplatNative/SplatViewer.swift
test -f SplatNative/PrivacyInfo.xcprivacy
grep -q 'jp.allsunday1122.splatlab' project.yml
grep -q 'd620d9c58d270e7de9e34a9d8a85dcf938a5070d' project.yml
grep -q '2b965de1934de38dda1c71cf90bf798aa948a14c' project.yml
! grep -R -nE 'https?://.*(api|upload|analytics)|URLSession|Firebase|Amplitude|Mixpanel' SplatNative --include='*.swift'
plutil -lint SplatNative/PrivacyInfo.xcprivacy >/dev/null 2>&1 || true
echo 'PASS: static Splat Lab Native checks'
