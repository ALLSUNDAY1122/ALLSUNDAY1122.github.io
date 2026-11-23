#!/usr/bin/env python3
from pathlib import Path
import re, sys

p = Path('fp2-manabi-sprint/index.html')
if not p.exists():
    raise SystemExit('FAIL: fp2-manabi-sprint/index.html missing')
s = p.read_text(encoding='utf-8')

fail=[]

def require(label, cond):
    if not cond: fail.append(label)

# Generation lock: FP2 itself must not remain the obsolete v1.3/3-tab reference.
forbidden = ['FP2 v1.3 UI検証版','FP2 v1.3｜GitHub復旧・UI検証版','UI基準：FP2 v1.3']
for x in forbidden:
    require(f'forbidden legacy marker remains: {x}', x not in s)

# Golden Master v2.1 common contract.
require('v2.1 identity missing', ('v2.1' in s or 'Golden Master' in s))
require('4-tab navigation missing: home/mock/history/settings', all(x in s for x in ['ホーム','模試','記録','設定']))
require('standard 8-question sprint missing', '8問' in s)
require('4/8/16 sprint setting missing', all(x in s for x in ['4','8','16']) and ('4／8／16' in s or '4/8/16' in s or all(f'data-goal="{n}"' in s for n in (4,8,16))))
require('resume journey missing', '続きから' in s)
require('weakness graduation missing', '3連続正解' in s)
require('mock exam journey missing', '模試' in s)
require('progress/achievement visualization missing', any(x in s for x in ['達成度','progress-ring','donut','todayArc']))
require('5-week heatmap missing', ('5週間' in s and 'ヒートマップ' in s) or 'heatmap' in s.lower())
require('JSON export/import missing', ('JSON' in s and any(x in s for x in ['書き出し','エクスポート','export'])) and any(x in s for x in ['読み込み','インポート','import']))
require('offline/PWA requirement missing', ('serviceWorker.register' in s and 'manifest.webmanifest' in s and Path('fp2-manabi-sprint/service-worker.js').exists()))
require('reduced-motion handling missing', 'prefers-reduced-motion' in s)

# Product-data guard: the public product cannot be promoted while it still self-identifies as an 8-question UI-only sample.
require('UI-only sample marker remains', '公開状態：Safari UI検証版（独自表現8問）' not in s)
require('obsolete 600-question placeholder remains', '製品版データは別途600問監査後に置換します' not in s)
# The bank size must be read and independently validated from the audited release JSON,
# not inferred from any number mentioned in an HTML page.

if fail:
    print('FP2 Golden Master v2.1 migration gate: FAIL')
    for x in fail: print('-',x)
    print(f'failures={len(fail)}')
    sys.exit(1)
print('FP2 Golden Master v2.1 migration gate: PASS')
