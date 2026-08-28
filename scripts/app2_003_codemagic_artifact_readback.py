#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import os
import plistlib
import urllib.request
import zipfile
from pathlib import Path

ALLOWED_BUILD_IDS = {
    "6a903f4e0b744f0115921f39",
    "6a910380c8427ec173c8e13f",
    "6a9104bdc61a7f197e4ce9b6",
    "6a9105fde0c3191da504c2c7",
    "6a910f0cfcbd73331ec99411",
}
TARGET_SUFFIXES = (
    "/Info.plist",
    "/PrivacyInfo.xcprivacy",
)
SAFE_LOG_TERMS = (
    "native UI audit",
    "native-ui-gate",
    "marker missing",
    "signature missing",
    "Error:",
    "error:",
)
NATIVE_JS_MARKER = "app2-003-reader-fixes-v3"
NATIVE_CSS_MARKER = "app2-reader-fixes-v3"
NATIVE_CSS_SELECTORS = (
    "html.app2-reader-fixes-v3.reader-overlay",
    "html.app2-reader-fixes-v3.reader-toolbar",
    "html.app2-reader-fixes-v3.library-tools",
    "html.app2-reader-fixes-v3.story-card.story-read-button",
)

def safe_plist(raw: bytes):
    try: value = plistlib.loads(raw)
    except Exception: return None
    if isinstance(value, dict):
        allowed = {"CFBundleIdentifier","CFBundleShortVersionString","CFBundleVersion","MinimumOSVersion","ITSAppUsesNonExemptEncryption","NSUserTrackingUsageDescription","NSAppTransportSecurity","NSPrivacyTracking","NSPrivacyTrackingDomains","NSPrivacyCollectedDataTypes","NSPrivacyAccessedAPITypes"}
        return {k: value[k] for k in allowed if k in value}
    return value

def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as response: return response.read()

def safe_failure_excerpt(bundle_blob: bytes):
    zf=zipfile.ZipFile(io.BytesIO(bundle_blob)); names=[i.filename for i in zf.infolist() if not i.is_dir()]; excerpts=[]
    for name in names:
        if not name.lower().endswith((".log",".txt")): continue
        try: text=zf.read(name).decode("utf-8",errors="replace")
        except Exception: continue
        for line in text.splitlines():
            if any(term in line for term in SAFE_LOG_TERMS): excerpts.append({"file":name,"line":line[:1000]})
    return names,excerpts[:80]

def native_web_audit(zf: zipfile.ZipFile):
    files=[i.filename for i in zf.infolist() if not i.is_dir()]
    web_files=[name for name in files if "/public/" in name and name.lower().endswith((".js",".css",".html"))]
    js_html=[]; css=[]
    for name in web_files:
        try: text=zf.read(name).decode("utf-8",errors="replace")
        except Exception: continue
        if name.lower().endswith(".css"): css.append((name,text.replace(" ","").replace("\n","").replace("\t","")))
        else: js_html.append((name,text))
    js_files=[name for name,text in js_html if NATIVE_JS_MARKER in text]
    css_marker_files=[name for name,text in css if NATIVE_CSS_MARKER in text]
    selector_presence={selector:[name for name,text in css if selector in text] for selector in NATIVE_CSS_SELECTORS}
    return {"public_web_file_count":len(web_files),"js_marker_present":bool(js_files),"js_marker_files":js_files,"css_marker_present":bool(css_marker_files),"css_marker_files":css_marker_files,"scoped_selector_presence":selector_presence,"all_scoped_selectors_present":all(bool(v) for v in selector_presence.values())}

def main() -> int:
    command=json.loads(Path('/tmp/release-command.json').read_text(encoding='utf-8'))
    if command.get('action')!='inspect_artifact': raise SystemExit('action must be inspect_artifact')
    build_id=str(command.get('build_id') or '')
    if build_id not in ALLOWED_BUILD_IDS: raise SystemExit('unexpected build id')
    token=os.environ.get('CM_API_TOKEN','').strip()
    if not token: raise SystemExit('CM_API_TOKEN unavailable')
    req=urllib.request.Request(f'https://codemagic.io/api/v3/builds/{build_id}',headers={'x-auth-token':token,'Accept':'application/json'})
    with urllib.request.urlopen(req,timeout=30) as response: payload=json.load(response)
    build=payload.get('data') or payload; artifacts=build.get('artifacts') or []
    result={'ok':True,'request_id':command.get('request_id'),'action':'inspect_artifact','build_id':build_id,'status':build.get('status'),'secret_values_persisted':False}
    ipa=next((a for a in artifacts if a.get('type')=='ipa'),None)
    if ipa and ipa.get('short_lived_download_url'):
        blob=download(ipa['short_lived_download_url']); zf=zipfile.ZipFile(io.BytesIO(blob)); files=[i.filename for i in zf.infolist() if not i.is_dir()]; audit={}
        for name in files:
            if not name.endswith(TARGET_SUFFIXES): continue
            parsed=safe_plist(zf.read(name))
            if parsed is not None: audit[name]=parsed
        app_info=next((v for k,v in audit.items() if k=='Payload/App.app/Info.plist'),{}); privacy_files={k:v for k,v in audit.items() if k.endswith('/PrivacyInfo.xcprivacy')}
        result.update({'ipa':{'size_in_bytes':ipa.get('size_in_bytes'),'version_name':ipa.get('version_name'),'version_code':ipa.get('version_code')},'app_info':app_info,'privacy_manifests':privacy_files,'privacy_manifest_count':len(privacy_files),'framework_names':sorted({n.split('/Frameworks/',1)[1].split('/',1)[0] for n in files if '/Frameworks/' in n}),'native_web_audit':native_web_audit(zf)})
    bundle=next((a for a in artifacts if a.get('type')=='bundle'),None)
    if bundle and bundle.get('short_lived_download_url'):
        names,excerpts=safe_failure_excerpt(download(bundle['short_lived_download_url'])); result['bundle_files']=names[:200]; result['safe_log_excerpts']=excerpts
    Path('release-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8'); return 0
if __name__=='__main__': raise SystemExit(main())
