#!/usr/bin/env python3
"""Create a replacement AI Handover App Store profile on the shared MLD certificate."""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, api_request, load_private_key, make_token

COMMAND=Path('automation/app2-010-ai-handover-protect-command.json')
OUTPUT=Path('asc-ai-handover-protect-result.json')
BUNDLE_RESOURCE_ID='B7R8MY8GK8'
CERTIFICATE_ID='MLDDAKTU69'
PROFILE_NAME='AI_Handover_Log_AppStore_MLD'
PROFILE_TYPE='IOS_APP_STORE'


def data_one(response,label):
    data=response.get('data') if isinstance(response,dict) else None
    if not isinstance(data,dict): raise RuntimeError(f'{label}: expected single data resource')
    return data


def data_list(response):
    data=response.get('data') if isinstance(response,dict) else None
    return [x for x in data if isinstance(x,dict)] if isinstance(data,list) else []


def attrs(resource):
    value=resource.get('attributes') if isinstance(resource,dict) else None
    return value if isinstance(value,dict) else {}


def main():
    command=json.loads(COMMAND.read_text(encoding='utf-8'))
    request_id=str(command.get('request_id',''))
    expected={
        'bundle_resource_id':BUNDLE_RESOURCE_ID,
        'certificate_id':CERTIFICATE_ID,
        'profile_name':PROFILE_NAME,
        'profile_type':PROFILE_TYPE,
    }
    if not request_id.startswith('app2-010-ai-handover-protect-'): raise RuntimeError('unexpected request id')
    for k,v in expected.items():
        if str(command.get(k))!=v: raise RuntimeError(f'command mismatch: {k}')
    issuer=os.environ.get('ASC_ISSUER_ID'); kid=os.environ.get('ASC_KEY_ID')
    if not issuer or not kid: raise RuntimeError('missing ASC credential identifiers')
    key_path,cleanup=load_private_key()
    try:
        token=make_token(issuer,kid,key_path)
        _,bundle_resp=api_get(token,f'/v1/bundleIds/{BUNDLE_RESOURCE_ID}')
        bundle=data_one(bundle_resp,'bundle')
        _,cert_resp=api_get(token,f'/v1/certificates/{CERTIFICATE_ID}')
        cert=data_one(cert_resp,'certificate')
        ca=attrs(cert)
        if ca.get('activated') is False: raise RuntimeError('certificate inactive')
        if ca.get('certificateType') not in {'DISTRIBUTION','IOS_DISTRIBUTION'}: raise RuntimeError('certificate is not distribution')

        _,profiles=api_get(token,f'/v1/profiles?filter[name]={PROFILE_NAME}&limit=20')
        existing=next((p for p in data_list(profiles) if attrs(p).get('name')==PROFILE_NAME),None)
        changed=False
        if existing is None:
            payload={'data':{'type':'profiles','attributes':{'name':PROFILE_NAME,'profileType':PROFILE_TYPE},'relationships':{'bundleId':{'data':{'type':'bundleIds','id':BUNDLE_RESOURCE_ID}},'certificates':{'data':[{'type':'certificates','id':CERTIFICATE_ID}]}}}}
            status,response=api_request(token,'/v1/profiles',method='POST',payload=payload)
            if status!=201: raise RuntimeError(f'unexpected create status {status}')
            existing=data_one(response,'created profile'); changed=True
        profile_id=str(existing.get('id'))
        _,rb=api_get(token,f'/v1/profiles/{profile_id}')
        profile=data_one(rb,'profile')
        pa=attrs(profile)
        if pa.get('profileState')!='ACTIVE': raise RuntimeError('replacement profile is not ACTIVE')
        _,rb_bundle=api_get(token,f'/v1/profiles/{profile_id}/bundleId')
        if str(data_one(rb_bundle,'profile bundle').get('id'))!=BUNDLE_RESOURCE_ID: raise RuntimeError('bundle relation mismatch')
        _,rb_certs=api_get(token,f'/v1/profiles/{profile_id}/certificates')
        cert_ids={str(x.get('id')) for x in data_list(rb_certs)}
        if CERTIFICATE_ID not in cert_ids: raise RuntimeError('certificate relation mismatch')
        result={
            'request_id':request_id,'completed_at':datetime.now(timezone.utc).isoformat(),'ok':True,'changed':changed,
            'bundle_resource_id':BUNDLE_RESOURCE_ID,'bundle_name':attrs(bundle).get('name'),
            'certificate_id':CERTIFICATE_ID,'certificate_name':ca.get('name'),'certificate_expiration':ca.get('expirationDate'),
            'profile_id':profile_id,'profile_name':pa.get('name'),'profile_type':pa.get('profileType'),'profile_state':pa.get('profileState'),'profile_expiration':pa.get('expirationDate'),
            'relationship_certificate_ids':sorted(cert_ids),
        }
        OUTPUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(f'PASS: protected AI Handover with profile {profile_id}')
    finally:
        if cleanup: cleanup.unlink(missing_ok=True)

if __name__=='__main__': main()
