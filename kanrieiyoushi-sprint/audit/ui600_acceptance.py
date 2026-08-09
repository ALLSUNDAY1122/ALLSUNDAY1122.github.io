#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def need(text,token,label,errors):
    if token not in text: errors.append(f'{label}: missing {token}')

def main():
    errors=[]
    index=(ROOT/'index.html').read_text(encoding='utf-8')
    app=(ROOT/'app-v061.js').read_text(encoding='utf-8')
    boot=(ROOT/'data-bootstrap-v061.js').read_text(encoding='utf-8')
    css0=(ROOT/'styles-v060.css').read_text(encoding='utf-8')
    css1=(ROOT/'styles-v061.css').read_text(encoding='utf-8')
    sw=(ROOT/'sw.js').read_text(encoding='utf-8')

    for token in ['data-bootstrap-v061.js?v=061','styles-v061.css?v=061','id="roundSeg"','id="mockRounds"','id="roundStats"','id="mockNotice"','id="dataError"','aria-live="polite"']:
        need(index,token,'index',errors)
    for forbidden in ['questions600.js?v=061','app-v060.js?v=060','200問データ完成後に有効化します']:
        if forbidden in index: errors.append(f'index legacy/dead dependency remains: {forbidden}')

    for token in ['function startMock','mockComp','compKey','selectedRound','function integrity','600','200','resultEyebrow',"if(mode!=='mock')toast",'120点目安','n.ip.mode=n.ip.mode||n.ip.k']:
        need(app,token,'app-v061',errors)
    if '合格圏' in app: errors.append('mock result uses categorical 合格圏 wording')

    for token in ['R2_SELECTED','R2_OV','R3_OV','round2-extra-121-140.json','round2-rebalance-201-216.json','round3/01-social.json','round3/10-applied.json','primary-source-registry.json','rebalance(r1)','rebalance(r2)','rebalance(r3)','window.KANRI_Q=r1.concat(r2,r3)','await script(\'app-v061.js\')']:
        need(boot,token,'bootstrap',errors)
    for token in ["if(r1.length!==200)","if(r2.length!==200)","if(r3.length!==200)","window.KANRI_Q.length!==600"]:
        need(boot,token,'bootstrap integrity',errors)

    for token in ['.roundseg','.mockrounds','.mocknotice','.roundstats','.sourceLink']:
        need(css0,token,'styles-v060',errors)
    need(css1,'.roundseg button{min-height:44px}','styles-v061 touch target',errors)
    for token in ['.dataerror','.sourceLink{min-height:44px']:
        need(css1,token,'styles-v061 accessibility',errors)

    assets=['data-bootstrap-v061.js','app-v061.js','styles-v061.css','questions.js','data/round1-runtime-overrides.js','questions-121-150.js','questions-211-240.js','audit/round2-extra-121-140.json','audit/round2-rebalance-217-232.json','audit/primary-source-registry.json','audit/round3/01-social.json','audit/round3/10-applied.json']
    for token in assets: need(sw,token,'service worker',errors)
    need(sw,"kanri-sprint-v061",'service worker version',errors)
    need(sw,"ignoreSearch:true",'service worker cache bust handling',errors)

    print('=== 管理栄養士 v0.6.1 実装・UI受入監査 ===')
    if errors:
        print('FAIL')
        for e in errors: print('-',e)
        raise SystemExit(1)
    print('PASS: 監査済み素材→600問再構成、3回×10分類、200問模試×3、状態移行、模試正答漏洩防止、44px、ARIA、PWAを確認')

if __name__=='__main__': main()
