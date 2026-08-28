#!/usr/bin/env python3
from __future__ import annotations
import json, os, urllib.request
from pathlib import Path

APP_ID='6a8af6e5a5c86907b00c2efd'
BRANCH='main'
ALLOWED_WORKFLOWS={
    'yoru-ios': {'build_number':'6','distribution':'INTERNAL_ONLY'},
    'yoru-ios-appstore': {'build_number':'7','distribution':'APP_STORE'},
}

def main():
    cmd=json.loads(Path('/tmp/release-command.json').read_text(encoding='utf-8'))
    if cmd.get('action')!='build_yoru': raise SystemExit('action must be build_yoru')
    workflow_id=cmd.get('workflow_id')
    if cmd.get('app_id')!=APP_ID or workflow_id not in ALLOWED_WORKFLOWS or cmd.get('branch')!=BRANCH:
        raise SystemExit('pinned build parameters mismatch')
    token=os.environ.get('CM_API_TOKEN','').strip()
    if not token: raise SystemExit('CM_API_TOKEN unavailable')
    payload=json.dumps({'appId':APP_ID,'workflowId':workflow_id,'branch':BRANCH}).encode()
    req=urllib.request.Request('https://api.codemagic.io/builds',data=payload,method='POST',headers={'x-auth-token':token,'Content-Type':'application/json','Accept':'application/json'})
    with urllib.request.urlopen(req,timeout=30) as r: d=json.load(r)
    build_id=d.get('buildId') or d.get('id')
    if not build_id: raise SystemExit('build id missing')
    cfg=ALLOWED_WORKFLOWS[workflow_id]
    result={'ok':True,'request_id':cmd.get('request_id'),'action':'build_yoru','app_id':APP_ID,'workflow_id':workflow_id,'branch':BRANCH,'build_id':build_id,'version':'1.2.0','build_number':cfg['build_number'],'distribution':cfg['distribution'],'review_submission':False}
    Path('release-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__': main()
