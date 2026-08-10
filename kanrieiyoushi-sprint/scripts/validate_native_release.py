#!/usr/bin/env python3
import hashlib,json,re,sys
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; IOS=ROOT/'ios'; NATIVE=IOS/'Resources/questions.native.json'; CANON=ROOT/'audit/data/questions.round1-2-3.canonical.json'
EXPECTED={'社会・環境':16,'人体・疾病':26,'食べ物':25,'基礎栄養':14,'応用栄養':16,'栄養教育':13,'臨床栄養':26,'公衆栄養':16,'給食経営':18,'応用力':30}; errors=[]
def need(c,m):
    if not c: errors.append(m)
def read(p): return p.read_text(encoding='utf-8')
payload=json.loads(NATIVE.read_text(encoding='utf-8')) if NATIVE.exists() else {'questions':[]}; native=payload.get('questions',[]); canon=json.loads(CANON.read_text(encoding='utf-8')) if CANON.exists() else []
need(payload.get('bundleID')=='jp.allsunday1122.kanrieiyoushi','bundle id mismatch'); need(payload.get('contentVersion')=='kanri-native-600-v1','contentVersion mismatch'); need(len(native)==600,f'native count {len(native)}/600'); need(len(canon)==600,f'canonical count {len(canon)}/600'); need(len({q.get('id') for q in native})==600,'native duplicate IDs'); need(sum(not q.get('premium',True) for q in native)==60,'free count must be 60')
free=Counter(q['subject'] for q in native if not q.get('premium',True)); need(dict(free)=={k:6 for k in EXPECTED},f'free split {dict(free)}')
by_round=defaultdict(Counter)
for q in native:
    m=re.fullmatch(r'第([123])回',q.get('examRound',''))
    if not m: errors.append(f"{q.get('id')}: invalid examRound"); continue
    by_round[int(m.group(1))][q.get('subject')]+=1; need(q.get('answerType')=='singleChoice',f"{q.get('id')}: answer type"); need(len(q.get('choices',[]))==5,f"{q.get('id')}: choices"); ci=q.get('correctIndices',[]); need(len(ci)==1 and isinstance(ci[0],int) and 0<=ci[0]<5,f"{q.get('id')}: correctIndices"); need(bool(q.get('memoryPoint')),f"{q.get('id')}: memoryPoint"); need(bool(q.get('explanation')),f"{q.get('id')}: explanation"); need(bool(re.fullmatch(r'\d{4}-\d{2}-\d{2}',q.get('sourceCheckedAt',''))),f"{q.get('id')}: sourceCheckedAt"); need(bool(re.fullmatch(r'\d{4}-\d{2}-\d{2}',q.get('lawBaselineDate',''))),f"{q.get('id')}: lawBaselineDate")
for r in (1,2,3): need(dict(by_round[r])==EXPECTED,f'round {r} distribution {dict(by_round[r])}')
cm={q['id']:q for q in canon}
for n in native:
    c=cm.get(n['id'])
    if not c: errors.append(f"{n['id']}: missing canonical"); continue
    for nk,ck in [('subject','subject'),('topic','topic'),('prompt','question'),('choices','choices')]: need(n.get(nk)==c.get(ck),f"{n['id']}: content changed {nk}")
    need(n.get('correctIndices')==[c.get('correct_index')],f"{n['id']}: correct answer changed")
swift_files=list((IOS/'KanriEiyoushiSprint').glob('*.swift')); swift='\n'.join(read(p) for p in swift_files if p.exists()); project=read(IOS/'project.yml') if (IOS/'project.yml').exists() else ''; cmagic=read(IOS/'codemagic-kanrieiyoushi.yml') if (IOS/'codemagic-kanrieiyoushi.yml').exists() else ''
need(swift_files,'native Swift source missing'); need('import WebKit' not in swift and 'WKWebView' not in swift,'WebKit/WKWebView found in native target')
for token in ['ホーム','模試','記録','設定','わからない','ここだけ覚える','JSONバックアップ','3連続正解']: need(token in swift,f'native UI marker missing: {token}')
for token in ['LearningSprintCore','Resources','KanriEiyoushiSprintTests','KanriEiyoushiSprintUITests','jp.allsunday1122.kanrieiyoushi']: need(token in project,f'project missing {token}')
need('path: Web' not in project,'Web folder remains in app resources')
for token in ['kanrieiyoushi_appstore','jp.allsunday1122.kanrieiyoushi','6799753841','testFlightInternalTestingOnly','submit_to_testflight: true','submit_to_app_store: false']: need(token in cmagic,f'Codemagic missing {token}')
if '--require-icon' in sys.argv:
    icon=IOS/'Assets.xcassets/AppIcon.appiconset/AppIcon.png'; need(icon.exists(),'canonical AppIcon missing')
    if icon.exists():
        actual=hashlib.sha256(icon.read_bytes()).hexdigest(); need(actual=='294481351106502f20958359d02bb2fb117ae18399654388425aad0e264fe31f',f'AppIcon SHA mismatch {actual}')
print('=== 管理栄養士 Native SwiftUI Release Audit ===')
if errors:
    print('FAIL'); [print('-',e) for e in errors]; sys.exit(1)
print('PASS: 600問同値、無料60、3回配分、SwiftUI native、4タブ、StoreKit/TestFlight契約を確認')
