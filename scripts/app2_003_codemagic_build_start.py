#!/usr/bin/env python3
from __future__ import annotations
import json, os, urllib.request
from pathlib import Path

APP_ID='6a8af6e5a5c86907b00c2efd'
WORKFLOW_ID='yoru-ios'
BRANCH='main'

def main():
    cmd=json.loads(Path('/tmp/release-command.json').read_text(encoding='utf-8'))
    if cmd.get('action')!='build_yoru': raise SystemExit('action must be build_yoru')
    if cmd.get('app_id')!=APP_ID or cmd.get('workflow_id')!=WORKFLOW_ID or cmd.get('branch')!=BRANCH:
        raise SystemExit('pinned build parameters mismatch')
    token=os.environ.get('CM_API_TOKEN','').strip()
    if not token: raise SystemExit('CM_API_TOKEN unavailable')
    payload=json.dumps({'appId':APP_ID,'workflowId':WORKFLOW_ID,'branch':BRANCH}).encode()
    req=urllib.request.Request('https://api.codemagic.io/builds',data=payload,method='POST',headers={'x-auth-token':token,'Content-Type':'application/json','Accept':'application/json'})
    with urllib.request.urlopen(req,timeout=30) as r: d=json.load(r)
    build_id=d.get('buildId') or d.get('id')
    if not build_id: raise SystemExit('build id missing')
    result={'ok':True,'request_id':cmd.get('request_id'),'action':'build_yoru','app_id':APP_ID,'workflow_id':WORKFLOW_ID,'branch':BRANCH,'build_id':build_id,'version':'1.2.0','build_number':'5','review_submission':False}
    Path('release-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__': main()
