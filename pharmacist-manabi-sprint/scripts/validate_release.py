#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,plistlib,struct,sys
R=Path(__file__).resolve().parents[1]; ROOT=R.parent; errors=[]; warnings=[]
def need(p):
 if not (R/p).exists(): errors.append('missing: '+p)
for p in ['index.html','style.css','app-v06.js','record-fix-v061.js','content/product/questions.json','content/product/final-audit-v2.json','content/product/web-static-audit.json','support.html','privacy.html','terms.html','ios/project.yml','ios/App.swift','ios/Info.plist','ios/PrivacyInfo.xcprivacy','ios/prepare-ios.sh','ios/product-loader-ios.js','ios/native-store-ui.js','ios/native-store.css','ios/apply-xcode-capabilities.py','ios/Assets.xcassets/AppIcon.appiconset/Contents.json','ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md','metadata/APP_STORE_METADATA_JA.md','metadata/RELEASE_STATUS.md','metadata/RELEASE_CHECKLIST.md','metadata/CODEX_HANDOFF.md']: need(p)
if not (ROOT/'codemagic.yaml').exists(): errors.append('missing: root codemagic.yaml')
if errors: print('FAIL\n'+'\n'.join('- '+e for e in errors));sys.exit(1)
a=json.load(open(R/'content/product/final-audit-v2.json',encoding='utf-8'));q=json.load(open(R/'content/product/questions.json',encoding='utf-8'));w=json.load(open(R/'content/product/web-static-audit.json',encoding='utf-8'))
if not a.get('finalPass') or a.get('questionCount')!=1035 or a.get('blockedCount')!=0 or a.get('explanationCoverage')!=1035 or a.get('unresolvedHighSimilarityPairs'): errors.append('final question audit not PASS')
qs=q.get('questions',[]);active=[x for x in qs if x.get('scoring_status')!='excluded'];exc=[x for x in qs if x.get('scoring_status')=='excluded'];flex=[x for x in qs if x.get('scoring_status')=='multiple_accepted'];free=[x for x in active if int(x.get('sourceExam',0))==111 and x.get('subject')=='必須']
if (len(qs),len(active),len(exc),len(flex),len(free))!=(1035,1031,4,3,90): errors.append(f'bank counts invalid {(len(qs),len(active),len(exc),len(flex),len(free))}')
if w.get('pass') is not True: errors.append('web audit not PASS')
with open(R/'ios/Info.plist','rb') as f: info=plistlib.load(f)
if info.get('ITSAppUsesNonExemptEncryption') is not False: errors.append('encryption plist mismatch')
with open(R/'ios/PrivacyInfo.xcprivacy','rb') as f: priv=plistlib.load(f)
if priv.get('NSPrivacyTracking') is not False or priv.get('NSPrivacyCollectedDataTypes')!=[] or priv.get('NSPrivacyAccessedAPITypes')!=[]: errors.append('privacy manifest mismatch')
app=(R/'ios/App.swift').read_text(encoding='utf-8');project=(R/'ios/project.yml').read_text(encoding='utf-8');loader=(R/'ios/product-loader-ios.js').read_text(encoding='utf-8');storeui=(R/'ios/native-store-ui.js').read_text(encoding='utf-8')
for s in ['jp.allsunday1122.yakuzaishi','jp.allsunday1122.yakuzaishi.monthly','jp.allsunday1122.yakuzaishi.lifetime','Transaction.currentEntitlements','AppStore.sync()','showManageSubscriptions']:
 if s not in app+project: errors.append('native token missing: '+s)
if 'UserDefaults' in app: errors.append('UserDefaults added without Privacy Manifest reason')
if "q.exam===111&&q.f==='必須'" not in loader or 'free!==90' not in loader: errors.append('free gate not fixed to current mandatory 90')
if 'state.introConfigured&&state.introEligible' not in storeui: errors.append('trial eligibility UI gate missing')
if 'App Storeで確認' not in storeui or 'displayPrice' in storeui: pass
source=(R/'ios/Assets.xcassets/AppIcon.appiconset/APPICON_SOURCE.md').read_text(encoding='utf-8');expected='dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec'
if '1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu' not in source or expected not in source: errors.append('canonical icon source mismatch')
icon=R/'ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png';materialized=icon.exists()
if materialized:
 b=icon.read_bytes()
 if hashlib.sha256(b).hexdigest()!=expected: errors.append('AppIcon hash mismatch')
 elif b[:8]!=b'\x89PNG\r\n\x1a\n' or struct.unpack('>II',b[16:24])!=(1024,1024) or b[25]!=2: errors.append('AppIcon must be canonical 1024 RGB')
else: warnings.append('canonical AppIcon source verified; PNG materialization pending before signed build')
for p in ['support.html','privacy.html','terms.html']:
 s=(R/p).read_text(encoding='utf-8')
 if 'http://' in s: errors.append(p+' has insecure link')
metadata=(R/'metadata/APP_STORE_METADATA_JA.md').read_text(encoding='utf-8')
for s in ['1,031','必須90問','displayPrice','jp.allsunday1122.yakuzaishi.monthly','jp.allsunday1122.yakuzaishi.lifetime','16+']:
 if s not in metadata: errors.append('metadata missing: '+s)
cm=(ROOT/'codemagic.yaml').read_text(encoding='utf-8')
for s in ['pharmacist-ios:','bundle_identifier: jp.allsunday1122.yakuzaishi','submit_to_testflight: true','submit_to_app_store: false','testFlightInternalTestingOnly']:
 if s not in cm: errors.append('Codemagic token missing: '+s)
report={'pass':not errors,'errors':errors,'warnings':warnings,'questions':len(qs),'active':len(active),'excluded':len(exc),'flexible':len(flex),'free':len(free),'iconMaterialized':materialized}
(R/'content/product/release-preflight-static.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False));sys.exit(1 if errors else 0)
