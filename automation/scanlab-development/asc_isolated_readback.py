# Scan Lab isolated Apple state readback; copied/adapted from S17.
# Security: Apple credentials via CI secrets; no credentials written to files/repository.
# Group names are considered internal metadata; output artifact restricted to Actions access.
import base64, json, os, subprocess, tempfile, time, urllib.parse, urllib.request, urllib.error
from pathlib import Path

cmd=json.loads(Path('automation/scanlab-development/asc-readback-trigger.json').read_text(encoding='utf-8'))
expected_bundle='jp.allsunday1122.splatlab'
if cmd.get('app_id') != '6803778932':
    raise SystemExit('Apple app ID mismatch')
if cmd.get('bundle_id') != expected_bundle:
    raise SystemExit('bundle id mismatch')
if cmd.get('read_only') is not True:
    raise SystemExit('readback must remain read-only')

issuer=os.environ.get('ASC_ISSUER_ID','').strip()
key_id=os.environ.get('ASC_KEY_ID','').strip()
key_text=os.environ.get('ASC_PRIVATE_KEY','')
if not issuer or not key_id or not key_text:
    raise SystemExit('missing App Store Connect credentials')

def b64url(data): return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')
def der_len(data,pos):
    first=data[pos]; pos+=1
    if first < 0x80: return first,pos
    count=first & 0x7f
    if count == 0 or count > 4 or pos+count > len(data): raise ValueError('bad DER length')
    return int.from_bytes(data[pos:pos+count],'big'), pos+count
def der_to_jose(sig,size=32):
    pos=0
    if sig[pos] != 0x30: raise ValueError('bad DER sequence')
    pos+=1; seq,pos=der_len(sig,pos)
    if pos+seq != len(sig): raise ValueError('bad DER sequence length')
    vals=[]
    for _ in range(2):
        if sig[pos] != 0x02: raise ValueError('bad DER integer')
        pos+=1; n,pos=der_len(sig,pos); v=sig[pos:pos+n]; pos+=n
        while len(v)>1 and v[0]==0: v=v[1:]
        vals.append(v.rjust(size,b'\0'))
    return vals[0]+vals[1]

tmp=tempfile.NamedTemporaryFile('w',encoding='utf-8',delete=False)
tmp.write(key_text.replace('\\n','\n')); tmp.close(); os.chmod(tmp.name,0o600)
try:
    now=int(time.time())
    h=b64url(json.dumps({'alg':'ES256','kid':key_id,'typ':'JWT'},separators=(',',':')).encode())
    p=b64url(json.dumps({'iss':issuer,'iat':now,'exp':now+600,'aud':'appstoreconnect-v1'},separators=(',',':')).encode())
    signing=f'{h}.{p}'.encode('ascii')
    proc=subprocess.run(['openssl','dgst','-sha256','-sign',tmp.name],input=signing,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    token=f'{h}.{p}.{b64url(der_to_jose(proc.stdout))}'
finally:
    Path(tmp.name).unlink(missing_ok=True)

base='https://api.appstoreconnect.apple.com'
def get(path):
    req=urllib.request.Request(base+path,headers={'Authorization':'Bearer '+token,'Accept':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            return json.loads(r.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        body=e.read().decode('utf-8','replace')[:1200]
        raise SystemExit(f'ASC HTTP {e.code}: {body}')

bundle=urllib.parse.quote(expected_bundle,safe='')
apps=get(f'/v1/apps?filter[bundleId]={bundle}&fields[apps]=name,bundleId&limit=5').get('data') or []
apps=[a for a in apps if (a.get('attributes') or {}).get('bundleId') == expected_bundle]
if len(apps) != 1:
    raise SystemExit(f'expected exactly one Scan Lab ASC app, got {len(apps)}')
app=apps[0]; app_id=str(app['id']); attrs=app.get('attributes') or {}

builds=get(f'/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5&fields[builds]=version,uploadedDate,expirationDate,processingState,expired,buildAudienceType,usesNonExemptEncryption').get('data') or []
out_builds=[]
for b in builds:
    bid=str(b.get('id')); ba=b.get('attributes') or {}; detail={}
    try:
        d=get(f'/v1/builds/{bid}/buildBetaDetail?fields[buildBetaDetails]=internalBuildState,externalBuildState').get('data') or {}
        detail=d.get('attributes') or {}
    except SystemExit:
        detail={'internalBuildState':'READ_ERROR','externalBuildState':'READ_ERROR'}
    out_builds.append({
        'id':bid,
        'version':ba.get('version'),
        'uploadedDate':ba.get('uploadedDate'),
        'processingState':ba.get('processingState'),
        'expired':ba.get('expired'),
        'buildAudienceType':ba.get('buildAudienceType'),
        'usesNonExemptEncryption':ba.get('usesNonExemptEncryption'),
        'internalBuildState':detail.get('internalBuildState'),
        'externalBuildState':detail.get('externalBuildState'),
    })

# Internal beta group and actual build linkage readback (no mutation).
# A group with hasAccessToAllBuilds still needs the build linkage to be verified.
groups=[]
url=f'/v1/apps/{app_id}/betaGroups?fields[betaGroups]=name,isInternalGroup,hasAccessToAllBuilds&limit=200'
while url:
    response=get(url)
    for group in response.get('data') or []:
        ga=group.get('attributes') or {}
        gid=str(group['id'])
        ids=[]
        relationship=f'/v1/betaGroups/{gid}/relationships/builds?limit=200'
        while relationship:
            linked=get(relationship)
            ids.extend(str(d['id']) for d in linked.get('data') or [])
            relationship=(linked.get('links') or {}).get('next')
            if relationship and relationship.startswith(base):
                relationship=relationship[len(base):]
            if relationship and not relationship.startswith('/'):
                raise SystemExit('unsafe group relationship pagination URL')
        groups.append({'group_id':gid,'name':ga.get('name'),'is_internal':ga.get('isInternalGroup'),
            'all_builds_flag':ga.get('hasAccessToAllBuilds'),
            'linked_build_ids':ids, 'latest_build_explicit_link':(str(out_builds[0]['id']) in ids) if out_builds else False})
    url=(response.get('links') or {}).get('next')
    if url and url.startswith(base): url=url[len(base):]
    if url and not url.startswith('/'): raise SystemExit('unsafe group pagination URL')

result={
    'request_id':cmd.get('request_id'),
    'read_only':True,
    'bundle_id':expected_bundle,
    'app_id':app_id,
    'app_name':attrs.get('name'),
    'builds':out_builds,
    'latest':out_builds[0] if out_builds else None,
    'credentials_persisted':False,
    'beta_groups':groups,
    'latest_build_internal_group_linked':any(g['is_internal'] is True and g['latest_build_explicit_link'] for g in groups),
}
Path('scanlab-asc-isolated-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS Scan Lab isolated readback; latest_build=', result['latest']['version'] if result['latest'] else None, 'internal_group_explicitly_linked=', result['latest_build_internal_group_linked'])
