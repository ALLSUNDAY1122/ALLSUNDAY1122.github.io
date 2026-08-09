#!/usr/bin/env python3
from pathlib import Path
import re,sys
ROOT=Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf-8')
def need(text,token,label,errors):
    if token not in text: errors.append(f'{label}: missing {token}')
errors=[]
swift=read('ios/App.swift');js=read('ios/native-storekit.js');prep=read('ios/prepare-ios.sh');project=read('ios/project.yml');cm=read('ios/codemagic-kanrieiyoushi.yml');preflight=read('validate-apple-preflight.mjs')
for token in ['jp.allsunday1122.kanrieiyoushi.premium','Product.products(for:','displayPrice','Transaction.currentEntitlements','Transaction.updates','AppStore.sync()','case .pending','case .userCancelled','revocationDate == nil','loadFileURL','allowingReadAccessTo']:
    need(swift,token,'App.swift',errors)
for bad in ['UserDefaults','980円','¥980','￥980']:
    if bad in swift: errors.append('App.swift forbidden: '+bad)
for token in ['window.KANRI_NATIVE_STORE','無料版では第1回の各分野6問、合計60問','全600問','data-restore','data-settings-restore','aria-modal="true"','min-width:44px','displayPrice','showPaywall','startFreeToday','startFreeSubject','startFreeWeak']:
    need(js,token,'native-storekit.js',errors)
if re.search(r'[¥￥]\s*980|980\s*円',js): errors.append('native-storekit.js hard-coded candidate price')
for token in ['native-storekit.js','__KANRI_NATIVE_API','nativeFreePool','n<6','startFreeToday','startFreeSubject','startFreeWeak','11d72Dl76UH7QvU8Gxl-SgDjTV73GaxP4','726223','simulator-placeholder']:
    need(prep,token,'prepare-ios.sh',errors)
for token in ['PRODUCT_BUNDLE_IDENTIFIER: jp.allsunday1122.kanrieiyoushi','CFBundleDisplayName: 管理栄養士 学びスプリント','PrivacyInfo.xcprivacy','Web']:
    need(project,token,'project.yml',errors)
for token in ['testFlightInternalTestingOnly','submit_to_testflight: false','submit_to_app_store: false','jp.allsunday1122.kanrieiyoushi']:
    need(cm,token,'codemagic',errors)
for p in ['privacy/index.html','support/index.html','ios/PrivacyInfo.xcprivacy','app-store/APPLE_CONNECT_PACKET.md','app-store/APP_REVIEW_NOTES_JA.md','app-store/APP_STORE_METADATA_JA.md','app-store/STOREKIT_TEST_PLAN.md','ios/HARSH_REVIEW.md']:
    if not (ROOT/p).exists(): errors.append('missing release artifact: '+p)
need(preflight,'displayPrice-only UI','preflight',errors)
# DOMContentLoaded must prepare UI only; it must not auto-open the paywall.
m=re.search(r"document\.addEventListener\('DOMContentLoaded'.*?\}\);",js,re.S)
if m and 'showPaywall()' in m.group(0): errors.append('paywall opens automatically at launch')
# Restore is allowed only after explicit JS action reaches Swift.
if 'case "restore": await store.restore()' not in swift: errors.append('restore not bound to explicit bridge action')
# Web source remains unrestricted; native gate is injected only by prepare-ios.sh.
index=read('index.html')
if 'native-storekit.js' in index: errors.append('GitHub Pages index must not include native StoreKit gate')
print('=== 管理栄養士 StoreKit 2 / iOS製品化監査 ===')
if errors:
    print('FAIL');[print('-',e) for e in errors];sys.exit(1)
print('PASS: one-time StoreKit 2, displayPrice, purchase/restore/pending/revocation, native-only 60/600 gate, local WKWebView, privacy/support and safe TestFlight contract')
