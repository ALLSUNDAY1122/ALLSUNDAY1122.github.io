#!/usr/bin/env python3
"""Target-bound Pitari Build 12 asset bridge. No media or plaintext upload URLs leave CI."""
import base64, hashlib, json, os, re, sys, urllib.error, urllib.request
from datetime import datetime, timezone
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from app_store_connect_api import load_private_key, make_token

APP="6795941132"
BUNDLE="jp.allsunday.pitariresize"
VERSION="e0aa7c21-0569-4e59-85e7-3cc3afe65dff"
BUILD="b0821263-a794-467f-baf0-41b386f6f233"
DETAIL="7416f717-4d3b-475d-9c86-7f1f00a34627"
LOC="415714d1-5d12-4f37-87e2-7da943a70518"
IAP="6798713983"
FILES={
 "video":{"type":"appStoreReviewAttachments","file_name":"pitari_app_review_ios27_2_batch_20261104.mp4","size":634130},
 "screenshot":{"type":"appScreenshots","file_name":"pitari_build12_iphone_screenshot_20261104.png","size":417730,"display":"APP_IPHONE_61"}
}
OLD_FAILED={"e268c8c1-bb46-44e2-8bf0-7163a6367fd0","911e8b77-4d7f-42b2-b441-5c666a1d0826"}
class ApiError(Exception):
 def __init__(self,status,codes):
  self.status=status; self.codes=codes
def call(token,path,method="GET",payload=None):
 assert path.startswith(("/v1/","/v2/")) and method in {"GET","POST","PATCH","DELETE"}
 raw=None if payload is None else json.dumps(payload).encode()
 req=urllib.request.Request("https://api.appstoreconnect.apple.com"+path,data=raw,method=method,headers={"Authorization":"Bearer "+token,"Content-Type":"application/json","Accept":"application/json"})
 try:
  with urllib.request.urlopen(req,timeout=40) as response:
   data=response.read()
   return json.loads(data) if data else {}
 except urllib.error.HTTPError as exc:
  try: errors=json.loads(exc.read()).get("errors",[])
  except Exception: errors=[]
  codes=[str(e.get("code","UNKNOWN"))[:160] for e in errors]
  raise ApiError(exc.code,codes) from None
def rows(p):
 d=p.get("data",[])
 return d if isinstance(d,list) else [d] if isinstance(d,dict) else []
def one(p):
 r=rows(p); assert len(r)==1,"Expected one resource"
 return r[0]
def attrs(r): return r.get("attributes") or {}
def ids(p): return {r["id"] for r in rows(p)}
def rel(typ,id): return {"data":{"type":typ,"id":id}}
def delivery(r): return attrs(r).get("assetDeliveryState") or {}
def sealed(data,pem):
 pub=serialization.load_pem_public_key(pem.encode())
 assert isinstance(pub,rsa.RSAPublicKey) and pub.key_size>=3072,"RSA 3072+ recipient required"
 key=os.urandom(32); nonce=os.urandom(12)
 ciphertext=AESGCM(key).encrypt(nonce,json.dumps(data).encode(),b"pitari-review-v1")
 wrapped=pub.encrypt(key,padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),algorithm=hashes.SHA256(),label=None))
 return {k:base64.b64encode(v).decode() for k,v in {"wrapped_key":wrapped,"nonce":nonce,"ciphertext":ciphertext}.items()}
def preflight(token):
 app=one(call(token,f"/v1/apps/{APP}"))
 assert attrs(app).get("bundleId")==BUNDLE,"App identity mismatch"
 assert VERSION in ids(call(token,f"/v1/apps/{APP}/appStoreVersions?limit=200")),"Version ownership mismatch"
 version=one(call(token,f"/v1/appStoreVersions/{VERSION}"))
 assert attrs(version).get("platform")=="IOS" and attrs(version).get("versionString")=="1.0","Version mismatch"
 selected=one(call(token,f"/v1/appStoreVersions/{VERSION}/build"))
 assert selected["id"]==BUILD and attrs(selected).get("version")=="12","Selected Build 12 required"
 assert attrs(selected).get("processingState")=="VALID" and not attrs(selected).get("expired"),"Build invalid"
 detail=one(call(token,f"/v1/appStoreVersions/{VERSION}/appStoreReviewDetail"))
 assert detail["id"]==DETAIL,"Review detail ownership mismatch"
 assert LOC in ids(call(token,f"/v1/appStoreVersions/{VERSION}/appStoreVersionLocalizations")),"Localization ownership mismatch"
 return version,detail
def sets(token):
 return rows(call(token,f"/v1/appStoreVersionLocalizations/{LOC}/appScreenshotSets?limit=100"))
def collections(token):
 out={"video":rows(call(token,f"/v1/appStoreReviewDetails/{DETAIL}/appStoreReviewAttachments?limit=100")),"screenshot":[]}
 for ss in sets(token):
  for s in rows(call(token,f"/v1/appScreenshotSets/{ss['id']}/appScreenshots?limit=100")):
   s["_set_id"]=ss["id"];s["_display"]=attrs(ss).get("screenshotDisplayType");out["screenshot"].append(s)
 return out
def sanitized_asset(r):
 a=attrs(r); d=delivery(r)
 return {"id":r["id"],"type":r["type"],"file_name":a.get("fileName"),"file_size":a.get("fileSize"),"state":d.get("state"),"error_codes":[e.get("code") for e in d.get("errors") or []],"display":r.get("_display")}
def audit(token,version,detail):
 assets=collections(token)
 iap=one(call(token,f"/v2/inAppPurchases/{IAP}"))
 assert attrs(iap).get("productId")=="jp.allsunday.pitariresize.pro.lifetime" and attrs(iap).get("inAppPurchaseType")=="NON_CONSUMABLE","IAP identity mismatch"
 shot=one(call(token,f"/v2/inAppPurchases/{IAP}/appStoreReviewScreenshot"))
 iv=rows(call(token,f"/v2/inAppPurchases/{IAP}/versions?limit=100"))
 a=attrs(detail);notes=a.get("notes") or ""
 return {"app_id":APP,"bundle_id":BUNDLE,"version_id":VERSION,"build_id":BUILD,"app_store_state":attrs(version).get("appStoreState"),"review_notes":{"present":bool(notes),"length":len(notes),"sha256":hashlib.sha256(notes.encode()).hexdigest(),"demo_account_required":a.get("demoAccountRequired"),"contact_present":{k:bool(a.get(k)) for k in ["contactFirstName","contactLastName","contactPhone","contactEmail"]}},"assets":{k:[sanitized_asset(r) for r in v] for k,v in assets.items()},"iap":{"id":IAP,"state":attrs(iap).get("state"),"review_screenshot":sanitized_asset(shot),"versions":[{"id":r["id"],"state":attrs(r).get("state")} for r in iv]},"review_submissions":[{"id":r["id"],"state":attrs(r).get("state")} for r in rows(call(token,f"/v1/reviewSubmissions?filter[app]={APP}&limit=100"))]}
def execute(token,command):
 version,detail=preflight(token);action=command["action"]
 if action=="audit": return audit(token,version,detail)
 if action=="reserve_assets":
  # Validate recipient before creating any Apple resource.
  sealed({},command["recipient_public_key"])
  existing=collections(token);reserved=[]
  for kind in ["video","screenshot"]:
   f=FILES[kind];matches=[r for r in existing[kind] if attrs(r).get("fileName")==f["file_name"]]
   assert len(matches)<=1,"Ambiguous existing filename"
   if matches:
    resource=matches[0];assert attrs(resource).get("fileSize")==f["size"],"Existing size mismatch"
    resource=one(call(token,f"/v1/{f['type']}/{resource['id']}"))
   else:
    if kind=="video": relationships={"appStoreReviewDetail":rel("appStoreReviewDetails",DETAIL)}
    else:
     matching=[s for s in sets(token) if attrs(s).get("screenshotDisplayType")==f["display"]]
     assert len(matching)<=1,"Ambiguous screenshot set"
     if matching: ss=matching[0]
     else: ss=one(call(token,"/v1/appScreenshotSets","POST",{"data":{"type":"appScreenshotSets","attributes":{"screenshotDisplayType":f["display"]},"relationships":{"appStoreVersionLocalization":rel("appStoreVersionLocalizations",LOC)}}}))
     relationships={"appScreenshotSet":rel("appScreenshotSets",ss["id"])}
    resource=one(call(token,"/v1/"+f["type"],"POST",{"data":{"type":f["type"],"attributes":{"fileName":f["file_name"],"fileSize":f["size"]},"relationships":relationships}}))
   assert delivery(resource).get("state")!="FAILED","Existing asset failed; explicit remediation needed"
   reserved.append({"kind":kind,"resource":resource})
  return {"assets":[{"kind":r["kind"],**sanitized_asset(r["resource"])} for r in reserved],"encrypted_upload_instructions":sealed(reserved,command["recipient_public_key"])}
 if action=="complete_assets":
  existing=collections(token);receipt=[]
  for asset in command["assets"]:
   kind=asset["kind"];f=FILES[kind];assert re.fullmatch(r"[a-f0-9]{32}",asset["md5"]),"Invalid MD5"
   matches=[r for r in existing[kind] if r["id"]==asset["id"] and attrs(r).get("fileName")==f["file_name"] and attrs(r).get("fileSize")==f["size"]]
   assert len(matches)==1,"Asset ownership mismatch"
   r=matches[0]
   if delivery(r).get("state")!="COMPLETE":
    call(token,f"/v1/{f['type']}/{r['id']}","PATCH",{"data":{"type":f["type"],"id":r["id"],"attributes":{"uploaded":True,"sourceFileChecksum":asset["md5"]}}})
   receipt.append(sanitized_asset(one(call(token,f"/v1/{f['type']}/{r['id']}"))))
  return {"assets":receipt}
 if action=="remove_failed_screenshots":
  existing=collections(token)
  assert any(attrs(r).get("fileName")==FILES["screenshot"]["file_name"] and delivery(r).get("state")=="COMPLETE" for r in existing["screenshot"]),"Replacement must be COMPLETE"
  removed=[]
  for r in existing["screenshot"]:
   if r["id"] in OLD_FAILED:
    assert delivery(r).get("state")=="FAILED" and r["_set_id"]=="32b924ca-603f-4003-b61f-46b41a1e469e","Old failed target changed"
    call(token,f"/v1/appScreenshots/{r['id']}","DELETE");removed.append(r["id"])
  return {"removed_failed_ids":removed,"audit":audit(token,version,detail)}
 raise ValueError("Unsupported target-bound action")
def main():
 command=json.loads(Path("automation/pitari-review-command.json").read_text())
 request_id=command["request_id"];assert re.fullmatch(r"[A-Za-z0-9._-]{1,100}",request_id),"Invalid request id"
 out={"request_id":request_id,"checked_at":datetime.now(timezone.utc).isoformat(),"action":command["action"],"app_id":APP}
 key_path,cleanup=load_private_key()
 try:
  token=make_token(os.environ["ASC_ISSUER_ID"],os.environ["ASC_KEY_ID"],key_path)
  out["result"]=execute(token,command);out["ok"]=True
 except ApiError as exc:
  out.update(ok=False,error={"http_status":exc.status,"codes":exc.codes})
 except Exception as exc:
  # Never serialize arbitrary exception text, response bodies, tokens or upload URLs.
  out.update(ok=False,error={"type":type(exc).__name__})
 finally:
  if cleanup:cleanup.unlink(missing_ok=True)
 result_path=Path("automation/pitari-review-results")/(request_id+".json")
 result_path.parent.mkdir(parents=True,exist_ok=True);result_path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
 print("Pitari request "+request_id+" result ok="+str(out["ok"])+"; sanitized receipt saved")
 return 0 if out["ok"] else 1
if __name__=="__main__":sys.exit(main())
